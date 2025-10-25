import json
import boto3
import os
import logging
from datetime import datetime, timedelta
import uuid
import re

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table(os.environ['CONNECTIONS_TABLE'])
messages_table = dynamodb.Table(os.environ['MESSAGES_TABLE'])
comprehend = boto3.client('comprehend')

def moderate_message(message_text):
    """
    Use AWS Comprehend to moderate chat messages
    Returns moderation result with confidence scores
    """
    try:
        # Detect sentiment
        sentiment_response = comprehend.detect_sentiment(
            Text=message_text,
            LanguageCode='en'
        )
        
        # Detect toxic content using PII detection as a proxy
        pii_response = comprehend.detect_pii_entities(
            Text=message_text,
            LanguageCode='en'
        )
        
        # Simple profanity filter (basic implementation)
        profanity_words = [
            'spam', 'scam', 'fake', 'bot', 'hack', 'cheat',
            # Add more words as needed
        ]
        
        contains_profanity = any(word.lower() in message_text.lower() for word in profanity_words)
        
        # Determine if message should be blocked
        sentiment = sentiment_response['Sentiment']
        negative_confidence = sentiment_response['SentimentScore'].get('Negative', 0)
        
        is_blocked = (
            sentiment == 'NEGATIVE' and negative_confidence > 0.8 or
            contains_profanity or
            len(pii_response['Entities']) > 0  # Contains PII
        )
        
        return {
            'is_blocked': is_blocked,
            'sentiment': sentiment,
            'confidence': negative_confidence,
            'reason': 'High negative sentiment' if negative_confidence > 0.8 else 
                     'Contains profanity' if contains_profanity else
                     'Contains PII' if len(pii_response['Entities']) > 0 else 'Clean',
            'pii_entities': len(pii_response['Entities'])
        }
        
    except Exception as e:
        logger.warning(f"Moderation failed: {str(e)}")
        # If moderation fails, allow the message but log the failure
        return {
            'is_blocked': False,
            'sentiment': 'UNKNOWN',
            'confidence': 0,
            'reason': 'Moderation service unavailable',
            'pii_entities': 0
        }

def lambda_handler(event, context):
    """
    Handle chat message sending with AI moderation and broadcasting
    """
    try:
        connection_id = event['requestContext']['connectionId']
        
        # Parse message body
        try:
            body = json.loads(event['body'])
        except json.JSONDecodeError:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid JSON in message body'})
            }
        
        # Extract message data
        stream_id = body.get('streamId')
        user_id = body.get('userId')
        username = body.get('username', 'Anonymous')
        message_text = body.get('message', '').strip()
        
        # Validate required fields
        if not all([stream_id, user_id, message_text]):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required fields: streamId, userId, message'})
            }
        
        # Validate message length
        if len(message_text) > 500:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Message too long (max 500 characters)'})
            }
        
        # Verify connection exists and matches user
        try:
            connection_response = connections_table.get_item(Key={'connection_id': connection_id})
            if 'Item' not in connection_response:
                return {
                    'statusCode': 403,
                    'body': json.dumps({'error': 'Connection not found'})
                }
            
            connection_info = connection_response['Item']
            if connection_info.get('user_id') != user_id:
                return {
                    'statusCode': 403,
                    'body': json.dumps({'error': 'User ID mismatch'})
                }
                
        except Exception as e:
            logger.error(f"Error verifying connection: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Connection verification failed'})
            }
        
        # Moderate the message
        moderation_result = moderate_message(message_text)
        
        # Block message if moderation fails
        if moderation_result['is_blocked']:
            logger.warning(f"Message blocked for user {user_id}: {moderation_result['reason']}")
            
            # Send moderation notice to sender
            apigw = boto3.client('apigatewaymanagementapi',
                endpoint_url=f"https://{event['requestContext']['domainName']}/{event['requestContext']['stage']}")
            
            moderation_notice = {
                'type': 'moderation',
                'message': f'Your message was blocked: {moderation_result["reason"]}',
                'timestamp': datetime.now().isoformat()
            }
            
            try:
                apigw.post_to_connection(
                    ConnectionId=connection_id,
                    Data=json.dumps(moderation_notice)
                )
            except Exception as e:
                logger.warning(f"Failed to send moderation notice: {str(e)}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Message blocked by moderation'})
            }
        
        # Create message record
        message_id = str(uuid.uuid4())
        timestamp = datetime.now().isoformat()
        expires_at = int((datetime.now() + timedelta(days=1)).timestamp())  # TTL: 24 hours
        
        message_item = {
            'stream_id': stream_id,
            'timestamp': timestamp,
            'message_id': message_id,
            'user_id': user_id,
            'username': username,
            'message': message_text,
            'moderation': moderation_result,
            'expires_at': expires_at,
            'created_at': timestamp
        }
        
        # Store message in DynamoDB
        messages_table.put_item(Item=message_item)
        
        # Get all connections for the stream
        stream_connections = connections_table.scan(
            FilterExpression='stream_id = :stream_id',
            ExpressionAttributeValues={':stream_id': stream_id}
        )
        
        if not stream_connections['Items']:
            logger.warning(f"No connections found for stream {stream_id}")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Message stored but no active connections'})
            }
        
        # Prepare broadcast message
        broadcast_message = {
            'type': 'message',
            'messageId': message_id,
            'streamId': stream_id,
            'userId': user_id,
            'username': username,
            'message': message_text,
            'timestamp': timestamp,
            'sentiment': moderation_result['sentiment']
        }
        
        # Initialize API Gateway Management API client
        apigw = boto3.client('apigatewaymanagementapi',
            endpoint_url=f"https://{event['requestContext']['domainName']}/{event['requestContext']['stage']}")
        
        # Broadcast to all connections in the stream
        successful_broadcasts = 0
        failed_connections = []
        
        for connection in stream_connections['Items']:
            try:
                apigw.post_to_connection(
                    ConnectionId=connection['connection_id'],
                    Data=json.dumps(broadcast_message)
                )
                successful_broadcasts += 1
                
            except apigw.exceptions.GoneException:
                # Connection is stale, mark for cleanup
                failed_connections.append(connection['connection_id'])
                logger.info(f"Stale connection detected: {connection['connection_id']}")
                
            except Exception as e:
                logger.warning(f"Failed to send message to {connection['connection_id']}: {str(e)}")
                failed_connections.append(connection['connection_id'])
        
        # Clean up stale connections
        for failed_conn_id in failed_connections:
            try:
                connections_table.delete_item(Key={'connection_id': failed_conn_id})
                logger.info(f"Cleaned up stale connection: {failed_conn_id}")
            except Exception as e:
                logger.warning(f"Failed to clean up connection {failed_conn_id}: {str(e)}")
        
        logger.info(f"Message broadcast completed: {successful_broadcasts} successful, {len(failed_connections)} failed")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Message sent successfully',
                'messageId': message_id,
                'broadcastCount': successful_broadcasts
            })
        }
        
    except Exception as e:
        logger.error(f"Error handling message: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Message processing failed'})
        }