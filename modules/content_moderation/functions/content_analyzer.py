import json
import boto3
import os
import logging
from datetime import datetime, timedelta
from decimal import Decimal
import base64

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
rekognition = boto3.client('rekognition')
comprehend = boto3.client('comprehend')
dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

# Environment variables
MODERATION_TABLE = os.environ['MODERATION_TABLE']
FLAGGED_CONTENT_BUCKET = os.environ['FLAGGED_CONTENT_BUCKET']
NOTIFICATION_TOPIC = os.environ['NOTIFICATION_TOPIC']

# Initialize DynamoDB table
moderation_table = dynamodb.Table(MODERATION_TABLE)

def lambda_handler(event, context):
    """
    Analyze content using AI services for moderation
    """
    try:
        logger.info(f"Processing moderation event: {json.dumps(event)}")
        
        # Handle different event types
        if 'action' in event and event['action'] == 'scheduled_review':
            return handle_scheduled_review()
        elif 'Records' in event:
            # S3 event for new content
            return handle_s3_event(event)
        elif 'contentType' in event:
            # Direct content analysis request
            return handle_direct_analysis(event)
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid event format'})
            }
            
    except Exception as e:
        logger.error(f"Error processing moderation event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to process moderation event'})
        }

def handle_scheduled_review():
    """Handle scheduled content review"""
    try:
        logger.info("Starting scheduled content review")
        
        # Get pending moderation items from the last hour
        one_hour_ago = (datetime.now() - timedelta(hours=1)).isoformat()
        
        response = moderation_table.scan(
            FilterExpression='#status = :status AND created_at > :timestamp',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'pending',
                ':timestamp': one_hour_ago
            }
        )
        
        pending_items = response.get('Items', [])
        logger.info(f"Found {len(pending_items)} pending moderation items")
        
        processed_count = 0
        for item in pending_items:
            try:
                # Re-analyze items that have been pending too long
                if item.get('content_type') == 'text':
                    result = analyze_text_content(item.get('content', ''))
                elif item.get('content_type') == 'image':
                    result = analyze_image_content(item.get('s3_key', ''))
                else:
                    continue
                
                # Update moderation status
                update_moderation_record(item['moderation_id'], result)
                processed_count += 1
                
            except Exception as e:
                logger.error(f"Error processing item {item.get('moderation_id')}: {str(e)}")
                continue
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Scheduled review completed',
                'processed_items': processed_count
            })
        }
        
    except Exception as e:
        logger.error(f"Error in scheduled review: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to complete scheduled review'})
        }

def handle_s3_event(event):
    """Handle S3 event for new content upload"""
    try:
        processed_count = 0
        
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            logger.info(f"Processing S3 object: {bucket}/{key}")
            
            # Analyze the uploaded content
            result = analyze_image_content(key, bucket)
            
            # Create moderation record
            moderation_id = create_moderation_record({
                'content_type': 'image',
                's3_bucket': bucket,
                's3_key': key,
                'analysis_result': result
            })
            
            processed_count += 1
            
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'S3 content processed',
                'processed_items': processed_count
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing S3 event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to process S3 event'})
        }

def handle_direct_analysis(event):
    """Handle direct content analysis request"""
    try:
        content_type = event.get('contentType')
        content = event.get('content', '')
        user_id = event.get('userId', 'unknown')
        
        if content_type == 'text':
            result = analyze_text_content(content)
        elif content_type == 'image':
            # Expect base64 encoded image or S3 key
            if content.startswith('data:image'):
                # Base64 encoded image
                result = analyze_base64_image(content)
            else:
                # S3 key
                result = analyze_image_content(content)
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Unsupported content type'})
            }
        
        # Create moderation record
        moderation_id = create_moderation_record({
            'content_type': content_type,
            'content': content if content_type == 'text' else '',
            's3_key': content if content_type == 'image' else '',
            'user_id': user_id,
            'analysis_result': result
        })
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'moderationId': moderation_id,
                'result': result
            }, default=decimal_serializer)
        }
        
    except Exception as e:
        logger.error(f"Error in direct analysis: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to analyze content'})
        }

def analyze_text_content(text):
    """Analyze text content using Comprehend"""
    try:
        if not text or len(text.strip()) == 0:
            return {
                'status': 'approved',
                'confidence': 1.0,
                'flags': [],
                'analysis_type': 'text'
            }
        
        flags = []
        max_confidence = 0.0
        
        # Sentiment analysis
        try:
            sentiment_response = comprehend.detect_sentiment(
                Text=text,
                LanguageCode='en'
            )
            
            sentiment = sentiment_response['Sentiment']
            sentiment_confidence = sentiment_response['SentimentScore'][sentiment.title()]
            
            if sentiment == 'NEGATIVE' and sentiment_confidence > 0.8:
                flags.append({
                    'type': 'negative_sentiment',
                    'confidence': float(sentiment_confidence),
                    'details': f"Negative sentiment detected with {sentiment_confidence:.2%} confidence"
                })
                max_confidence = max(max_confidence, sentiment_confidence)
                
        except Exception as e:
            logger.warning(f"Sentiment analysis failed: {str(e)}")
        
        # Toxicity detection (using a simple keyword approach since Comprehend toxicity is limited)
        toxic_keywords = [
            'hate', 'kill', 'die', 'stupid', 'idiot', 'moron', 'retard',
            'nazi', 'terrorist', 'bomb', 'violence', 'murder'
        ]
        
        text_lower = text.lower()
        for keyword in toxic_keywords:
            if keyword in text_lower:
                flags.append({
                    'type': 'toxic_content',
                    'confidence': 0.7,
                    'details': f"Potentially toxic keyword detected: {keyword}"
                })
                max_confidence = max(max_confidence, 0.7)
        
        # PII detection
        try:
            pii_response = comprehend.detect_pii_entities(
                Text=text,
                LanguageCode='en'
            )
            
            pii_entities = pii_response.get('Entities', [])
            if pii_entities:
                for entity in pii_entities:
                    if entity['Score'] > 0.7:
                        flags.append({
                            'type': 'pii_detected',
                            'confidence': float(entity['Score']),
                            'details': f"PII detected: {entity['Type']}"
                        })
                        max_confidence = max(max_confidence, entity['Score'])
                        
        except Exception as e:
            logger.warning(f"PII detection failed: {str(e)}")
        
        # Determine overall status
        if max_confidence > 0.8:
            status = 'flagged'
        elif max_confidence > 0.5:
            status = 'review_required'
        else:
            status = 'approved'
        
        return {
            'status': status,
            'confidence': float(max_confidence),
            'flags': flags,
            'analysis_type': 'text',
            'text_length': len(text)
        }
        
    except Exception as e:
        logger.error(f"Error analyzing text content: {str(e)}")
        return {
            'status': 'error',
            'confidence': 0.0,
            'flags': [{'type': 'analysis_error', 'details': str(e)}],
            'analysis_type': 'text'
        }

def analyze_image_content(s3_key, bucket=None):
    """Analyze image content using Rekognition"""
    try:
        if not bucket:
            bucket = FLAGGED_CONTENT_BUCKET
        
        # Use Rekognition to detect moderation labels
        response = rekognition.detect_moderation_labels(
            Image={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': s3_key
                }
            },
            MinConfidence=50.0
        )
        
        moderation_labels = response.get('ModerationLabels', [])
        flags = []
        max_confidence = 0.0
        
        for label in moderation_labels:
            confidence = label['Confidence'] / 100.0  # Convert to 0-1 scale
            flags.append({
                'type': 'inappropriate_content',
                'confidence': confidence,
                'details': f"Detected: {label['Name']} ({label['Confidence']:.1f}%)",
                'category': label.get('ParentName', label['Name'])
            })
            max_confidence = max(max_confidence, confidence)
        
        # Detect text in image
        try:
            text_response = rekognition.detect_text(
                Image={
                    'S3Object': {
                        'Bucket': bucket,
                        'Name': s3_key
                    }
                }
            )
            
            detected_text = []
            for text_detection in text_response.get('TextDetections', []):
                if text_detection['Type'] == 'LINE' and text_detection['Confidence'] > 80:
                    detected_text.append(text_detection['DetectedText'])
            
            # Analyze detected text if any
            if detected_text:
                combined_text = ' '.join(detected_text)
                text_analysis = analyze_text_content(combined_text)
                
                if text_analysis['status'] in ['flagged', 'review_required']:
                    flags.extend(text_analysis['flags'])
                    max_confidence = max(max_confidence, text_analysis['confidence'])
                    
        except Exception as e:
            logger.warning(f"Text detection in image failed: {str(e)}")
        
        # Determine overall status
        if max_confidence > 0.8:
            status = 'flagged'
        elif max_confidence > 0.5:
            status = 'review_required'
        else:
            status = 'approved'
        
        return {
            'status': status,
            'confidence': float(max_confidence),
            'flags': flags,
            'analysis_type': 'image',
            'moderation_labels_count': len(moderation_labels)
        }
        
    except Exception as e:
        logger.error(f"Error analyzing image content: {str(e)}")
        return {
            'status': 'error',
            'confidence': 0.0,
            'flags': [{'type': 'analysis_error', 'details': str(e)}],
            'analysis_type': 'image'
        }

def analyze_base64_image(base64_data):
    """Analyze base64 encoded image"""
    try:
        # Extract image data from data URL
        if base64_data.startswith('data:image'):
            base64_data = base64_data.split(',')[1]
        
        image_bytes = base64.b64decode(base64_data)
        
        # Use Rekognition to detect moderation labels
        response = rekognition.detect_moderation_labels(
            Image={'Bytes': image_bytes},
            MinConfidence=50.0
        )
        
        moderation_labels = response.get('ModerationLabels', [])
        flags = []
        max_confidence = 0.0
        
        for label in moderation_labels:
            confidence = label['Confidence'] / 100.0
            flags.append({
                'type': 'inappropriate_content',
                'confidence': confidence,
                'details': f"Detected: {label['Name']} ({label['Confidence']:.1f}%)",
                'category': label.get('ParentName', label['Name'])
            })
            max_confidence = max(max_confidence, confidence)
        
        # Determine status
        if max_confidence > 0.8:
            status = 'flagged'
        elif max_confidence > 0.5:
            status = 'review_required'
        else:
            status = 'approved'
        
        return {
            'status': status,
            'confidence': float(max_confidence),
            'flags': flags,
            'analysis_type': 'image',
            'moderation_labels_count': len(moderation_labels)
        }
        
    except Exception as e:
        logger.error(f"Error analyzing base64 image: {str(e)}")
        return {
            'status': 'error',
            'confidence': 0.0,
            'flags': [{'type': 'analysis_error', 'details': str(e)}],
            'analysis_type': 'image'
        }

def create_moderation_record(data):
    """Create a new moderation record in DynamoDB"""
    try:
        moderation_id = f"mod_{int(datetime.now().timestamp() * 1000)}"
        
        item = {
            'moderation_id': moderation_id,
            'content_type': data.get('content_type'),
            'user_id': data.get('user_id', 'unknown'),
            'created_at': datetime.now().isoformat(),
            'status': data['analysis_result']['status'],
            'confidence': Decimal(str(data['analysis_result']['confidence'])),
            'flags': data['analysis_result']['flags'],
            'analysis_type': data['analysis_result']['analysis_type']
        }
        
        # Add content-specific fields
        if data.get('content'):
            item['content'] = data['content']
        if data.get('s3_key'):
            item['s3_key'] = data['s3_key']
        if data.get('s3_bucket'):
            item['s3_bucket'] = data['s3_bucket']
        
        moderation_table.put_item(Item=item)
        
        # Send notification if content is flagged
        if data['analysis_result']['status'] == 'flagged':
            send_moderation_alert(moderation_id, data['analysis_result'])
        
        logger.info(f"Created moderation record: {moderation_id}")
        return moderation_id
        
    except Exception as e:
        logger.error(f"Error creating moderation record: {str(e)}")
        raise

def update_moderation_record(moderation_id, analysis_result):
    """Update existing moderation record"""
    try:
        moderation_table.update_item(
            Key={'moderation_id': moderation_id},
            UpdateExpression='SET #status = :status, confidence = :confidence, flags = :flags, updated_at = :updated_at',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': analysis_result['status'],
                ':confidence': Decimal(str(analysis_result['confidence'])),
                ':flags': analysis_result['flags'],
                ':updated_at': datetime.now().isoformat()
            }
        )
        
        logger.info(f"Updated moderation record: {moderation_id}")
        
    except Exception as e:
        logger.error(f"Error updating moderation record: {str(e)}")
        raise

def send_moderation_alert(moderation_id, analysis_result):
    """Send SNS notification for flagged content"""
    try:
        message = f"""
Content Moderation Alert

Moderation ID: {moderation_id}
Status: {analysis_result['status']}
Confidence: {analysis_result['confidence']:.2%}
Analysis Type: {analysis_result['analysis_type']}

Flags:
"""
        
        for flag in analysis_result['flags']:
            message += f"- {flag['type']}: {flag['details']} (Confidence: {flag['confidence']:.2%})\n"
        
        message += f"\nTimestamp: {datetime.now().isoformat()}"
        
        sns_client.publish(
            TopicArn=NOTIFICATION_TOPIC,
            Subject=f"Content Flagged - {moderation_id}",
            Message=message
        )
        
        logger.info(f"Sent moderation alert for {moderation_id}")
        
    except Exception as e:
        logger.error(f"Error sending moderation alert: {str(e)}")

def decimal_serializer(obj):
    """JSON serializer for Decimal objects"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")