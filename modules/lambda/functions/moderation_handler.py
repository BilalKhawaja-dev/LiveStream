import json
import boto3
import os
import logging
import uuid
from datetime import datetime
from typing import Dict, Any, List, Optional
import base64

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
rekognition_client = boto3.client('rekognition')
comprehend_client = boto3.client('comprehend')
rds_client = boto3.client('rds-data')
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')
secrets_client = boto3.client('secretsmanager')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Content moderation handler using AI services
    Handles image, video, and text moderation using Rekognition and Comprehend
    """
    
    try:
        # Parse the request
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        
        logger.info(f"Processing {http_method} request to {path}")
        
        # Route to appropriate handler
        if path.endswith('/moderate/image') and http_method == 'POST':
            return handle_image_moderation(body)
        elif path.endswith('/moderate/text') and http_method == 'POST':
            return handle_text_moderation(body)
        elif path.endswith('/moderate/stream') and http_method == 'POST':
            return handle_stream_moderation(body)
        elif path.endswith('/moderate/batch') and http_method == 'POST':
            return handle_batch_moderation(body)
        elif '/moderation/' in path and http_method == 'GET':
            content_id = path.split('/moderation/')[-1]
            return handle_get_moderation_result(content_id)
        else:
            return create_response(400, {'error': 'Invalid endpoint or method'})
            
    except Exception as e:
        logger.error(f"Moderation handler error: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_image_moderation(body: Dict[str, Any]) -> Dict[str, Any]:
    """Moderate image content using Rekognition"""
    
    try:
        content_id = body.get('content_id')
        user_id = body.get('user_id')
        image_data = body.get('image_data')  # Base64 encoded image
        s3_bucket = body.get('s3_bucket')
        s3_key = body.get('s3_key')
        
        if not content_id or not user_id:
            return create_response(400, {'error': 'Content ID and user ID required'})
        
        if not image_data and not (s3_bucket and s3_key):
            return create_response(400, {'error': 'Image data or S3 location required'})
        
        # Prepare image for Rekognition
        if image_data:
            # Decode base64 image
            image_bytes = base64.b64decode(image_data)
            image_source = {'Bytes': image_bytes}
        else:
            # Use S3 image
            image_source = {
                'S3Object': {
                    'Bucket': s3_bucket,
                    'Name': s3_key
                }
            }
        
        # Detect moderation labels
        moderation_response = rekognition_client.detect_moderation_labels(
            Image=image_source,
            MinConfidence=float(os.environ.get('REKOGNITION_MIN_CONFIDENCE', 80))
        )
        
        # Detect text in image (for additional context)
        text_response = None
        try:
            text_response = rekognition_client.detect_text(Image=image_source)
        except Exception as e:
            logger.warning(f"Text detection failed: {str(e)}")
        
        # Analyze results
        moderation_labels = moderation_response.get('ModerationLabels', [])
        detected_text = []
        
        if text_response:
            detected_text = [
                text['DetectedText'] 
                for text in text_response.get('TextDetections', [])
                if text['Type'] == 'LINE'
            ]
        
        # Determine moderation status
        max_confidence = max([label['Confidence'] for label in moderation_labels], default=0)
        
        if max_confidence >= float(os.environ.get('REKOGNITION_MIN_CONFIDENCE', 80)):
            status = 'flagged'
        elif max_confidence >= 50:
            status = 'under_review'
        else:
            status = 'approved'
        
        # Additional text moderation if text detected
        text_moderation_result = None
        if detected_text:
            combined_text = ' '.join(detected_text)
            text_moderation_result = moderate_text_content(combined_text)
            
            # Update status based on text moderation
            if text_moderation_result['status'] == 'flagged':
                status = 'flagged'
            elif text_moderation_result['status'] == 'under_review' and status == 'approved':
                status = 'under_review'
        
        # Store moderation result
        moderation_id = str(uuid.uuid4())
        
        flags = {
            'moderation_labels': moderation_labels,
            'detected_text': detected_text,
            'text_moderation': text_moderation_result,
            'max_confidence': max_confidence
        }
        
        store_moderation_result(
            moderation_id=moderation_id,
            content_type='image',
            content_id=content_id,
            user_id=user_id,
            moderation_service='rekognition',
            confidence_score=max_confidence / 100,
            flags=flags,
            status=status
        )
        
        # Send notification if content is flagged
        if status == 'flagged':
            send_moderation_notification(content_id, 'image', status, flags)
        
        return create_response(200, {
            'moderation_id': moderation_id,
            'content_id': content_id,
            'status': status,
            'confidence': max_confidence,
            'moderation_labels': moderation_labels,
            'detected_text': detected_text,
            'text_moderation': text_moderation_result
        })
        
    except Exception as e:
        logger.error(f"Image moderation error: {str(e)}")
        return create_response(500, {'error': 'Failed to moderate image'})

def handle_text_moderation(body: Dict[str, Any]) -> Dict[str, Any]:
    """Moderate text content using Comprehend"""
    
    try:
        content_id = body.get('content_id')
        user_id = body.get('user_id')
        text = body.get('text')
        content_type = body.get('content_type', 'text')
        
        if not content_id or not user_id or not text:
            return create_response(400, {'error': 'Content ID, user ID, and text required'})
        
        # Moderate text content
        moderation_result = moderate_text_content(text)
        
        # Store moderation result
        moderation_id = str(uuid.uuid4())
        
        store_moderation_result(
            moderation_id=moderation_id,
            content_type=content_type,
            content_id=content_id,
            user_id=user_id,
            moderation_service='comprehend',
            confidence_score=moderation_result['confidence'],
            flags=moderation_result['flags'],
            status=moderation_result['status']
        )
        
        # Send notification if content is flagged
        if moderation_result['status'] == 'flagged':
            send_moderation_notification(content_id, content_type, moderation_result['status'], moderation_result['flags'])
        
        return create_response(200, {
            'moderation_id': moderation_id,
            'content_id': content_id,
            'status': moderation_result['status'],
            'confidence': moderation_result['confidence'],
            'sentiment': moderation_result['sentiment'],
            'toxic_content': moderation_result['toxic_content'],
            'pii_entities': moderation_result['pii_entities']
        })
        
    except Exception as e:
        logger.error(f"Text moderation error: {str(e)}")
        return create_response(500, {'error': 'Failed to moderate text'})

def handle_stream_moderation(body: Dict[str, Any]) -> Dict[str, Any]:
    """Moderate live stream content"""
    
    try:
        stream_id = body.get('stream_id')
        user_id = body.get('user_id')
        frame_data = body.get('frame_data')  # Base64 encoded frame
        timestamp = body.get('timestamp')
        
        if not stream_id or not user_id or not frame_data:
            return create_response(400, {'error': 'Stream ID, user ID, and frame data required'})
        
        # Decode frame data
        frame_bytes = base64.b64decode(frame_data)
        
        # Moderate frame using Rekognition
        moderation_response = rekognition_client.detect_moderation_labels(
            Image={'Bytes': frame_bytes},
            MinConfidence=float(os.environ.get('REKOGNITION_MIN_CONFIDENCE', 80))
        )
        
        moderation_labels = moderation_response.get('ModerationLabels', [])
        max_confidence = max([label['Confidence'] for label in moderation_labels], default=0)
        
        # Determine action based on confidence
        if max_confidence >= float(os.environ.get('REKOGNITION_MIN_CONFIDENCE', 80)):
            status = 'flagged'
            action = 'suspend_stream'
        elif max_confidence >= 60:
            status = 'under_review'
            action = 'flag_for_review'
        else:
            status = 'approved'
            action = 'continue'
        
        # Store moderation result
        moderation_id = str(uuid.uuid4())
        
        flags = {
            'moderation_labels': moderation_labels,
            'max_confidence': max_confidence,
            'timestamp': timestamp,
            'action_taken': action
        }
        
        store_moderation_result(
            moderation_id=moderation_id,
            content_type='stream',
            content_id=stream_id,
            user_id=user_id,
            moderation_service='rekognition',
            confidence_score=max_confidence / 100,
            flags=flags,
            status=status
        )
        
        # Send immediate notification for flagged content
        if status == 'flagged':
            send_moderation_notification(stream_id, 'stream', status, flags)
        
        return create_response(200, {
            'moderation_id': moderation_id,
            'stream_id': stream_id,
            'status': status,
            'action': action,
            'confidence': max_confidence,
            'moderation_labels': moderation_labels,
            'timestamp': timestamp
        })
        
    except Exception as e:
        logger.error(f"Stream moderation error: {str(e)}")
        return create_response(500, {'error': 'Failed to moderate stream'})

def moderate_text_content(text: str) -> Dict[str, Any]:
    """Moderate text content using Comprehend"""
    
    try:
        # Detect sentiment
        sentiment_response = comprehend_client.detect_sentiment(
            Text=text,
            LanguageCode='en'
        )
        
        # Detect toxic content (if available in region)
        toxic_content = None
        try:
            toxic_response = comprehend_client.detect_toxic_content(
                TextSegments=[{'Text': text}],
                LanguageCode='en'
            )
            toxic_content = toxic_response.get('ResultList', [])
        except Exception as e:
            logger.warning(f"Toxic content detection not available: {str(e)}")
        
        # Detect PII entities
        pii_response = comprehend_client.detect_pii_entities(
            Text=text,
            LanguageCode='en'
        )
        
        pii_entities = pii_response.get('Entities', [])
        
        # Analyze results
        sentiment = sentiment_response.get('Sentiment', 'NEUTRAL')
        sentiment_scores = sentiment_response.get('SentimentScore', {})
        
        # Determine moderation status
        max_toxic_score = 0
        if toxic_content:
            max_toxic_score = max([
                max(segment.get('Toxicity', {}).values(), default=0)
                for segment in toxic_content
            ], default=0)
        
        # Check for high negative sentiment or toxic content
        negative_score = sentiment_scores.get('Negative', 0)
        
        confidence = max(max_toxic_score, negative_score)
        min_confidence = float(os.environ.get('COMPREHEND_MIN_CONFIDENCE', 70)) / 100
        
        if confidence >= min_confidence or len(pii_entities) > 0:
            status = 'flagged'
        elif confidence >= 0.5 or sentiment == 'NEGATIVE':
            status = 'under_review'
        else:
            status = 'approved'
        
        return {
            'status': status,
            'confidence': confidence,
            'sentiment': sentiment,
            'sentiment_scores': sentiment_scores,
            'toxic_content': toxic_content,
            'pii_entities': pii_entities,
            'flags': {
                'sentiment': sentiment,
                'toxic_score': max_toxic_score,
                'pii_count': len(pii_entities),
                'negative_score': negative_score
            }
        }
        
    except Exception as e:
        logger.error(f"Text moderation error: {str(e)}")
        return {
            'status': 'approved',
            'confidence': 0.0,
            'sentiment': 'NEUTRAL',
            'sentiment_scores': {},
            'toxic_content': None,
            'pii_entities': [],
            'flags': {'error': str(e)}
        }

def store_moderation_result(moderation_id: str, content_type: str, content_id: str, 
                          user_id: str, moderation_service: str, confidence_score: float,
                          flags: Dict[str, Any], status: str) -> None:
    """Store moderation result in database"""
    
    try:
        sql = """
        INSERT INTO content_moderation (
            id, content_type, content_id, user_id, moderation_service,
            confidence_score, flags, status, created_at
        ) VALUES (
            :moderation_id, :content_type, :content_id, :user_id, :moderation_service,
            :confidence_score, :flags, :status, NOW()
        )
        """
        
        parameters = [
            {'name': 'moderation_id', 'value': {'stringValue': moderation_id}},
            {'name': 'content_type', 'value': {'stringValue': content_type}},
            {'name': 'content_id', 'value': {'stringValue': content_id}},
            {'name': 'user_id', 'value': {'stringValue': user_id}},
            {'name': 'moderation_service', 'value': {'stringValue': moderation_service}},
            {'name': 'confidence_score', 'value': {'doubleValue': confidence_score}},
            {'name': 'flags', 'value': {'stringValue': json.dumps(flags)}},
            {'name': 'status', 'value': {'stringValue': status}}
        ]
        
        rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
    except Exception as e:
        logger.error(f"Store moderation result error: {str(e)}")

def send_moderation_notification(content_id: str, content_type: str, status: str, flags: Dict[str, Any]) -> None:
    """Send moderation notification via SNS"""
    
    try:
        message = {
            'content_id': content_id,
            'content_type': content_type,
            'status': status,
            'flags': flags,
            'timestamp': datetime.utcnow().isoformat(),
            'requires_action': status == 'flagged'
        }
        
        sns_client.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Message=json.dumps(message),
            Subject=f'Content Moderation Alert: {content_type.title()} {status.title()}'
        )
        
    except Exception as e:
        logger.error(f"Send moderation notification error: {str(e)}")

def handle_get_moderation_result(content_id: str) -> Dict[str, Any]:
    """Get moderation results for content"""
    
    try:
        sql = """
        SELECT id, content_type, moderation_service, confidence_score, 
               flags, status, created_at, reviewed_by, reviewed_at
        FROM content_moderation 
        WHERE content_id = :content_id 
        ORDER BY created_at DESC
        """
        
        parameters = [{'name': 'content_id', 'value': {'stringValue': content_id}}]
        
        result = rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        moderation_results = []
        for record in result['records']:
            moderation_result = {
                'id': record[0]['stringValue'],
                'content_type': record[1]['stringValue'],
                'moderation_service': record[2]['stringValue'],
                'confidence_score': record[3]['doubleValue'],
                'flags': json.loads(record[4]['stringValue']),
                'status': record[5]['stringValue'],
                'created_at': record[6]['stringValue'],
                'reviewed_by': record[7].get('stringValue') if record[7].get('stringValue') else None,
                'reviewed_at': record[8].get('stringValue') if record[8].get('stringValue') else None
            }
            moderation_results.append(moderation_result)
        
        return create_response(200, {
            'content_id': content_id,
            'moderation_results': moderation_results,
            'total_results': len(moderation_results)
        })
        
    except Exception as e:
        logger.error(f"Get moderation result error: {str(e)}")
        return create_response(500, {'error': 'Failed to get moderation results'})

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