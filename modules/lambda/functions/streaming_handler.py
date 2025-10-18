import json
import boto3
import os
import logging
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
medialive_client = boto3.client('medialive')
s3_client = boto3.client('s3')

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
        else:
            return create_response(404, {'error': 'Endpoint not found'})
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_start_stream(body):
    """Handle stream start request"""
    try:
        stream_name = body.get('stream_name')
        stream_key = body.get('stream_key')
        
        if not stream_name:
            return create_response(400, {'error': 'Stream name required'})
        
        # Mock stream start (replace with actual MediaLive logic)
        stream_data = {
            'stream_id': f"stream_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            'stream_name': stream_name,
            'status': 'starting',
            'rtmp_url': f"rtmp://example.com/live/{stream_key or 'default'}",
            'hls_url': f"https://example.com/hls/{stream_name}/playlist.m3u8",
            'created_at': datetime.now().isoformat()
        }
        
        return create_response(200, {
            'message': 'Stream started successfully',
            'stream': stream_data
        })
        
    except Exception as e:
        logger.error(f"Start stream error: {str(e)}")
        return create_response(500, {'error': 'Failed to start stream'})

def handle_stop_stream(body):
    """Handle stream stop request"""
    try:
        stream_id = body.get('stream_id')
        
        if not stream_id:
            return create_response(400, {'error': 'Stream ID required'})
        
        # Mock stream stop (replace with actual MediaLive logic)
        return create_response(200, {
            'message': 'Stream stopped successfully',
            'stream_id': stream_id,
            'stopped_at': datetime.now().isoformat()
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

def handle_list_streams():
    """Handle list streams request"""
    try:
        # Mock stream list (replace with actual data source)
        streams = [
            {
                'stream_id': 'stream_001',
                'stream_name': 'Gaming Stream',
                'status': 'active',
                'viewers': 150,
                'created_at': '2024-01-15T10:30:00Z'
            },
            {
                'stream_id': 'stream_002',
                'stream_name': 'Music Stream',
                'status': 'inactive',
                'viewers': 0,
                'created_at': '2024-01-15T09:15:00Z'
            }
        ]
        
        return create_response(200, {
            'streams': streams,
            'total': len(streams)
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