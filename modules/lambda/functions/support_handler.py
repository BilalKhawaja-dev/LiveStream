import json
import boto3
import os
import logging
import uuid
from datetime import datetime
from typing import Dict, Any, List, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
rds_client = boto3.client('rds-data')
dynamodb = boto3.resource('dynamodb')
bedrock_client = boto3.client('bedrock-runtime')
sns_client = boto3.client('sns')
secrets_client = boto3.client('secretsmanager')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Support ticket management handler with AI integration
    Handles ticket creation, AI suggestions, and smart filtering
    """
    
    try:
        # Parse the request
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        query_params = event.get('queryStringParameters') or {}
        
        logger.info(f"Processing {http_method} request to {path}")
        
        # Route to appropriate handler
        if path.endswith('/tickets') and http_method == 'POST':
            return handle_create_ticket(body)
        elif path.endswith('/tickets') and http_method == 'GET':
            return handle_list_tickets(query_params)
        elif '/tickets/' in path and http_method == 'GET':
            ticket_id = path.split('/tickets/')[-1]
            return handle_get_ticket(ticket_id)
        elif '/tickets/' in path and http_method == 'PUT':
            ticket_id = path.split('/tickets/')[-1]
            return handle_update_ticket(ticket_id, body)
        elif path.endswith('/ai/suggest') and http_method == 'POST':
            return handle_ai_suggestion(body)
        elif path.endswith('/chat') and http_method == 'POST':
            return handle_chat_message(body)
        else:
            return create_response(400, {'error': 'Invalid endpoint or method'})
            
    except Exception as e:
        logger.error(f"Support handler error: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_create_ticket(body: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new support ticket with AI analysis"""
    
    try:
        user_id = body.get('user_id')
        subject = body.get('subject')
        description = body.get('description')
        ticket_type = body.get('type', 'general')
        priority = body.get('priority', 'medium')
        
        if not user_id or not subject or not description:
            return create_response(400, {'error': 'User ID, subject, and description required'})
        
        ticket_id = str(uuid.uuid4())
        
        # Analyze ticket content with AI for categorization and priority
        ai_analysis = analyze_ticket_content(subject, description)
        
        # Apply smart filtering based on keywords
        filter_result = apply_smart_filtering(subject, description)
        
        # Determine final priority and type based on AI analysis
        final_priority = ai_analysis.get('suggested_priority', priority)
        final_type = ai_analysis.get('suggested_type', ticket_type)
        
        # Store ticket in Aurora database
        sql = """
        INSERT INTO support_tickets (
            id, user_id, type, priority, status, subject, description,
            context, ai_suggestions, created_at
        ) VALUES (
            :ticket_id, :user_id, :type, :priority, 'open', :subject, :description,
            :context, :ai_suggestions, NOW()
        )
        """
        
        context_data = {
            'user_agent': body.get('user_agent', ''),
            'url': body.get('url', ''),
            'stream_id': body.get('stream_id'),
            'error_logs': body.get('error_logs', [])
        }
        
        parameters = [
            {'name': 'ticket_id', 'value': {'stringValue': ticket_id}},
            {'name': 'user_id', 'value': {'stringValue': user_id}},
            {'name': 'type', 'value': {'stringValue': final_type}},
            {'name': 'priority', 'value': {'stringValue': final_priority}},
            {'name': 'subject', 'value': {'stringValue': subject}},
            {'name': 'description', 'value': {'stringValue': description}},
            {'name': 'context', 'value': {'stringValue': json.dumps(context_data)}},
            {'name': 'ai_suggestions', 'value': {'stringValue': json.dumps(ai_analysis.get('suggestions', []))}}
        ]
        
        rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        # Store ticket metadata in DynamoDB for fast access
        tickets_table = dynamodb.Table(os.environ['DYNAMODB_TICKETS_TABLE'])
        tickets_table.put_item(
            Item={
                'ticket_id': ticket_id,
                'user_id': user_id,
                'type': final_type,
                'priority': final_priority,
                'status': 'open',
                'keywords': filter_result['keywords'],
                'ai_confidence': ai_analysis.get('confidence', 0.5),
                'created_at': datetime.utcnow().isoformat(),
                'ttl': int((datetime.utcnow().timestamp()) + (365 * 24 * 60 * 60))  # 1 year TTL
            }
        )
        
        # Send notifications based on filtering results
        if filter_result['should_notify']:
            send_ticket_notification(ticket_id, final_type, final_priority, filter_result['notification_channels'])
        
        return create_response(201, {
            'ticket_id': ticket_id,
            'type': final_type,
            'priority': final_priority,
            'status': 'open',
            'ai_analysis': ai_analysis,
            'filter_result': filter_result,
            'created_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Create ticket error: {str(e)}")
        return create_response(500, {'error': 'Failed to create ticket'})

def handle_ai_suggestion(body: Dict[str, Any]) -> Dict[str, Any]:
    """Generate AI-powered response suggestions for support tickets"""
    
    try:
        ticket_id = body.get('ticket_id')
        message = body.get('message', '')
        context = body.get('context', {})
        
        if not ticket_id:
            return create_response(400, {'error': 'Ticket ID required'})
        
        # Get ticket details from database
        sql = "SELECT subject, description, type, ai_suggestions FROM support_tickets WHERE id = :ticket_id"
        parameters = [{'name': 'ticket_id', 'value': {'stringValue': ticket_id}}]
        
        result = rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        if not result['records']:
            return create_response(404, {'error': 'Ticket not found'})
        
        ticket_data = result['records'][0]
        subject = ticket_data[0]['stringValue']
        description = ticket_data[1]['stringValue']
        ticket_type = ticket_data[2]['stringValue']
        
        # Generate AI response suggestions
        suggestions = generate_ai_response_suggestions(
            subject=subject,
            description=description,
            ticket_type=ticket_type,
            message=message,
            context=context
        )
        
        return create_response(200, {
            'ticket_id': ticket_id,
            'suggestions': suggestions,
            'generated_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"AI suggestion error: {str(e)}")
        return create_response(500, {'error': 'Failed to generate AI suggestions'})

def analyze_ticket_content(subject: str, description: str) -> Dict[str, Any]:
    """Analyze ticket content using Bedrock AI for categorization and priority"""
    
    try:
        # Prepare prompt for AI analysis
        prompt = f"""
        Analyze this support ticket and provide categorization and priority suggestions:
        
        Subject: {subject}
        Description: {description}
        
        Please provide:
        1. Suggested ticket type (technical, billing, content, account, general)
        2. Suggested priority (low, medium, high, urgent)
        3. Key issues identified
        4. Confidence score (0.0 to 1.0)
        5. Initial response suggestions
        
        Respond in JSON format.
        """
        
        # Call Bedrock AI model
        response = bedrock_client.invoke_model(
            modelId=os.environ['BEDROCK_MODEL_ID'],
            body=json.dumps({
                'prompt': prompt,
                'max_tokens': 500,
                'temperature': 0.3
            })
        )
        
        response_body = json.loads(response['body'].read())
        ai_response = response_body.get('completion', '{}')
        
        # Parse AI response
        try:
            analysis = json.loads(ai_response)
        except json.JSONDecodeError:
            # Fallback analysis if AI response is not valid JSON
            analysis = {
                'suggested_type': 'general',
                'suggested_priority': 'medium',
                'confidence': 0.5,
                'suggestions': ['Please provide more details about your issue.']
            }
        
        return analysis
        
    except Exception as e:
        logger.error(f"AI analysis error: {str(e)}")
        # Return default analysis on error
        return {
            'suggested_type': 'general',
            'suggested_priority': 'medium',
            'confidence': 0.5,
            'suggestions': ['Thank you for contacting support. We will review your request shortly.']
        }

def apply_smart_filtering(subject: str, description: str) -> Dict[str, Any]:
    """Apply smart filtering based on keywords and content analysis"""
    
    try:
        content = f"{subject} {description}".lower()
        
        # Define keyword filters
        keyword_filters = {
            'password': {
                'keywords': ['password', 'login', 'signin', 'authentication', 'access'],
                'priority': 'high',
                'channels': ['security-team@example.com'],
                'urgent': True
            },
            'billing': {
                'keywords': ['billing', 'payment', 'subscription', 'charge', 'refund', 'invoice'],
                'priority': 'medium',
                'channels': ['billing-team@example.com'],
                'urgent': False
            },
            'technical': {
                'keywords': ['error', 'bug', 'crash', 'broken', 'not working', 'technical'],
                'priority': 'medium',
                'channels': ['tech-support@example.com'],
                'urgent': False
            },
            'streaming': {
                'keywords': ['stream', 'video', 'audio', 'quality', 'buffering', 'lag'],
                'priority': 'high',
                'channels': ['streaming-team@example.com'],
                'urgent': True
            }
        }
        
        matched_filters = []
        notification_channels = set()
        max_priority = 'low'
        should_notify = False
        
        # Check for keyword matches
        for filter_name, filter_config in keyword_filters.items():
            for keyword in filter_config['keywords']:
                if keyword in content:
                    matched_filters.append(filter_name)
                    notification_channels.update(filter_config['channels'])
                    
                    # Update priority if higher
                    if filter_config['priority'] == 'urgent' or (filter_config['priority'] == 'high' and max_priority != 'urgent'):
                        max_priority = filter_config['priority']
                    elif filter_config['priority'] == 'medium' and max_priority == 'low':
                        max_priority = filter_config['priority']
                    
                    if filter_config['urgent']:
                        should_notify = True
                    
                    break  # Only match once per filter
        
        return {
            'keywords': list(set(matched_filters)),
            'suggested_priority': max_priority,
            'notification_channels': list(notification_channels),
            'should_notify': should_notify,
            'matched_filters': matched_filters
        }
        
    except Exception as e:
        logger.error(f"Smart filtering error: {str(e)}")
        return {
            'keywords': [],
            'suggested_priority': 'medium',
            'notification_channels': [],
            'should_notify': False,
            'matched_filters': []
        }

def generate_ai_response_suggestions(subject: str, description: str, ticket_type: str, 
                                   message: str = '', context: Dict[str, Any] = {}) -> List[str]:
    """Generate AI-powered response suggestions"""
    
    try:
        # Prepare context for AI
        prompt = f"""
        Generate helpful response suggestions for this support ticket:
        
        Ticket Type: {ticket_type}
        Subject: {subject}
        Description: {description}
        
        {f"Latest Message: {message}" if message else ""}
        
        Context: {json.dumps(context) if context else "No additional context"}
        
        Please provide 3-5 professional, helpful response suggestions that a support agent could use.
        Focus on being empathetic, solution-oriented, and specific to the issue.
        
        Respond with a JSON array of strings.
        """
        
        # Call Bedrock AI model
        response = bedrock_client.invoke_model(
            modelId=os.environ['BEDROCK_MODEL_ID'],
            body=json.dumps({
                'prompt': prompt,
                'max_tokens': 800,
                'temperature': 0.4
            })
        )
        
        response_body = json.loads(response['body'].read())
        ai_response = response_body.get('completion', '[]')
        
        # Parse AI response
        try:
            suggestions = json.loads(ai_response)
            if isinstance(suggestions, list):
                return suggestions[:5]  # Limit to 5 suggestions
        except json.JSONDecodeError:
            pass
        
        # Fallback suggestions
        return [
            "Thank you for contacting us. I understand your concern and I'm here to help.",
            "Let me look into this issue for you right away.",
            "I apologize for any inconvenience this may have caused.",
            "Could you please provide some additional details so I can better assist you?",
            "I'll escalate this to our technical team for further investigation."
        ]
        
    except Exception as e:
        logger.error(f"AI response generation error: {str(e)}")
        return [
            "Thank you for your message. We're reviewing your request and will respond shortly.",
            "I appreciate you bringing this to our attention.",
            "Let me investigate this issue and get back to you with a solution."
        ]

def send_ticket_notification(ticket_id: str, ticket_type: str, priority: str, channels: List[str]) -> None:
    """Send ticket notification via SNS"""
    
    try:
        message = {
            'ticket_id': ticket_id,
            'type': ticket_type,
            'priority': priority,
            'channels': channels,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        sns_client.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Message=json.dumps(message),
            Subject=f'New {priority.upper()} Priority {ticket_type.title()} Ticket'
        )
        
    except Exception as e:
        logger.error(f"Send notification error: {str(e)}")

def handle_list_tickets(query_params: Dict[str, Any]) -> Dict[str, Any]:
    """List support tickets with filtering"""
    
    try:
        user_id = query_params.get('user_id')
        status = query_params.get('status')
        ticket_type = query_params.get('type')
        priority = query_params.get('priority')
        limit = int(query_params.get('limit', 20))
        offset = int(query_params.get('offset', 0))
        
        # Build SQL query
        sql = "SELECT * FROM support_tickets WHERE 1=1"
        parameters = []
        
        if user_id:
            sql += " AND user_id = :user_id"
            parameters.append({'name': 'user_id', 'value': {'stringValue': user_id}})
        
        if status:
            sql += " AND status = :status"
            parameters.append({'name': 'status', 'value': {'stringValue': status}})
        
        if ticket_type:
            sql += " AND type = :type"
            parameters.append({'name': 'type', 'value': {'stringValue': ticket_type}})
        
        if priority:
            sql += " AND priority = :priority"
            parameters.append({'name': 'priority', 'value': {'stringValue': priority}})
        
        sql += " ORDER BY created_at DESC LIMIT :limit OFFSET :offset"
        parameters.extend([
            {'name': 'limit', 'value': {'longValue': limit}},
            {'name': 'offset', 'value': {'longValue': offset}}
        ])
        
        result = rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        tickets = []
        for record in result['records']:
            ticket = {
                'id': record[0]['stringValue'],
                'user_id': record[1]['stringValue'],
                'type': record[3]['stringValue'],
                'priority': record[4]['stringValue'],
                'status': record[5]['stringValue'],
                'subject': record[6]['stringValue'],
                'created_at': record[10]['stringValue']
            }
            tickets.append(ticket)
        
        return create_response(200, {
            'tickets': tickets,
            'total': len(tickets),
            'limit': limit,
            'offset': offset
        })
        
    except Exception as e:
        logger.error(f"List tickets error: {str(e)}")
        return create_response(500, {'error': 'Failed to list tickets'})

def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create standardized API response"""
    
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps(body)
    }