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
rekognition_client = boto3.client('rekognition')
comprehend_client = boto3.client('comprehend')

def lambda_handler(event, context):
    """
    Handle content moderation requests
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
        if path == '/moderation/image' and http_method == 'POST':
            return handle_image_moderation(body)
        elif path == '/moderation/text' and http_method == 'POST':
            return handle_text_moderation(body)
        elif path == '/moderation/stream' and http_method == 'POST':
            return handle_stream_moderation(body)
        else:
            return create_response(404, {'error': 'Endpoint not found'})
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_image_moderation(body):
    """Handle image content moderation"""
    try:
        image_url = body.get('image_url')
        s3_bucket = body.get('s3_bucket')
        s3_key = body.get('s3_key')
        
        if not any([image_url, (s3_bucket and s3_key)]):
            return create_response(400, {'error': 'Image URL or S3 location required'})
        
        # Mock moderation result (replace with actual Rekognition call)
        moderation_labels = [
            {
                'Name': 'Explicit Nudity',
                'Confidence': random.uniform(10, 95),
                'ParentName': 'Suggestive'
            },
            {
                'Name': 'Violence',
                'Confidence': random.uniform(5, 30),
                'ParentName': 'Violence'
            }
        ]
        
        # Filter labels above confidence threshold
        threshold = 80.0
        flagged_labels = [label for label in moderation_labels if label['Confidence'] > threshold]
        
        result = {
            'moderation_result': 'approved' if not flagged_labels else 'rejected',
            'confidence_threshold': threshold,
            'flagged_labels': flagged_labels,
            'all_labels': moderation_labels,
            'timestamp': datetime.now().isoformat()
        }
        
        return create_response(200, result)
        
    except Exception as e:
        logger.error(f"Image moderation error: {str(e)}")
        return create_response(500, {'error': 'Failed to moderate image'})

def handle_text_moderation(body):
    """Handle text content moderation"""
    try:
        text_content = body.get('text')
        
        if not text_content:
            return create_response(400, {'error': 'Text content required'})
        
        # Mock text moderation (replace with actual Comprehend call)
        sentiment_score = random.uniform(-1, 1)
        toxicity_score = random.uniform(0, 1)
        
        # Simple keyword-based flagging for demo
        flagged_keywords = ['spam', 'hate', 'abuse', 'inappropriate']
        detected_keywords = [word for word in flagged_keywords if word.lower() in text_content.lower()]
        
        result = {
            'moderation_result': 'approved' if toxicity_score < 0.7 and not detected_keywords else 'rejected',
            'sentiment_score': round(sentiment_score, 3),
            'toxicity_score': round(toxicity_score, 3),
            'detected_keywords': detected_keywords,
            'confidence': round(random.uniform(0.8, 0.95), 3),
            'timestamp': datetime.now().isoformat()
        }
        
        return create_response(200, result)
        
    except Exception as e:
        logger.error(f"Text moderation error: {str(e)}")
        return create_response(500, {'error': 'Failed to moderate text'})

def handle_stream_moderation(body):
    """Handle live stream content moderation"""
    try:
        stream_id = body.get('stream_id')
        frame_url = body.get('frame_url')
        
        if not all([stream_id, frame_url]):
            return create_response(400, {'error': 'Stream ID and frame URL required'})
        
        # Mock stream moderation (replace with actual analysis)
        moderation_score = random.uniform(0, 1)
        
        result = {
            'stream_id': stream_id,
            'moderation_result': 'approved' if moderation_score < 0.8 else 'flagged',
            'moderation_score': round(moderation_score, 3),
            'action_required': moderation_score > 0.9,
            'timestamp': datetime.now().isoformat()
        }
        
        # If action required, log for manual review
        if result['action_required']:
            logger.warning(f"Stream {stream_id} flagged for manual review: score {moderation_score}")
        
        return create_response(200, result)
        
    except Exception as e:
        logger.error(f"Stream moderation error: {str(e)}")
        return create_response(500, {'error': 'Failed to moderate stream'})

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