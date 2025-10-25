import json
import boto3
import os
import logging
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')

# Environment variables
UPLOAD_BUCKET = os.environ['UPLOAD_BUCKET']
PROCESSED_BUCKET = os.environ['PROCESSED_BUCKET']
CDN_DOMAIN = os.environ['CDN_DOMAIN']

def lambda_handler(event, context):
    """
    Generate presigned URLs for video uploads and downloads
    """
    try:
        # Parse the request
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        query_params = event.get('queryStringParameters') or {}
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        
        logger.info(f"Processing {http_method} request to {path}")
        
        # Route the request
        if path.endswith('/upload-url'):
            return handle_upload_url_request(body)
        elif path.endswith('/download-url'):
            return handle_download_url_request(query_params)
        elif path.endswith('/video-info'):
            return handle_video_info_request(query_params)
        else:
            return {
                'statusCode': 404,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Endpoint not found'})
            }
            
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Internal server error'})
        }

def handle_upload_url_request(body):
    """Generate presigned URL for video upload"""
    try:
        # Validate required fields
        filename = body.get('filename')
        content_type = body.get('contentType', 'video/mp4')
        user_id = body.get('userId')
        
        if not filename or not user_id:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'filename and userId are required'})
            }
        
        # Validate file type
        allowed_types = ['video/mp4', 'video/avi', 'video/mov', 'video/wmv']
        if content_type not in allowed_types:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': f'Content type {content_type} not allowed'})
            }
        
        # Generate unique key
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        file_extension = filename.split('.')[-1] if '.' in filename else 'mp4'
        object_key = f"uploads/{user_id}/{timestamp}_{filename}"
        
        # Generate presigned URL for upload
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': UPLOAD_BUCKET,
                'Key': object_key,
                'ContentType': content_type
            },
            ExpiresIn=3600  # 1 hour
        )
        
        # Generate video ID for tracking
        video_id = f"{user_id}_{timestamp}"
        
        result = {
            'uploadUrl': presigned_url,
            'videoId': video_id,
            'objectKey': object_key,
            'expiresIn': 3600,
            'maxFileSize': '5GB'
        }
        
        logger.info(f"Generated upload URL for user {user_id}, video {video_id}")
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(result)
        }
        
    except ClientError as e:
        logger.error(f"AWS error generating upload URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to generate upload URL'})
        }
    except Exception as e:
        logger.error(f"Error generating upload URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to generate upload URL'})
        }

def handle_download_url_request(query_params):
    """Generate presigned URL for video download"""
    try:
        video_key = query_params.get('videoKey')
        quality = query_params.get('quality', 'hd')
        
        if not video_key:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'videoKey parameter is required'})
            }
        
        # Construct the processed video key based on quality
        quality_suffix = {
            'sd': '_480p.mp4',
            'hd': '_720p.mp4',
            'fhd': '_1080p.mp4'
        }
        
        processed_key = f"processed/{video_key.replace('.mp4', '')}{quality_suffix.get(quality, '_720p.mp4')}"
        
        # Check if processed video exists
        try:
            s3_client.head_object(Bucket=PROCESSED_BUCKET, Key=processed_key)
        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                return {
                    'statusCode': 404,
                    'headers': get_cors_headers(),
                    'body': json.dumps({'error': 'Video not found or still processing'})
                }
            raise
        
        # Generate presigned URL for download
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': PROCESSED_BUCKET,
                'Key': processed_key
            },
            ExpiresIn=3600  # 1 hour
        )
        
        # Also provide CDN URL for better performance
        cdn_url = f"https://{CDN_DOMAIN}/{processed_key}"
        
        result = {
            'downloadUrl': presigned_url,
            'cdnUrl': cdn_url,
            'quality': quality,
            'expiresIn': 3600
        }
        
        logger.info(f"Generated download URL for video {video_key}, quality {quality}")
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(result)
        }
        
    except ClientError as e:
        logger.error(f"AWS error generating download URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to generate download URL'})
        }
    except Exception as e:
        logger.error(f"Error generating download URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to generate download URL'})
        }

def handle_video_info_request(query_params):
    """Get video processing status and metadata"""
    try:
        video_id = query_params.get('videoId')
        
        if not video_id:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'videoId parameter is required'})
            }
        
        # Check processing status by looking for processed files
        base_key = f"processed/{video_id}"
        
        # List available qualities
        available_qualities = []
        quality_files = {
            'sd': f"{base_key}_480p.mp4",
            'hd': f"{base_key}_720p.mp4",
            'fhd': f"{base_key}_1080p.mp4"
        }
        
        for quality, key in quality_files.items():
            try:
                response = s3_client.head_object(Bucket=PROCESSED_BUCKET, Key=key)
                available_qualities.append({
                    'quality': quality,
                    'size': response.get('ContentLength', 0),
                    'lastModified': response.get('LastModified', '').isoformat() if response.get('LastModified') else ''
                })
            except ClientError:
                continue
        
        # Check for thumbnail
        thumbnail_key = f"thumbnails/{video_id}_thumb.jpg"
        thumbnail_url = None
        try:
            s3_client.head_object(Bucket=PROCESSED_BUCKET, Key=thumbnail_key)
            thumbnail_url = f"https://{CDN_DOMAIN}/{thumbnail_key}"
        except ClientError:
            pass
        
        # Determine processing status
        if available_qualities:
            status = 'completed'
        else:
            # Check if original file exists in upload bucket
            try:
                s3_client.head_object(Bucket=UPLOAD_BUCKET, Key=f"uploads/{video_id}")
                status = 'processing'
            except ClientError:
                status = 'not_found'
        
        result = {
            'videoId': video_id,
            'status': status,
            'availableQualities': available_qualities,
            'thumbnailUrl': thumbnail_url,
            'cdnDomain': CDN_DOMAIN
        }
        
        logger.info(f"Retrieved video info for {video_id}: status={status}, qualities={len(available_qualities)}")
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Error getting video info: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to get video info'})
        }

def get_cors_headers():
    """Get CORS headers for API responses"""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }