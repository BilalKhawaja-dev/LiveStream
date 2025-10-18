import json
import boto3
import os
import logging
from datetime import datetime
import random

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sns_client = boto3.client('sns')

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
        else:
            return create_response(404, {'error': 'Endpoint not found'})
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_get_tickets(query_params):
    """Handle get support tickets"""
    try:
        user_id = query_params.get('user_id') if query_params else None
        status = query_params.get('status', 'all') if query_params else 'all'
        
        # Mock ticket data (replace with actual database queries)
        tickets = [
            {
                'ticket_id': 'TKT-001',
                'user_id': user_id or 'user123',
                'subject': 'Stream quality issues',
                'status': 'open',
                'priority': 'medium',
                'created_at': '2024-01-15T10:30:00Z',
                'updated_at': '2024-01-15T14:20:00Z'
            },
            {
                'ticket_id': 'TKT-002',
                'user_id': user_id or 'user456',
                'subject': 'Payment processing error',
                'status': 'resolved',
                'priority': 'high',
                'created_at': '2024-01-14T09:15:00Z',
                'updated_at': '2024-01-14T16:45:00Z'
            }
        ]
        
        # Filter by status if specified
        if status != 'all':
            tickets = [t for t in tickets if t['status'] == status]
        
        return create_response(200, {
            'tickets': tickets,
            'total': len(tickets)
        })
        
    except Exception as e:
        logger.error(f"Get tickets error: {str(e)}")
        return create_response(500, {'error': 'Failed to retrieve tickets'})

def handle_create_ticket(body):
    """Handle create support ticket"""
    try:
        user_id = body.get('user_id')
        subject = body.get('subject')
        description = body.get('description')
        priority = body.get('priority', 'medium')
        
        if not all([user_id, subject, description]):
            return create_response(400, {'error': 'Missing required fields'})
        
        # Mock ticket creation (replace with actual database insert)
        ticket_id = f"TKT-{random.randint(1000, 9999)}"
        
        ticket_data = {
            'ticket_id': ticket_id,
            'user_id': user_id,
            'subject': subject,
            'description': description,
            'status': 'open',
            'priority': priority,
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat()
        }
        
        logger.info(f"Created ticket: {ticket_data}")
        
        return create_response(201, {
            'message': 'Ticket created successfully',
            'ticket': ticket_data
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