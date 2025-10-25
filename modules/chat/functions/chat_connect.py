import json
import boto3
import os
import logging
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table(os.environ['CONNECTIONS_TABLE'])

def lambda_handler(event, context):
    """
    Handle WebSocket connection establishment
    Store connection info with user context and stream association
    """
    try:
        connection_id = event['requestContext']['connectionId']
        
        # Extract query parameters for user and stream context
        query_params = event.get('queryStringParameters') or {}
        user_id = query_params.get('userId')
        stream_id = query_params.get('streamId')
        username = query_params.get('username', 'Anonymous')
        
        # Calculate expiration time (24 hours from now)
        expires_at = int((datetime.now() + timedelta(hours=24)).timestamp())
        
        # Store connection with context
        connection_item = {
            'connection_id': connection_id,
            'user_id': user_id,
            'stream_id': stream_id,
            'username': username,
            'connected_at': datetime.now().isoformat(),
            'expires_at': expires_at,
            'status': 'connected'
        }
        
        connections_table.put_item(Item=connection_item)
        
        logger.info(f"Connection established: {connection_id} for user {user_id} in stream {stream_id}")
        
        # Send welcome message to the connected user
        apigw = boto3.client('apigatewaymanagementapi',
            endpoint_url=f"https://{event['requestContext']['domainName']}/{event['requestContext']['stage']}")
        
        welcome_message = {
            'type': 'system',
            'message': f'Welcome to the chat, {username}!',
            'timestamp': datetime.now().isoformat()
        }
        
        try:
            apigw.post_to_connection(
                ConnectionId=connection_id,
                Data=json.dumps(welcome_message)
            )
        except Exception as e:
            logger.warning(f"Failed to send welcome message: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Connected successfully'})
        }
        
    except Exception as e:
        logger.error(f"Error handling connection: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Connection failed'})
        }