import json
import boto3
import os
import uuid
import logging
import random
from datetime import datetime, timedelta
import re
from typing import Dict, Any, Optional, List

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sns_client = boto3.client('sns')
dynamodb = boto3.resource('dynamodb')
bedrock_client = boto3.client('bedrock-runtime')
comprehend_client = boto3.client('comprehend')
ses_client = boto3.client('ses')

# DynamoDB table
support_table = dynamodb.Table(os.environ.get('SUPPORT_TICKETS_TABLE', 'support_tickets'))

def lambda_handler(event, context):
    """
    Handle support requests
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract HTTP method and path
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        
        # Parse request body
        body = {}
        if event.get('body'):
            try:
                body = json.loads(event['body'])
            except json.JSONDecodeError:
                return create_response(400, {'error': 'Invalid JSON in request body'})
        
        # Route based on path and method
        if path == '/support' and http_method == 'GET':
            return handle_get_support_info()
        elif path == '/support/tickets' and http_method == 'GET':
            return handle_get_tickets(event.get('queryStringParameters', {}))
        elif path == '/support/tickets' and http_method == 'POST':
            return handle_create_ticket(body)
        elif path == '/support/chat' and http_method == 'GET':
            return handle_get_chat_info()
        elif path == '/support/chat' and http_method == 'POST':
            return handle_chat_message(body)
        elif path == '/support/ai' and http_method == 'GET':
            return handle_get_ai_info()
        elif path == '/support/ai' and http_method == 'POST':
            return handle_ai_support(body)
        elif path == '/support/tickets/status' and http_method == 'PUT':
            return handle_update_ticket_status(body)
        else:
            return create_response(404, {'error': 'Endpoint not found'})
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_get_tickets(query_params):
    """Handle get support tickets from DynamoDB"""
    try:
        user_id = query_params.get('user_id') if query_params else None
        status = query_params.get('status', 'all') if query_params else 'all'
        limit = int(query_params.get('limit', 50)) if query_params else 50
        
        # Query tickets from DynamoDB
        if user_id:
            # Get tickets for specific user
            response = support_table.query(
                IndexName='user-id-index',
                KeyConditionExpression='user_id = :user_id',
                ExpressionAttributeValues={':user_id': user_id},
                Limit=limit,
                ScanIndexForward=False  # Most recent first
            )
        else:
            # Scan all tickets (admin view)
            if status != 'all':
                response = support_table.scan(
                    FilterExpression='#status = :status',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={':status': status},
                    Limit=limit
                )
            else:
                response = support_table.scan(Limit=limit)
        
        tickets = []
        for item in response.get('Items', []):
            ticket = {
                'ticket_id': item['ticket_id'],
                'user_id': item['user_id'],
                'type': item['type'],
                'priority': item['priority'],
                'status': item['status'],
                'subject': item['subject'],
                'description': item['description'],
                'keywords': item.get('keywords', []),
                'ai_suggestions': item.get('ai_suggestions', []),
                'assigned_team': item.get('assigned_team'),
                'created_at': item['created_at'],
                'updated_at': item['updated_at']
            }
            tickets.append(ticket)
        
        # Sort by created_at descending
        tickets.sort(key=lambda x: x['created_at'], reverse=True)
        
        return create_response(200, {
            'tickets': tickets,
            'total': len(tickets)
        })
        
    except Exception as e:
        logger.error(f"Get tickets error: {str(e)}")
        return create_response(500, {'error': 'Failed to retrieve tickets'})

def handle_create_ticket(body):
    """Handle create support ticket with AI analysis and DynamoDB storage"""
    try:
        user_id = body.get('user_id')
        subject = body.get('subject')
        description = body.get('description')
        priority = body.get('priority', 'medium')
        source_context = body.get('source_context', {})
        
        if not all([user_id, subject, description]):
            return create_response(400, {'error': 'Missing required fields'})
        
        # Generate unique ticket ID
        ticket_id = f"TKT-{datetime.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        
        # Analyze ticket content with AI
        ai_analysis = analyze_ticket_content(subject + " " + description)
        
        # Determine ticket type and priority based on keywords
        ticket_type = determine_ticket_type(ai_analysis['keywords'])
        if ai_analysis.get('urgency_score', 0) > 0.8:
            priority = 'urgent'
        elif ai_analysis.get('urgency_score', 0) > 0.6:
            priority = 'high'
        
        # Assign to appropriate team
        assigned_team = assign_to_team(ai_analysis['keywords'], ticket_type)
        
        # Create ticket in DynamoDB
        current_time = datetime.now().isoformat()
        ttl = int((datetime.now() + timedelta(days=365)).timestamp())  # 1 year retention
        
        ticket_item = {
            'ticket_id': ticket_id,
            'user_id': user_id,
            'type': ticket_type,
            'priority': priority,
            'status': 'open',
            'subject': subject,
            'description': description,
            'keywords': ai_analysis['keywords'],
            'ai_suggestions': ai_analysis['suggestions'],
            'sentiment_score': ai_analysis.get('sentiment_score', 0.5),
            'assigned_team': assigned_team,
            'source_context': source_context,
            'created_at': current_time,
            'updated_at': current_time,
            'ttl': ttl
        }
        
        support_table.put_item(Item=ticket_item)
        
        # Send notifications
        send_ticket_notifications(ticket_item)
        
        logger.info(f"Created ticket: {ticket_id} for user {user_id}")
        
        return create_response(201, {
            'message': 'Ticket created successfully',
            'ticket': {
                'ticket_id': ticket_id,
                'user_id': user_id,
                'type': ticket_type,
                'priority': priority,
                'status': 'open',
                'subject': subject,
                'assigned_team': assigned_team,
                'ai_analysis': {
                    'keywords': ai_analysis['keywords'],
                    'suggestions': ai_analysis['suggestions'][:3],  # Top 3 suggestions
                    'confidence': ai_analysis.get('confidence', 0.5)
                },
                'created_at': current_time
            }
        })
        
    except Exception as e:
        logger.error(f"Create ticket error: {str(e)}")
        return create_response(500, {'error': 'Failed to create ticket'})

def handle_chat_message(body):
    """Handle chat support message"""
    try:
        user_id = body.get('user_id')
        message = body.get('message')
        session_id = body.get('session_id')
        
        if not all([user_id, message]):
            return create_response(400, {'error': 'User ID and message required'})
        
        # Mock chat response (replace with actual chat system)
        response_message = "Thank you for contacting support. An agent will be with you shortly."
        
        chat_data = {
            'session_id': session_id or f"chat_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            'user_message': message,
            'agent_response': response_message,
            'timestamp': datetime.now().isoformat()
        }
        
        return create_response(200, {
            'message': 'Chat message processed',
            'chat': chat_data
        })
        
    except Exception as e:
        logger.error(f"Chat message error: {str(e)}")
        return create_response(500, {'error': 'Failed to process chat message'})

def handle_ai_support(body):
    """Handle AI-powered support"""
    try:
        user_id = body.get('user_id')
        question = body.get('question')
        
        if not all([user_id, question]):
            return create_response(400, {'error': 'User ID and question required'})
        
        # Mock AI response (replace with actual AI service)
        ai_responses = [
            "To improve your stream quality, try adjusting your bitrate settings in your streaming software.",
            "For payment issues, please check that your payment method is valid and has sufficient funds.",
            "To reset your password, click on 'Forgot Password' on the login page and follow the instructions.",
            "For technical support, please provide your stream ID and a description of the issue you're experiencing."
        ]
        
        ai_response = random.choice(ai_responses)
        
        return create_response(200, {
            'question': question,
            'answer': ai_response,
            'confidence': round(random.uniform(0.7, 0.95), 2),
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"AI support error: {str(e)}")
        return create_response(500, {'error': 'Failed to process AI support request'})

def handle_get_support_info():
    """Handle get support info"""
    try:
        support_info = {
            'available_channels': ['tickets', 'chat', 'ai'],
            'business_hours': '9 AM - 5 PM UTC',
            'response_time': {
                'tickets': '24 hours',
                'chat': 'immediate',
                'ai': 'immediate'
            }
        }
        
        return create_response(200, support_info)
        
    except Exception as e:
        logger.error(f"Get support info error: {str(e)}")
        return create_response(500, {'error': 'Failed to get support info'})

def handle_get_chat_info():
    """Handle get chat info"""
    try:
        chat_info = {
            'status': 'available',
            'queue_length': random.randint(0, 5),
            'estimated_wait': f"{random.randint(1, 10)} minutes"
        }
        
        return create_response(200, chat_info)
        
    except Exception as e:
        logger.error(f"Get chat info error: {str(e)}")
        return create_response(500, {'error': 'Failed to get chat info'})

def handle_get_ai_info():
    """Handle get AI support info"""
    try:
        ai_info = {
            'status': 'online',
            'capabilities': ['general_questions', 'troubleshooting', 'account_help'],
            'languages': ['en', 'es', 'fr']
        }
        
        return create_response(200, ai_info)
        
    except Exception as e:
        logger.error(f"Get AI info error: {str(e)}")
        return create_response(500, {'error': 'Failed to get AI info'})

# AI Analysis and Helper Functions
def analyze_ticket_content(content: str) -> Dict[str, Any]:
    """Analyze ticket content using AI services"""
    try:
        # Extract keywords using regex patterns
        keywords = extract_keywords(content)
        
        # Analyze sentiment with Comprehend
        sentiment_analysis = analyze_sentiment(content)
        
        # Generate suggestions with Bedrock
        suggestions = generate_ai_suggestions(content, keywords)
        
        # Calculate urgency score
        urgency_score = calculate_urgency_score(keywords, sentiment_analysis)
        
        return {
            'keywords': keywords,
            'sentiment_score': sentiment_analysis.get('score', 0.5),
            'sentiment': sentiment_analysis.get('sentiment', 'NEUTRAL'),
            'suggestions': suggestions,
            'urgency_score': urgency_score,
            'confidence': 0.8  # Base confidence score
        }
        
    except Exception as e:
        logger.error(f"AI analysis error: {str(e)}")
        return {
            'keywords': extract_keywords(content),
            'sentiment_score': 0.5,
            'sentiment': 'NEUTRAL',
            'suggestions': ['Please provide more details about your issue.'],
            'urgency_score': 0.5,
            'confidence': 0.3
        }

def extract_keywords(content: str) -> List[str]:
    """Extract keywords from ticket content"""
    # Define keyword patterns for different categories
    keyword_patterns = {
        'password': r'\b(password|login|signin|authentication|access)\b',
        'billing': r'\b(payment|billing|subscription|charge|refund|invoice)\b',
        'streaming': r'\b(stream|video|quality|buffer|lag|connection)\b',
        'technical': r'\b(error|bug|crash|broken|not working|issue)\b',
        'account': r'\b(account|profile|settings|preferences)\b',
        'urgent': r'\b(urgent|emergency|critical|immediately|asap)\b',
        'angry': r'\b(angry|frustrated|terrible|awful|horrible)\b'
    }
    
    keywords = []
    content_lower = content.lower()
    
    for category, pattern in keyword_patterns.items():
        if re.search(pattern, content_lower):
            keywords.append(category)
    
    return keywords

def analyze_sentiment(content: str) -> Dict[str, Any]:
    """Analyze sentiment using Comprehend"""
    try:
        response = comprehend_client.detect_sentiment(
            Text=content[:5000],  # Limit to 5000 characters
            LanguageCode='en'
        )
        
        sentiment = response['Sentiment']
        scores = response['SentimentScore']
        
        # Convert to numerical score (0 = very negative, 1 = very positive)
        if sentiment == 'POSITIVE':
            score = 0.7 + (scores['Positive'] * 0.3)
        elif sentiment == 'NEGATIVE':
            score = 0.3 - (scores['Negative'] * 0.3)
        elif sentiment == 'MIXED':
            score = 0.5
        else:  # NEUTRAL
            score = 0.5
        
        return {
            'sentiment': sentiment,
            'score': score,
            'confidence': max(scores.values())
        }
        
    except Exception as e:
        logger.error(f"Sentiment analysis error: {str(e)}")
        return {'sentiment': 'NEUTRAL', 'score': 0.5, 'confidence': 0.0}

def generate_ai_suggestions(content: str, keywords: List[str]) -> List[str]:
    """Generate response suggestions using Bedrock"""
    try:
        # Create context-aware prompt
        prompt = f"""
        Analyze this support ticket and provide 3 helpful response suggestions:
        
        Content: {content[:1000]}
        Keywords: {', '.join(keywords)}
        
        Provide professional, helpful responses that address the user's concern.
        Format as a JSON array of strings.
        """
        
        response = bedrock_client.invoke_model(
            modelId='anthropic.claude-v2',
            body=json.dumps({
                'prompt': prompt,
                'max_tokens': 500,
                'temperature': 0.7
            })
        )
        
        response_body = json.loads(response['body'].read())
        suggestions_text = response_body.get('completion', '')
        
        # Try to parse as JSON, fallback to simple suggestions
        try:
            suggestions = json.loads(suggestions_text)
            if isinstance(suggestions, list):
                return suggestions[:3]
        except:
            pass
        
        # Fallback suggestions based on keywords
        return get_fallback_suggestions(keywords)
        
    except Exception as e:
        logger.error(f"Bedrock suggestion error: {str(e)}")
        return get_fallback_suggestions(keywords)

def get_fallback_suggestions(keywords: List[str]) -> List[str]:
    """Get fallback suggestions based on keywords"""
    suggestions_map = {
        'password': [
            "Please try resetting your password using the 'Forgot Password' link on the login page.",
            "Ensure you're using the correct email address associated with your account.",
            "Check if Caps Lock is enabled and verify your password is entered correctly."
        ],
        'billing': [
            "Please check your payment method is valid and has sufficient funds.",
            "Review your subscription details in your account settings.",
            "Contact our billing team for assistance with payment issues."
        ],
        'streaming': [
            "Try refreshing your browser or restarting the application.",
            "Check your internet connection speed and stability.",
            "Ensure your subscription tier supports the quality you're trying to access."
        ],
        'technical': [
            "Please provide more details about the error message you're seeing.",
            "Try clearing your browser cache and cookies.",
            "Check if the issue persists in an incognito/private browsing window."
        ]
    }
    
    for keyword in keywords:
        if keyword in suggestions_map:
            return suggestions_map[keyword]
    
    return [
        "Thank you for contacting support. We'll investigate your issue and get back to you soon.",
        "Please provide additional details about your problem so we can assist you better.",
        "Our team will review your request and respond within 24 hours."
    ]

def calculate_urgency_score(keywords: List[str], sentiment_analysis: Dict[str, Any]) -> float:
    """Calculate urgency score based on keywords and sentiment"""
    urgency_weights = {
        'urgent': 0.9,
        'angry': 0.8,
        'billing': 0.7,
        'password': 0.6,
        'technical': 0.5,
        'streaming': 0.4
    }
    
    base_score = 0.3
    for keyword in keywords:
        if keyword in urgency_weights:
            base_score = max(base_score, urgency_weights[keyword])
    
    # Adjust based on sentiment
    sentiment_score = sentiment_analysis.get('score', 0.5)
    if sentiment_score < 0.3:  # Very negative
        base_score += 0.2
    elif sentiment_score < 0.4:  # Negative
        base_score += 0.1
    
    return min(base_score, 1.0)

def determine_ticket_type(keywords: List[str]) -> str:
    """Determine ticket type based on keywords"""
    type_priorities = [
        ('billing', ['billing', 'payment']),
        ('technical', ['technical', 'streaming', 'error']),
        ('account', ['password', 'account']),
        ('content', ['streaming', 'video']),
        ('general', [])  # Default
    ]
    
    for ticket_type, type_keywords in type_priorities:
        if any(keyword in keywords for keyword in type_keywords):
            return ticket_type
    
    return 'general'

def assign_to_team(keywords: List[str], ticket_type: str) -> str:
    """Assign ticket to appropriate team"""
    team_assignments = {
        'billing': 'billing-team',
        'technical': 'technical-team',
        'account': 'security-team',
        'content': 'content-team',
        'general': 'general-support'
    }
    
    # Check for urgent keywords that override normal assignment
    if 'urgent' in keywords or 'angry' in keywords:
        return 'escalation-team'
    
    return team_assignments.get(ticket_type, 'general-support')

def send_ticket_notifications(ticket: Dict[str, Any]) -> None:
    """Send notifications for new ticket"""
    try:
        # Send email to bilalkwj@amazon.com
        email_subject = f"New Support Ticket: {ticket['ticket_id']} - {ticket['subject']}"
        email_body = f"""
        New support ticket created:
        
        Ticket ID: {ticket['ticket_id']}
        User ID: {ticket['user_id']}
        Type: {ticket['type']}
        Priority: {ticket['priority']}
        Subject: {ticket['subject']}
        
        Description:
        {ticket['description']}
        
        Keywords: {', '.join(ticket['keywords'])}
        Assigned Team: {ticket['assigned_team']}
        
        Created: {ticket['created_at']}
        """
        
        ses_client.send_email(
            Source='noreply@streaming-platform.com',
            Destination={'ToAddresses': ['bilalkwj@amazon.com']},
            Message={
                'Subject': {'Data': email_subject},
                'Body': {'Text': {'Data': email_body}}
            }
        )
        
        # Send SNS notification to team
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if sns_topic_arn:
            sns_client.publish(
                TopicArn=sns_topic_arn,
                Subject=f"New {ticket['priority']} priority ticket: {ticket['ticket_id']}",
                Message=json.dumps({
                    'ticket_id': ticket['ticket_id'],
                    'type': ticket['type'],
                    'priority': ticket['priority'],
                    'assigned_team': ticket['assigned_team'],
                    'keywords': ticket['keywords']
                })
            )
        
        logger.info(f"Notifications sent for ticket {ticket['ticket_id']}")
        
    except Exception as e:
        logger.error(f"Failed to send notifications: {str(e)}")

def handle_update_ticket_status(body):
    """Update ticket status"""
    try:
        ticket_id = body.get('ticket_id')
        new_status = body.get('status')
        agent_id = body.get('agent_id')
        
        if not ticket_id or not new_status:
            return create_response(400, {'error': 'Ticket ID and status required'})
        
        # Update ticket in DynamoDB
        update_expression = "SET #status = :status, updated_at = :updated_at"
        expression_values = {
            ':status': new_status,
            ':updated_at': datetime.now().isoformat()
        }
        expression_names = {'#status': 'status'}
        
        if agent_id:
            update_expression += ", assigned_agent = :agent_id"
            expression_values[':agent_id'] = agent_id
        
        if new_status == 'resolved':
            update_expression += ", resolved_at = :resolved_at"
            expression_values[':resolved_at'] = datetime.now().isoformat()
        
        support_table.update_item(
            Key={'ticket_id': ticket_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values,
            ExpressionAttributeNames=expression_names
        )
        
        return create_response(200, {
            'message': 'Ticket status updated successfully',
            'ticket_id': ticket_id,
            'status': new_status
        })
        
    except Exception as e:
        logger.error(f"Update ticket status error: {str(e)}")
        return create_response(500, {'error': 'Failed to update ticket status'})

def create_response(status_code, body):
    """Create HTTP response"""
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