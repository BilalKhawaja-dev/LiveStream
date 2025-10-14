import json
import boto3
import os
import logging
import uuid
from datetime import datetime, timedelta
from typing import Dict, Any, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
rds_client = boto3.client('rds-data')
dynamodb = boto3.resource('dynamodb')
medialive_client = boto3.client('medialive')
s3_client = boto3.client('s3')
cloudfront_client = boto3.client('cloudfront')
secrets_client = boto3.client('secretsmanager')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Streaming management handler for live streaming platform
    Handles stream creation, management, and analytics
    """
    
    try:
        # Parse the request
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        query_params = event.get('queryStringParameters') or {}
        
        logger.info(f"Processing {http_method} request to {path}")
        
        # Route to appropriate handler
        if path.endswith('/streams') and http_method == 'POST':
            return handle_create_stream(body)
        elif path.endswith('/streams') and http_method == 'GET':
            return handle_list_streams(query_params)
        elif '/streams/' in path and http_method == 'GET':
            stream_id = path.split('/streams/')[-1]
            return handle_get_stream(stream_id)
        elif '/streams/' in path and http_method == 'PUT':
            stream_id = path.split('/streams/')[-1]
            return handle_update_stream(stream_id, body)
        elif '/streams/' in path and http_method == 'DELETE':
            stream_id = path.split('/streams/')[-1]
            return handle_delete_stream(stream_id)
        elif path.endswith('/live') and http_method == 'POST':
            return handle_start_stream(body)
        elif path.endswith('/live') and http_method == 'DELETE':
            return handle_stop_stream(body)
        elif path.endswith('/metrics') and http_method == 'GET':
            return handle_get_metrics(query_params)
        else:
            return create_response(400, {'error': 'Invalid endpoint or method'})
            
    except Exception as e:
        logger.error(f"Streaming handler error: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_create_stream(body: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new stream configuration"""
    
    try:
        creator_id = body.get('creator_id')
        title = body.get('title')
        description = body.get('description', '')
        category = body.get('category', 'general')
        scheduled_start = body.get('scheduled_start')
        
        if not creator_id or not title:
            return create_response(400, {'error': 'Creator ID and title required'})
        
        stream_id = str(uuid.uuid4())
        s3_media_prefix = f"streams/{creator_id}/{stream_id}"
        
        # Insert stream into Aurora database
        db_secret = get_db_secret()
        
        sql = """
        INSERT INTO streams (
            id, creator_id, title, description, category, 
            s3_media_prefix, scheduled_start, status, created_at
        ) VALUES (
            :stream_id, :creator_id, :title, :description, :category,
            :s3_media_prefix, :scheduled_start, 'scheduled', NOW()
        )
        """
        
        parameters = [
            {'name': 'stream_id', 'value': {'stringValue': stream_id}},
            {'name': 'creator_id', 'value': {'stringValue': creator_id}},
            {'name': 'title', 'value': {'stringValue': title}},
            {'name': 'description', 'value': {'stringValue': description}},
            {'name': 'category', 'value': {'stringValue': category}},
            {'name': 's3_media_prefix', 'value': {'stringValue': s3_media_prefix}},
            {'name': 'scheduled_start', 'value': {'stringValue': scheduled_start} if scheduled_start else {'isNull': True}}
        ]
        
        rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        # Store stream metadata in DynamoDB for real-time access
        streams_table = dynamodb.Table(os.environ['DYNAMODB_STREAMS_TABLE'])
        streams_table.put_item(
            Item={
                'stream_id': stream_id,
                'creator_id': creator_id,
                'title': title,
                'status': 'scheduled',
                'viewer_count': 0,
                'created_at': datetime.utcnow().isoformat(),
                'ttl': int((datetime.utcnow() + timedelta(days=30)).timestamp())
            }
        )
        
        return create_response(201, {
            'stream_id': stream_id,
            'title': title,
            'status': 'scheduled',
            's3_media_prefix': s3_media_prefix,
            'created_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Create stream error: {str(e)}")
        return create_response(500, {'error': 'Failed to create stream'})

def handle_start_stream(body: Dict[str, Any]) -> Dict[str, Any]:
    """Start a live stream"""
    
    try:
        stream_id = body.get('stream_id')
        
        if not stream_id:
            return create_response(400, {'error': 'Stream ID required'})
        
        # Get stream details from database
        db_secret = get_db_secret()
        
        sql = "SELECT * FROM streams WHERE id = :stream_id"
        parameters = [{'name': 'stream_id', 'value': {'stringValue': stream_id}}]
        
        result = rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        if not result['records']:
            return create_response(404, {'error': 'Stream not found'})
        
        # Create MediaLive channel if MediaLive is enabled
        medialive_channel_id = None
        if os.environ.get('MEDIALIVE_ROLE_ARN'):
            try:
                medialive_channel_id = create_medialive_channel(stream_id)
            except Exception as e:
                logger.warning(f"MediaLive channel creation failed: {str(e)}")
        
        # Update stream status to live
        update_sql = """
        UPDATE streams 
        SET status = 'live', 
            actual_start = NOW(),
            media_live_channel_id = :channel_id
        WHERE id = :stream_id
        """
        
        update_params = [
            {'name': 'stream_id', 'value': {'stringValue': stream_id}},
            {'name': 'channel_id', 'value': {'stringValue': medialive_channel_id} if medialive_channel_id else {'isNull': True}}
        ]
        
        rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=update_sql,
            parameters=update_params
        )
        
        # Update DynamoDB
        streams_table = dynamodb.Table(os.environ['DYNAMODB_STREAMS_TABLE'])
        streams_table.update_item(
            Key={'stream_id': stream_id},
            UpdateExpression='SET #status = :status, actual_start = :start_time',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'live',
                ':start_time': datetime.utcnow().isoformat()
            }
        )
        
        return create_response(200, {
            'stream_id': stream_id,
            'status': 'live',
            'medialive_channel_id': medialive_channel_id,
            'started_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Start stream error: {str(e)}")
        return create_response(500, {'error': 'Failed to start stream'})

def handle_stop_stream(body: Dict[str, Any]) -> Dict[str, Any]:
    """Stop a live stream"""
    
    try:
        stream_id = body.get('stream_id')
        
        if not stream_id:
            return create_response(400, {'error': 'Stream ID required'})
        
        # Get stream details
        db_secret = get_db_secret()
        
        sql = "SELECT media_live_channel_id FROM streams WHERE id = :stream_id AND status = 'live'"
        parameters = [{'name': 'stream_id', 'value': {'stringValue': stream_id}}]
        
        result = rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        if not result['records']:
            return create_response(404, {'error': 'Live stream not found'})
        
        # Stop MediaLive channel if it exists
        medialive_channel_id = result['records'][0][0].get('stringValue')
        if medialive_channel_id:
            try:
                medialive_client.stop_channel(ChannelId=medialive_channel_id)
            except Exception as e:
                logger.warning(f"Failed to stop MediaLive channel: {str(e)}")
        
        # Update stream status to ended
        update_sql = """
        UPDATE streams 
        SET status = 'ended', end_time = NOW()
        WHERE id = :stream_id
        """
        
        update_params = [{'name': 'stream_id', 'value': {'stringValue': stream_id}}]
        
        rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=update_sql,
            parameters=update_params
        )
        
        # Update DynamoDB
        streams_table = dynamodb.Table(os.environ['DYNAMODB_STREAMS_TABLE'])
        streams_table.update_item(
            Key={'stream_id': stream_id},
            UpdateExpression='SET #status = :status, end_time = :end_time',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'ended',
                ':end_time': datetime.utcnow().isoformat()
            }
        )
        
        return create_response(200, {
            'stream_id': stream_id,
            'status': 'ended',
            'ended_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Stop stream error: {str(e)}")
        return create_response(500, {'error': 'Failed to stop stream'})

def handle_list_streams(query_params: Dict[str, Any]) -> Dict[str, Any]:
    """List streams with optional filtering"""
    
    try:
        creator_id = query_params.get('creator_id')
        status = query_params.get('status')
        limit = int(query_params.get('limit', 20))
        offset = int(query_params.get('offset', 0))
        
        # Build SQL query
        sql = "SELECT * FROM streams WHERE 1=1"
        parameters = []
        
        if creator_id:
            sql += " AND creator_id = :creator_id"
            parameters.append({'name': 'creator_id', 'value': {'stringValue': creator_id}})
        
        if status:
            sql += " AND status = :status"
            parameters.append({'name': 'status', 'value': {'stringValue': status}})
        
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
        
        streams = []
        for record in result['records']:
            stream = {
                'id': record[0]['stringValue'],
                'creator_id': record[1]['stringValue'],
                'title': record[2]['stringValue'],
                'description': record[3].get('stringValue', ''),
                'category': record[4].get('stringValue', ''),
                'status': record[5]['stringValue'],
                'viewer_count': record[6].get('longValue', 0),
                'created_at': record[7]['stringValue']
            }
            streams.append(stream)
        
        return create_response(200, {
            'streams': streams,
            'total': len(streams),
            'limit': limit,
            'offset': offset
        })
        
    except Exception as e:
        logger.error(f"List streams error: {str(e)}")
        return create_response(500, {'error': 'Failed to list streams'})

def create_medialive_channel(stream_id: str) -> str:
    """Create MediaLive channel for live streaming"""
    
    try:
        channel_name = f"stream-{stream_id}"
        
        # Basic MediaLive channel configuration
        channel_config = {
            'Name': channel_name,
            'InputSpecification': {
                'Codec': 'AVC',
                'MaximumBitrate': 'MAX_20_MBPS',
                'Resolution': 'HD'
            },
            'Destinations': [
                {
                    'Id': 'destination1',
                    'Settings': [
                        {
                            'Url': f"s3://{os.environ['S3_MEDIA_BUCKET']}/live/{stream_id}/",
                            'Username': '',
                            'PasswordParam': ''
                        }
                    ]
                }
            ],
            'EncoderSettings': {
                'AudioDescriptions': [
                    {
                        'AudioSelectorName': 'default',
                        'Name': 'audio_1',
                        'CodecSettings': {
                            'AacSettings': {
                                'Bitrate': 96000,
                                'CodingMode': 'CODING_MODE_2_0',
                                'InputType': 'NORMAL',
                                'Profile': 'LC',
                                'RateControlMode': 'CBR',
                                'RawFormat': 'NONE',
                                'SampleRate': 48000,
                                'Spec': 'MPEG4'
                            }
                        }
                    }
                ],
                'VideoDescriptions': [
                    {
                        'Name': 'video_1080p',
                        'CodecSettings': {
                            'H264Settings': {
                                'Bitrate': 5000000,
                                'FramerateControl': 'SPECIFIED',
                                'FramerateNumerator': 30,
                                'FramerateDenominator': 1,
                                'GopSize': 2.0,
                                'Profile': 'HIGH',
                                'RateControlMode': 'CBR'
                            }
                        },
                        'Height': 1080,
                        'Width': 1920
                    }
                ],
                'OutputGroups': [
                    {
                        'Name': 'HLS',
                        'OutputGroupSettings': {
                            'HlsGroupSettings': {
                                'Destination': {
                                    'DestinationRefId': 'destination1'
                                },
                                'SegmentLength': 6,
                                'ManifestName': 'index',
                                'DirectoryStructure': 'SINGLE_DIRECTORY'
                            }
                        },
                        'Outputs': [
                            {
                                'OutputName': 'output_1080p',
                                'VideoDescriptionName': 'video_1080p',
                                'AudioDescriptionNames': ['audio_1'],
                                'OutputSettings': {
                                    'HlsOutputSettings': {
                                        'NameModifier': '_1080p'
                                    }
                                }
                            }
                        ]
                    }
                ]
            },
            'RoleArn': os.environ['MEDIALIVE_ROLE_ARN']
        }
        
        response = medialive_client.create_channel(**channel_config)
        return response['Channel']['Id']
        
    except Exception as e:
        logger.error(f"MediaLive channel creation error: {str(e)}")
        raise

def get_db_secret() -> Dict[str, Any]:
    """Get database credentials from Secrets Manager"""
    
    try:
        response = secrets_client.get_secret_value(SecretId=os.environ['AURORA_SECRET_ARN'])
        return json.loads(response['SecretString'])
    except Exception as e:
        logger.error(f"Failed to get database secret: {str(e)}")
        raise

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