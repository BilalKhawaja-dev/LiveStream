import json
import boto3
import os
import logging
import re
from datetime import datetime
from typing import Dict, Any, List

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
dynamodb_client = boto3.client('dynamodb')
sns_client = boto3.client('sns')
bedrock_client = boto3.client('bedrock-runtime')

# Keyword patterns for ticket categorization
CATEGORY_KEYWORDS = {
    'urgent': [
        'urgent', 'emergency', 'critical', 'down', 'outage', 'broken',
        'not working', 'error', 'crash', 'bug', 'security', 'hack'
    ],
    'technical': [
        'api', 'integration', 'code', 'development', 'streaming', 'quality',
        'buffering', 'latency', 'connection', 'upload', 'download', 'format'
    ],
    'billing': [
        'billing', 'payment', 'charge', 'invoice', 'subscription', 'upgrade',
        'downgrade', 'refund', 'cancel', 'price', 'cost', 'plan'
    ],
    'general': []  # Default category
}

def lambda_handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    Smart ticket filtering Lambda function
    Categorizes support tickets and routes them to appropriate teams
    """
    
    try:
        # Parse the request
        action = event.get('action', 'filter_ticket')
        
        if action == 'filter_ticket':
            return filter_and_route_ticket(event)
        elif action == 'update_filter_rules':
            return update_filter_rules(event)
        elif action == 'get_ticket_stats':
            return get_ticket_statistics()
        else:
            return create_response(400, {'error': f'Unknown action: {action}'})
            
    except Exception as e:
        logger.error(f"Error in ticket filter: {str(e)}")
        return create_response(500, {
            'error': 'Ticket filtering failed',
            'message': str(e)
        })

def filter_and_route_ticket(event: Dict[str, Any]) -> Dict[str, Any]:
    """Filter and route support ticket based on content analysis"""
    try:
        # Extract ticket information
        ticket_data = event.get('ticket', {})
        ticket_id = ticket_data.get('id', f"ticket_{int(datetime.now().timestamp())}")
        subject = ticket_data.get('subject', '')
        description = ticket_data.get('description', '')
        user_id = ticket_data.get('user_id', '')
        priority = ticket_data.get('priority', 'normal')
        
        # Combine subject and description for analysis
        full_text = f"{subject} {description}".lower()
        
        # Determine category using keyword matching and AI
        category = determine_ticket_category(full_text, priority)
        
        # Extract key information using AI
        ticket_analysis = analyze_ticket_with_ai(subject, description)
        
        # Determine urgency level
        urgency = determine_urgency(full_text, priority, ticket_analysis)
        
        # Store ticket in DynamoDB
        store_ticket(ticket_id, ticket_data, category, urgency, ticket_analysis)
        
        # Route to appropriate SNS topic
        routing_result = route_ticket_to_team(ticket_id, category, urgency, ticket_analysis)
        
        # Generate auto-response if applicable
        auto_response = generate_auto_response(category, ticket_analysis)
        
        logger.info(f"Filtered ticket {ticket_id}: category={category}, urgency={urgency}")
        
        return create_response(200, {
            'ticket_id': ticket_id,
            'category': category,
            'urgency': urgency,
            'routing': routing_result,
            'analysis': ticket_analysis,
            'auto_response': auto_response,
            'estimated_resolution_time': get_estimated_resolution_time(category, urgency)
        })
        
    except Exception as e:
        logger.error(f"Error filtering ticket: {str(e)}")
        return create_response(500, {
            'error': 'Failed to filter ticket',
            'message': str(e)
        })

def determine_ticket_category(text: str, priority: str) -> str:
    """Determine ticket category based on keyword analysis"""
    # Check for urgent keywords first
    if priority.lower() in ['high', 'urgent', 'critical']:
        for keyword in CATEGORY_KEYWORDS['urgent']:
            if keyword in text:
                return 'urgent'
    
    # Check other categories
    category_scores = {}
    
    for category, keywords in CATEGORY_KEYWORDS.items():
        if category == 'general':
            continue
            
        score = 0
        for keyword in keywords:
            if keyword in text:
                score += text.count(keyword)
        
        if score > 0:
            category_scores[category] = score
    
    # Return category with highest score, or 'general' if no matches
    if category_scores:
        return max(category_scores, key=category_scores.get)
    else:
        return 'general'

def analyze_ticket_with_ai(subject: str, description: str) -> Dict[str, Any]:
    """Use Bedrock AI to analyze ticket content"""
    try:
        prompt = f"""
        Analyze this support ticket and provide structured information:
        
        Subject: {subject}
        Description: {description}
        
        Please provide:
        1. Main issue category (technical, billing, general, urgent)
        2. Specific problem type
        3. Sentiment (positive, neutral, negative)
        4. Complexity level (low, medium, high)
        5. Key entities mentioned (products, features, error codes)
        6. Suggested resolution approach
        
        Respond in JSON format.
        """
        
        response = bedrock_client.invoke_model(
            modelId=os.environ['BEDROCK_MODEL_ID'],
            body=json.dumps({
                "prompt": prompt,
                "max_tokens": 500,
                "temperature": 0.1
            })
        )
        
        response_body = json.loads(response['body'].read())
        ai_analysis = json.loads(response_body.get('completion', '{}'))
        
        return {
            'category': ai_analysis.get('category', 'general'),
            'problem_type': ai_analysis.get('problem_type', 'unknown'),
            'sentiment': ai_analysis.get('sentiment', 'neutral'),
            'complexity': ai_analysis.get('complexity', 'medium'),
            'entities': ai_analysis.get('entities', []),
            'suggested_approach': ai_analysis.get('suggested_approach', ''),
            'confidence': 0.8  # AI confidence score
        }
        
    except Exception as e:
        logger.error(f"AI analysis failed: {str(e)}")
        return {
            'category': 'general',
            'problem_type': 'unknown',
            'sentiment': 'neutral',
            'complexity': 'medium',
            'entities': [],
            'suggested_approach': 'Manual review required',
            'confidence': 0.0
        }

def determine_urgency(text: str, priority: str, analysis: Dict[str, Any]) -> str:
    """Determine ticket urgency level"""
    urgency_indicators = {
        'critical': ['down', 'outage', 'security', 'hack', 'breach', 'critical'],
        'high': ['urgent', 'emergency', 'broken', 'not working', 'error'],
        'medium': ['issue', 'problem', 'question', 'help'],
        'low': ['suggestion', 'feature', 'improvement', 'feedback']
    }
    
    # Check explicit priority
    if priority.lower() in ['critical', 'high', 'medium', 'low']:
        return priority.lower()
    
    # Check AI sentiment and complexity
    if analysis.get('sentiment') == 'negative' and analysis.get('complexity') == 'high':
        return 'high'
    
    # Check text for urgency indicators
    for urgency, indicators in urgency_indicators.items():
        for indicator in indicators:
            if indicator in text:
                return urgency
    
    return 'medium'  # Default

def store_ticket(ticket_id: str, ticket_data: Dict[str, Any], category: str, urgency: str, analysis: Dict[str, Any]):
    """Store ticket information in DynamoDB"""
    try:
        timestamp = datetime.now().isoformat()
        
        dynamodb_client.put_item(
            TableName=os.environ['DYNAMODB_TICKETS_TABLE'],
            Item={
                'pk': {'S': f'TICKET#{ticket_id}'},
                'sk': {'S': f'METADATA#{timestamp}'},
                'ticket_id': {'S': ticket_id},
                'user_id': {'S': ticket_data.get('user_id', '')},
                'subject': {'S': ticket_data.get('subject', '')},
                'description': {'S': ticket_data.get('description', '')},
                'category': {'S': category},
                'urgency': {'S': urgency},
                'status': {'S': 'open'},
                'created_at': {'S': timestamp},
                'analysis': {'S': json.dumps(analysis)},
                'ttl': {'N': str(int(datetime.now().timestamp()) + 86400 * 365)}  # 1 year TTL
            }
        )
        
        # Update ticket statistics
        update_ticket_statistics(category, urgency)
        
    except Exception as e:
        logger.error(f"Error storing ticket: {str(e)}")

def route_ticket_to_team(ticket_id: str, category: str, urgency: str, analysis: Dict[str, Any]) -> Dict[str, Any]:
    """Route ticket to appropriate team via SNS"""
    try:
        # Determine SNS topic based on category and urgency
        topic_mapping = {
            'urgent': os.environ['SNS_URGENT_TOPIC'],
            'technical': os.environ['SNS_TECHNICAL_TOPIC'],
            'billing': os.environ['SNS_BILLING_TOPIC'],
            'general': os.environ['SNS_GENERAL_TOPIC']
        }
        
        # Use urgent topic for high urgency regardless of category
        if urgency in ['critical', 'high']:
            topic_arn = os.environ['SNS_URGENT_TOPIC']
            team = 'urgent_response'
        else:
            topic_arn = topic_mapping.get(category, os.environ['SNS_GENERAL_TOPIC'])
            team = category
        
        # Create notification message
        message = {
            'ticket_id': ticket_id,
            'category': category,
            'urgency': urgency,
            'team': team,
            'analysis': analysis,
            'timestamp': datetime.now().isoformat()
        }
        
        # Send notification
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=f"New {urgency.upper()} support ticket: {ticket_id}",
            Message=json.dumps(message, indent=2)
        )
        
        logger.info(f"Routed ticket {ticket_id} to {team} team")
        
        return {
            'team': team,
            'topic_arn': topic_arn,
            'notification_sent': True
        }
        
    except Exception as e:
        logger.error(f"Error routing ticket: {str(e)}")
        return {
            'team': 'general',
            'topic_arn': os.environ['SNS_GENERAL_TOPIC'],
            'notification_sent': False,
            'error': str(e)
        }

def generate_auto_response(category: str, analysis: Dict[str, Any]) -> Dict[str, Any]:
    """Generate automatic response for common issues"""
    auto_responses = {
        'billing': {
            'message': 'Thank you for contacting billing support. We have received your request and will respond within 24 hours.',
            'helpful_links': [
                'https://help.example.com/billing',
                'https://help.example.com/subscriptions'
            ]
        },
        'technical': {
            'message': 'We have received your technical support request. Our team will investigate and respond within 4 hours.',
            'helpful_links': [
                'https://help.example.com/technical',
                'https://help.example.com/troubleshooting'
            ]
        },
        'general': {
            'message': 'Thank you for contacting support. We will respond to your inquiry within 24 hours.',
            'helpful_links': [
                'https://help.example.com/faq'
            ]
        }
    }
    
    response = auto_responses.get(category, auto_responses['general'])
    
    # Add urgency-specific messaging
    if analysis.get('complexity') == 'low':
        response['message'] += ' You may also find our self-service options helpful.'
    
    return response

def get_estimated_resolution_time(category: str, urgency: str) -> str:
    """Get estimated resolution time based on category and urgency"""
    resolution_times = {
        ('urgent', 'critical'): '1-2 hours',
        ('urgent', 'high'): '2-4 hours',
        ('technical', 'high'): '4-8 hours',
        ('technical', 'medium'): '1-2 days',
        ('billing', 'high'): '4-8 hours',
        ('billing', 'medium'): '1-2 days',
        ('general', 'medium'): '2-3 days',
        ('general', 'low'): '3-5 days'
    }
    
    return resolution_times.get((category, urgency), '2-3 days')

def update_ticket_statistics(category: str, urgency: str):
    """Update CloudWatch metrics for ticket statistics"""
    try:
        cloudwatch_client = boto3.client('cloudwatch')
        
        # Put custom metrics
        cloudwatch_client.put_metric_data(
            Namespace='Custom/Support',
            MetricData=[
                {
                    'MetricName': 'TicketsCreated',
                    'Dimensions': [
                        {
                            'Name': 'Category',
                            'Value': category
                        }
                    ],
                    'Value': 1,
                    'Unit': 'Count',
                    'Timestamp': datetime.now()
                },
                {
                    'MetricName': 'TicketsCreated',
                    'Dimensions': [
                        {
                            'Name': 'Urgency',
                            'Value': urgency
                        }
                    ],
                    'Value': 1,
                    'Unit': 'Count',
                    'Timestamp': datetime.now()
                }
            ]
        )
        
    except Exception as e:
        logger.error(f"Error updating statistics: {str(e)}")

def update_filter_rules(event: Dict[str, Any]) -> Dict[str, Any]:
    """Update ticket filtering rules"""
    try:
        new_rules = event.get('rules', {})
        
        # Store updated rules in DynamoDB
        timestamp = datetime.now().isoformat()
        
        dynamodb_client.put_item(
            TableName=os.environ['DYNAMODB_TICKETS_TABLE'],
            Item={
                'pk': {'S': 'FILTER_RULES'},
                'sk': {'S': f'VERSION#{timestamp}'},
                'rules': {'S': json.dumps(new_rules)},
                'updated_at': {'S': timestamp},
                'ttl': {'N': str(int(datetime.now().timestamp()) + 86400 * 30)}  # 30 days TTL
            }
        )
        
        return create_response(200, {
            'message': 'Filter rules updated successfully',
            'timestamp': timestamp
        })
        
    except Exception as e:
        logger.error(f"Error updating filter rules: {str(e)}")
        return create_response(500, {
            'error': 'Failed to update filter rules',
            'message': str(e)
        })

def get_ticket_statistics() -> Dict[str, Any]:
    """Get ticket statistics and metrics"""
    try:
        # Query recent tickets for statistics
        response = dynamodb_client.scan(
            TableName=os.environ['DYNAMODB_TICKETS_TABLE'],
            FilterExpression='begins_with(pk, :pk_prefix)',
            ExpressionAttributeValues={
                ':pk_prefix': {'S': 'TICKET#'}
            },
            Limit=100
        )
        
        # Calculate statistics
        stats = {
            'total_tickets': len(response['Items']),
            'by_category': {},
            'by_urgency': {},
            'by_status': {}
        }
        
        for item in response['Items']:
            category = item.get('category', {}).get('S', 'unknown')
            urgency = item.get('urgency', {}).get('S', 'unknown')
            status = item.get('status', {}).get('S', 'unknown')
            
            stats['by_category'][category] = stats['by_category'].get(category, 0) + 1
            stats['by_urgency'][urgency] = stats['by_urgency'].get(urgency, 0) + 1
            stats['by_status'][status] = stats['by_status'].get(status, 0) + 1
        
        return create_response(200, stats)
        
    except Exception as e:
        logger.error(f"Error getting statistics: {str(e)}")
        return create_response(500, {
            'error': 'Failed to get statistics',
            'message': str(e)
        })

def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create HTTP response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps(body)
    }