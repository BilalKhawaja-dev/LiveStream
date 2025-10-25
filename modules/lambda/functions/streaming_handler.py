import json
import boto3
import os
import uuid
import logging
import random
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
medialive_client = boto3.client('medialive')
s3_client = boto3.client('s3')
rds_client = boto3.client('rds-data')
cloudwatch_client = boto3.client('cloudwatch')

def lambda_handler(event, context):
    """
    Handle streaming requests
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
        if path == '/streams' and http_method == 'GET':
            return handle_list_streams()
        elif path == '/streams' and http_method == 'POST':
            return handle_start_stream(body)
        elif path == '/streams/live' and http_method == 'GET':
            return handle_live_streams()
        elif path == '/streams/archive' and http_method == 'GET':
            return handle_archived_streams()
        elif path == '/streams/schedule' and http_method == 'GET':
            return handle_stream_schedule()
        elif path == '/streams/metrics' and http_method == 'GET':
            return handle_stream_metrics(event.get('queryStringParameters', {}))
        elif path == '/media' and http_method == 'GET':
            return handle_get_media()
        elif path == '/media/upload' and http_method == 'POST':
            return handle_upload_media(body)
        elif path == '/media/transcode' and http_method == 'POST':
            return handle_transcode_media(body)
        elif path == '/media/cdn' and http_method == 'GET':
            return handle_cdn_media()
        elif path == '/streaming/start' and http_method == 'POST':
            return handle_start_stream(body)
        elif path == '/streaming/stop' and http_method == 'POST':
            return handle_stop_stream(body)
        elif path == '/streaming/status' and http_method == 'GET':
            return handle_stream_status(event.get('queryStringParameters', {}))
        elif path == '/streaming/list' and http_method == 'GET':
            return handle_list_streams()
        elif path == '/streaming/viewers' and http_method == 'PUT':
            return handle_update_viewer_count(body)
        else:
            return create_response(404, {'error': 'Endpoint not found'})
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

@handle_database_errors
def handle_start_stream(body):
    """Handle stream start request with MediaLive integration"""
    try:
        creator_id = body.get('creator_id')
        stream_name = body.get('stream_name')
        description = body.get('description', '')
        category = body.get('category', 'general')
        subscription_tier = body.get('subscription_tier', 'bronze')
        
        if not all([creator_id, stream_name]):
            return create_response(400, {'error': 'Creator ID and stream name required'})
        
        # Validate creator exists and get subscription tier
        creator_profile = get_user_profile(creator_id)
        if not creator_profile:
            return create_response(404, {'error': 'Creator not found'})
        
        # Use creator's actual subscription tier
        actual_tier = creator_profile.get('subscription_tier', 'bronze')
        
        # Generate unique stream ID
        stream_id = str(uuid.uuid4())
        
        # Create MediaLive channel based on subscription tier
        medialive_config = create_medialive_channel(stream_id, actual_tier)
        
        if not medialive_config:
            return create_response(500, {'error': 'Failed to create MediaLive channel'})
        
        # Store stream configuration in database
        sql = """
        INSERT INTO streams (
            id, creator_id, title, description, category, status,
            media_live_channel_id, s3_media_prefix, scheduled_start,
            actual_start, chat_enabled, recording_enabled, created_at, updated_at
        ) VALUES (
            :stream_id, :creator_id, :title, :description, :category, 'scheduled',
            :channel_id, :s3_prefix, NOW(), NULL, true, true, NOW(), NOW()
        )
        """
        
        s3_prefix = f"streams/{stream_id}"
        
        parameters = [
            {'name': 'stream_id', 'value': {'stringValue': stream_id}},
            {'name': 'creator_id', 'value': {'stringValue': creator_id}},
            {'name': 'title', 'value': {'stringValue': stream_name}},
            {'name': 'description', 'value': {'stringValue': description}},
            {'name': 'category', 'value': {'stringValue': category}},
            {'name': 'channel_id', 'value': {'stringValue': medialive_config['channel_id']}},
            {'name': 's3_prefix', 'value': {'stringValue': s3_prefix}}
        ]
        
        execute_sql(sql, parameters)
        
        # Start the MediaLive channel
        try:
            medialive_client.start_channel(ChannelId=medialive_config['channel_id'])
            
            # Update stream status to live
            update_stream_status(stream_id, 'live')
            
        except Exception as e:
            logger.error(f"Failed to start MediaLive channel: {str(e)}")
            # Update stream status to cancelled
            update_stream_status(stream_id, 'cancelled')
            return create_response(500, {'error': 'Failed to start streaming channel'})
        
        # Create initial analytics record
        track_stream_event(stream_id, 'stream_started', {'tier': actual_tier})
        
        stream_data = {
            'stream_id': stream_id,
            'stream_name': stream_name,
            'status': 'live',
            'rtmp_url': medialive_config['rtmp_url'],
            'hls_url': medialive_config['hls_url'],
            'quality_settings': medialive_config['quality_settings'],
            'created_at': datetime.now().isoformat(),
            'creator': {
                'id': creator_id,
                'username': creator_profile['username'],
                'display_name': creator_profile.get('display_name')
            }
        }
        
        logger.info(f"Stream started successfully: {stream_id} by {creator_profile['username']}")
        
        return create_response(200, {
            'message': 'Stream started successfully',
            'stream': stream_data
        })
        
    except Exception as e:
        logger.error(f"Start stream error: {str(e)}")
        return create_response(500, {'error': 'Failed to start stream'})

@handle_database_errors
def handle_stop_stream(body):
    """Handle stream stop request with MediaLive integration"""
    try:
        stream_id = body.get('stream_id')
        creator_id = body.get('creator_id')
        
        if not stream_id:
            return create_response(400, {'error': 'Stream ID required'})
        
        # Get stream details from database
        stream_details = get_stream_details(stream_id)
        if not stream_details:
            return create_response(404, {'error': 'Stream not found'})
        
        # Verify creator ownership (if creator_id provided)
        if creator_id and stream_details['creator_id'] != creator_id:
            return create_response(403, {'error': 'Not authorized to stop this stream'})
        
        # Stop MediaLive channel
        if stream_details.get('media_live_channel_id'):
            try:
                medialive_client.stop_channel(ChannelId=stream_details['media_live_channel_id'])
                logger.info(f"MediaLive channel stopped: {stream_details['media_live_channel_id']}")
            except Exception as e:
                logger.error(f"Failed to stop MediaLive channel: {str(e)}")
        
        # Update stream status in database
        end_time = datetime.now()
        sql = """
        UPDATE streams 
        SET status = 'ended', end_time = :end_time, updated_at = NOW()
        WHERE id = :stream_id
        """
        
        parameters = [
            {'name': 'end_time', 'value': {'stringValue': end_time.isoformat()}},
            {'name': 'stream_id', 'value': {'stringValue': stream_id}}
        ]
        
        execute_sql(sql, parameters)
        
        # Track stream end event
        track_stream_event(stream_id, 'stream_ended', {
            'duration_minutes': calculate_stream_duration(stream_details.get('actual_start'), end_time),
            'final_viewer_count': stream_details.get('viewer_count', 0)
        })
        
        logger.info(f"Stream stopped successfully: {stream_id}")
        
        return create_response(200, {
            'message': 'Stream stopped successfully',
            'stream_id': stream_id,
            'stopped_at': end_time.isoformat(),
            'final_stats': {
                'max_viewers': stream_details.get('max_viewers', 0),
                'total_views': stream_details.get('total_views', 0)
            }
        })
        
    except Exception as e:
        logger.error(f"Stop stream error: {str(e)}")
        return create_response(500, {'error': 'Failed to stop stream'})

def handle_stream_status(query_params):
    """Handle stream status request"""
    try:
        stream_id = query_params.get('stream_id') if query_params else None
        
        if not stream_id:
            return create_response(400, {'error': 'Stream ID required'})
        
        # Mock stream status (replace with actual MediaLive logic)
        status_data = {
            'stream_id': stream_id,
            'status': 'active',
            'viewers': 42,
            'bitrate': '2500 kbps',
            'resolution': '1920x1080',
            'uptime': '00:15:30'
        }
        
        return create_response(200, status_data)
        
    except Exception as e:
        logger.error(f"Stream status error: {str(e)}")
        return create_response(500, {'error': 'Failed to get stream status'})

@handle_database_errors
def handle_list_streams():
    """Handle list streams request with real database query"""
    try:
        # Query active streams from database with creator information
        sql = """
        SELECT s.id, s.title, s.description, s.category, s.status,
               s.viewer_count, s.max_viewers, s.total_views, s.actual_start,
               s.created_at, u.username, u.display_name, u.subscription_tier
        FROM streams s
        JOIN users u ON s.creator_id = u.id
        WHERE s.status IN ('live', 'scheduled')
        ORDER BY s.actual_start DESC, s.created_at DESC
        LIMIT 50
        """
        
        result = execute_sql(sql, [])
        
        streams = []
        for record in result.get('records', []):
            stream = {
                'stream_id': record[0]['stringValue'],
                'title': record[1]['stringValue'],
                'description': record[2]['stringValue'] if record[2].get('stringValue') else '',
                'category': record[3]['stringValue'],
                'status': record[4]['stringValue'],
                'viewer_count': int(record[5]['longValue']) if record[5].get('longValue') else 0,
                'max_viewers': int(record[6]['longValue']) if record[6].get('longValue') else 0,
                'total_views': int(record[7]['longValue']) if record[7].get('longValue') else 0,
                'actual_start': record[8]['stringValue'] if record[8].get('stringValue') else None,
                'created_at': record[9]['stringValue'],
                'creator': {
                    'username': record[10]['stringValue'],
                    'display_name': record[11]['stringValue'] if record[11].get('stringValue') else None,
                    'subscription_tier': record[12]['stringValue']
                }
            }
            streams.append(stream)
        
        return create_response(200, {
            'streams': streams,
            'total': len(streams),
            'live_count': len([s for s in streams if s['status'] == 'live'])
        })
        
    except Exception as e:
        logger.error(f"List streams error: {str(e)}")
        return create_response(500, {'error': 'Failed to list streams'})

def handle_live_streams():
    """Handle live streams request"""
    try:
        live_streams = [
            {
                'stream_id': 'live_001',
                'stream_name': 'Gaming Tournament Live',
                'streamer': 'ProGamer123',
                'viewers': random.randint(100, 1000),
                'category': 'Gaming',
                'started_at': datetime.now().isoformat()
            },
            {
                'stream_id': 'live_002',
                'stream_name': 'Music Session',
                'streamer': 'MusicMaker',
                'viewers': random.randint(50, 500),
                'category': 'Music',
                'started_at': datetime.now().isoformat()
            }
        ]
        
        return create_response(200, {
            'live_streams': live_streams,
            'total': len(live_streams)
        })
        
    except Exception as e:
        logger.error(f"Live streams error: {str(e)}")
        return create_response(500, {'error': 'Failed to get live streams'})

def handle_archived_streams():
    """Handle archived streams request"""
    try:
        archived_streams = [
            {
                'stream_id': 'archive_001',
                'stream_name': 'Previous Gaming Session',
                'streamer': 'ProGamer123',
                'duration': '02:15:30',
                'views': random.randint(1000, 10000),
                'archived_at': '2024-01-15T10:30:00Z'
            }
        ]
        
        return create_response(200, {
            'archived_streams': archived_streams,
            'total': len(archived_streams)
        })
        
    except Exception as e:
        logger.error(f"Archived streams error: {str(e)}")
        return create_response(500, {'error': 'Failed to get archived streams'})

def handle_stream_schedule():
    """Handle stream schedule request"""
    try:
        schedule = [
            {
                'stream_id': 'scheduled_001',
                'stream_name': 'Weekly Gaming Tournament',
                'streamer': 'ProGamer123',
                'scheduled_time': '2024-01-20T15:00:00Z',
                'category': 'Gaming'
            }
        ]
        
        return create_response(200, {
            'schedule': schedule,
            'total': len(schedule)
        })
        
    except Exception as e:
        logger.error(f"Stream schedule error: {str(e)}")
        return create_response(500, {'error': 'Failed to get stream schedule'})

def handle_stream_metrics(query_params):
    """Handle stream metrics request"""
    try:
        metrics = {
            'total_streams_today': random.randint(50, 200),
            'concurrent_viewers': random.randint(500, 5000),
            'peak_viewers_today': random.randint(1000, 10000),
            'average_stream_duration': f"{random.randint(60, 180)} minutes"
        }
        
        return create_response(200, metrics)
        
    except Exception as e:
        logger.error(f"Stream metrics error: {str(e)}")
        return create_response(500, {'error': 'Failed to get stream metrics'})

def handle_get_media():
    """Handle get media request"""
    try:
        media_files = [
            {
                'media_id': 'media_001',
                'filename': 'stream_recording_001.mp4',
                'size': '1.2 GB',
                'duration': '02:15:30',
                'created_at': '2024-01-15T10:30:00Z'
            }
        ]
        
        return create_response(200, {
            'media_files': media_files,
            'total': len(media_files)
        })
        
    except Exception as e:
        logger.error(f"Get media error: {str(e)}")
        return create_response(500, {'error': 'Failed to get media'})

def handle_upload_media(body):
    """Handle media upload request"""
    try:
        filename = body.get('filename')
        if not filename:
            return create_response(400, {'error': 'Filename required'})
        
        upload_data = {
            'upload_id': f"upload_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            'presigned_url': f"https://example.com/upload/{filename}",
            'expires_in': 3600
        }
        
        return create_response(200, upload_data)
        
    except Exception as e:
        logger.error(f"Upload media error: {str(e)}")
        return create_response(500, {'error': 'Failed to upload media'})

def handle_transcode_media(body):
    """Handle media transcoding request"""
    try:
        media_id = body.get('media_id')
        if not media_id:
            return create_response(400, {'error': 'Media ID required'})
        
        transcode_data = {
            'job_id': f"transcode_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            'status': 'queued',
            'estimated_completion': '10 minutes'
        }
        
        return create_response(200, transcode_data)
        
    except Exception as e:
        logger.error(f"Transcode media error: {str(e)}")
        return create_response(500, {'error': 'Failed to transcode media'})

def handle_cdn_media():
    """Handle CDN media request"""
    try:
        cdn_info = {
            'cdn_url': 'https://cdn.example.com',
            'cache_status': 'active',
            'bandwidth_usage': '1.2 TB',
            'cache_hit_ratio': '95%'
        }
        
        return create_response(200, cdn_info)
        
    except Exception as e:
        logger.error(f"CDN media error: {str(e)}")
        return create_response(500, {'error': 'Failed to get CDN media info'})

# Database and MediaLive helper functions
def handle_database_errors(func):
    """Decorator for database operations with comprehensive error handling"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            logger.error(f"Database operation error in {func.__name__}: {str(e)}")
            return create_response(500, {'error': 'Database operation failed'})
    return wrapper

def execute_sql(sql: str, parameters: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Execute SQL query with proper error handling"""
    try:
        response = rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        return response
    except Exception as e:
        logger.error(f"SQL execution error: {str(e)}")
        raise

def create_medialive_channel(stream_id: str, subscription_tier: str) -> Optional[Dict[str, Any]]:
    """Create MediaLive channel with tier-appropriate settings"""
    try:
        # Quality settings based on subscription tier
        tier_configs = {
            'bronze': {
                'resolution': 'HD',
                'max_bitrate': 'MAX_10_MBPS',
                'codec': 'H_264',
                'width': 1280,
                'height': 720,
                'bitrate': 2500000
            },
            'silver': {
                'resolution': 'FHD',
                'max_bitrate': 'MAX_20_MBPS',
                'codec': 'H_264',
                'width': 1920,
                'height': 1080,
                'bitrate': 5000000
            },
            'gold': {
                'resolution': 'UHD',
                'max_bitrate': 'MAX_50_MBPS',
                'codec': 'H_264',
                'width': 3840,
                'height': 2160,
                'bitrate': 15000000
            }
        }
        
        config = tier_configs.get(subscription_tier, tier_configs['bronze'])
        
        # Create input
        input_response = medialive_client.create_input(
            Name=f"stream-input-{stream_id}",
            Type='RTMP_PUSH',
            Destinations=[
                {
                    'StreamName': f"stream/{stream_id}"
                }
            ]
        )
        
        input_id = input_response['Input']['Id']
        rtmp_url = input_response['Input']['Destinations'][0]['Url']
        
        # Create channel
        s3_bucket = os.environ.get('S3_MEDIA_BUCKET', 'streaming-platform-media')
        
        channel_response = medialive_client.create_channel(
            Name=f"stream-channel-{stream_id}",
            InputSpecification={
                'Codec': config['codec'],
                'Resolution': config['resolution'],
                'MaximumBitrate': config['max_bitrate']
            },
            InputAttachments=[
                {
                    'InputId': input_id,
                    'InputAttachmentName': f"input-{stream_id}",
                    'InputSettings': {
                        'SourceEndBehavior': 'CONTINUE'
                    }
                }
            ],
            Destinations=[
                {
                    'Id': 'destination1',
                    'Settings': [
                        {
                            'Url': f"s3://{s3_bucket}/live/{stream_id}/",
                            'Username': '',
                            'PasswordParam': ''
                        }
                    ]
                }
            ],
            EncoderSettings={
                'VideoDescriptions': [
                    {
                        'Name': 'video_1',
                        'CodecSettings': {
                            'H264Settings': {
                                'Bitrate': config['bitrate'],
                                'Width': config['width'],
                                'Height': config['height'],
                                'FramerateControl': 'SPECIFIED',
                                'FramerateNumerator': 30,
                                'FramerateDenominator': 1
                            }
                        }
                    }
                ],
                'AudioDescriptions': [
                    {
                        'Name': 'audio_1',
                        'CodecSettings': {
                            'AacSettings': {
                                'Bitrate': 128000,
                                'SampleRate': 48000
                            }
                        }
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
                                'ManifestName': 'playlist',
                                'DirectoryStructure': 'SINGLE_DIRECTORY'
                            }
                        },
                        'Outputs': [
                            {
                                'OutputName': 'output_1',
                                'VideoDescriptionName': 'video_1',
                                'AudioDescriptionNames': ['audio_1'],
                                'OutputSettings': {
                                    'HlsOutputSettings': {
                                        'NameModifier': '_720p'
                                    }
                                }
                            }
                        ]
                    }
                ]
            }
        )
        
        channel_id = channel_response['Channel']['Id']
        cloudfront_domain = os.environ.get('CLOUDFRONT_DOMAIN', 'streaming.example.com')
        hls_url = f"https://{cloudfront_domain}/live/{stream_id}/playlist.m3u8"
        
        return {
            'channel_id': channel_id,
            'input_id': input_id,
            'rtmp_url': rtmp_url,
            'hls_url': hls_url,
            'quality_settings': config
        }
        
    except Exception as e:
        logger.error(f"MediaLive channel creation error: {str(e)}")
        return None

def get_user_profile(user_id: str) -> Optional[Dict[str, Any]]:
    """Get user profile from database"""
    sql = """
    SELECT id, username, display_name, subscription_tier, role
    FROM users 
    WHERE id = :user_id
    """
    
    parameters = [{'name': 'user_id', 'value': {'stringValue': user_id}}]
    result = execute_sql(sql, parameters)
    
    if result.get('records') and len(result['records']) > 0:
        record = result['records'][0]
        return {
            'id': record[0]['stringValue'],
            'username': record[1]['stringValue'],
            'display_name': record[2]['stringValue'] if record[2].get('stringValue') else None,
            'subscription_tier': record[3]['stringValue'],
            'role': record[4]['stringValue']
        }
    return None

def get_stream_details(stream_id: str) -> Optional[Dict[str, Any]]:
    """Get stream details from database"""
    sql = """
    SELECT id, creator_id, title, status, media_live_channel_id,
           viewer_count, max_viewers, total_views, actual_start
    FROM streams 
    WHERE id = :stream_id
    """
    
    parameters = [{'name': 'stream_id', 'value': {'stringValue': stream_id}}]
    result = execute_sql(sql, parameters)
    
    if result.get('records') and len(result['records']) > 0:
        record = result['records'][0]
        return {
            'id': record[0]['stringValue'],
            'creator_id': record[1]['stringValue'],
            'title': record[2]['stringValue'],
            'status': record[3]['stringValue'],
            'media_live_channel_id': record[4]['stringValue'] if record[4].get('stringValue') else None,
            'viewer_count': int(record[5]['longValue']) if record[5].get('longValue') else 0,
            'max_viewers': int(record[6]['longValue']) if record[6].get('longValue') else 0,
            'total_views': int(record[7]['longValue']) if record[7].get('longValue') else 0,
            'actual_start': record[8]['stringValue'] if record[8].get('stringValue') else None
        }
    return None

def update_stream_status(stream_id: str, status: str) -> None:
    """Update stream status in database"""
    sql = """
    UPDATE streams 
    SET status = :status, updated_at = NOW()
    WHERE id = :stream_id
    """
    
    parameters = [
        {'name': 'status', 'value': {'stringValue': status}},
        {'name': 'stream_id', 'value': {'stringValue': stream_id}}
    ]
    
    execute_sql(sql, parameters)

def track_stream_event(stream_id: str, event_type: str, metadata: Dict[str, Any]) -> None:
    """Track stream analytics event"""
    try:
        # Store in database
        sql = """
        INSERT INTO stream_analytics (id, stream_id, metric_type, metric_value, metadata, recorded_at)
        VALUES (:id, :stream_id, :metric_type, 1, :metadata, NOW())
        """
        
        parameters = [
            {'name': 'id', 'value': {'stringValue': str(uuid.uuid4())}},
            {'name': 'stream_id', 'value': {'stringValue': stream_id}},
            {'name': 'metric_type', 'value': {'stringValue': event_type}},
            {'name': 'metadata', 'value': {'stringValue': json.dumps(metadata)}}
        ]
        
        execute_sql(sql, parameters)
        
        # Send to CloudWatch
        cloudwatch_client.put_metric_data(
            Namespace='StreamingPlatform/Streams',
            MetricData=[
                {
                    'MetricName': event_type,
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'StreamId',
                            'Value': stream_id
                        }
                    ]
                }
            ]
        )
        
    except Exception as e:
        logger.error(f"Failed to track stream event: {str(e)}")

def calculate_stream_duration(start_time: Optional[str], end_time: datetime) -> int:
    """Calculate stream duration in minutes"""
    if not start_time:
        return 0
    
    try:
        start = datetime.fromisoformat(start_time.replace('Z', '+00:00'))
        duration = end_time - start
        return int(duration.total_seconds() / 60)
    except Exception:
        return 0

@handle_database_errors
def handle_update_viewer_count(body):
    """Update viewer count for a stream"""
    try:
        stream_id = body.get('stream_id')
        viewer_count = body.get('viewer_count', 0)
        
        if not stream_id:
            return create_response(400, {'error': 'Stream ID required'})
        
        # Update viewer count and track max viewers
        sql = """
        UPDATE streams 
        SET viewer_count = :viewer_count,
            max_viewers = GREATEST(max_viewers, :viewer_count),
            updated_at = NOW()
        WHERE id = :stream_id AND status = 'live'
        """
        
        parameters = [
            {'name': 'viewer_count', 'value': {'longValue': viewer_count}},
            {'name': 'stream_id', 'value': {'stringValue': stream_id}}
        ]
        
        execute_sql(sql, parameters)
        
        # Track analytics
        track_stream_event(stream_id, 'viewer_count', {'count': viewer_count})
        
        return create_response(200, {
            'message': 'Viewer count updated',
            'stream_id': stream_id,
            'viewer_count': viewer_count
        })
        
    except Exception as e:
        logger.error(f"Update viewer count error: {str(e)}")
        return create_response(500, {'error': 'Failed to update viewer count'})

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