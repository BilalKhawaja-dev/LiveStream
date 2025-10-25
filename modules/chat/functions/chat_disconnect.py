import json
import boto3
import os
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table(os.environ['CONNECTIONS_TABLE'])

def lambda_handler(event, context):
    """
    Handle WebSocket disconnection
    Clean up connection record and update user status
    """
    try:
        connection_id = event['requestContext']['connectionId']
        
        # Get connection info before deletion for logging
        try:
            response = connections_table.get_item(Key={'connection_id': connection_id})
            connection_info = response.get('Item', {})
            user_id = connection_info.get('user_id', 'unknown')
            stream_id = connection_info.get('stream_id', 'unknown')
            username = connection_info.get('username', 'Anonymous')
            
            logger.info(f"Disconnecting user {username} ({user_id}) from stream {stream_id}")
            
        except Exception as e:
            logger.warning(f"Could not retrieve connection info: {str(e)}")
            user_id = 'unknown'
            stream_id = 'unknown'
            username = 'Anonymous'
        
        # Delete the connection record
        connections_table.delete_item(Key={'connection_id': connection_id})
        
        # Notify other users in the same stream about the disconnection
        if stream_id != 'unknown':
            try:
                # Get all connections for the same stream
                stream_connections = connections_table.scan(
                    FilterExpression='stream_id = :stream_id AND connection_id <> :conn_id',
                    ExpressionAttributeValues={
                        ':stream_id': stream_id,
                        ':conn_id': connection_id
                    }
                )
                
                if stream_connections['Items']:
                    apigw = boto3.client('apigatewaymanagementapi',
                        endpoint_url=f"https://{event['requestContext']['domainName']}/{event['requestContext']['stage']}")
                    
                    disconnect_message = {
                        'type': 'user_left',
                        'message': f'{username} left the chat',
                        'user_id': user_id,
                        'username': username,
                        'timestamp': datetime.now().isoformat()
                    }
                    
                    # Broadcast to remaining connections
                    for connection in stream_connections['Items']:
                        try:
                            apigw.post_to_connection(
                                ConnectionId=connection['connection_id'],
                                Data=json.dumps(disconnect_message)
                            )
                        except Exception as e:
                            logger.warning(f"Failed to notify connection {connection['connection_id']}: {str(e)}")
                            # Clean up stale connection
                            try:
                                connections_table.delete_item(Key={'connection_id': connection['connection_id']})
                            except:
                                pass
                                
            except Exception as e:
                logger.warning(f"Failed to broadcast disconnect message: {str(e)}")
        
        logger.info(f"Connection {connection_id} disconnected successfully")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Disconnected successfully'})
        }
        
    except Exception as e:
        logger.error(f"Error handling disconnection: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Disconnection failed'})
        }