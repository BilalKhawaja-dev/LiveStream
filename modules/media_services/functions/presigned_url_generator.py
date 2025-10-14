import json
import boto3
import os
import logging
import uuid
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Generate presigned URLs for secure file uploads
    """
    
    try:
        # Parse request
        http_method = event.get('httpMethod', 'POST')
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        
        if http_method == 'POST':
            return generate_upload_url(body)
        elif http_method == 'GET':
            return generate_download_url(event.get('queryStringParameters', {}))
        else:
            return create_response(405, {'error': 'Method not allowed'})
            
    except Exception as e:
        logger.error(f"Error generating presigned URL: {str(e)}")
        return create_response(500, {
            'error': 'Failed to generate presigned URL',
            'message': str(e)
        })

def generate_upload_url(body):
    """Generate presigned URL for file upload"""
    try:
        # Validate required parameters
        file_name = body.get('fileName')
        file_type = body.get('fileType')
        file_size = body.get('fileSize', 0)
        
        if not file_name or not file_type:
            return create_response(400, {
                'error': 'Missing required parameters',
                'required': ['fileName', 'fileType']
            })
        
        # Validate file type
        allowed_types = get_allowed_file_types()
        if file_type not in allowed_types:
            return create_response(400, {
                'error': 'File type not allowed',
                'allowed_types': list(allowed_types.keys())
            })
        
        # Validate file size
        max_size = allowed_types[file_type]['max_size']
        if file_size > max_size:
            return create_response(400, {
                'error': 'File size exceeds limit',
                'max_size_mb': max_size / (1024 * 1024),
                'provided_size_mb': file_size / (1024 * 1024)
            })
        
        # Generate unique file key
        file_extension = get_file_extension(file_name)
        unique_id = str(uuid.uuid4())
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        object_key = f"uploads/{timestamp}_{unique_id}{file_extension}"
        
        # Generate presigned URL
        bucket_name = os.environ['MEDIA_BUCKET']
        expiration = 3600  # 1 hour
        
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket_name,
                'Key': object_key,
                'ContentType': file_type,
                'ContentLength': file_size,
                'Metadata': {
                    'original-filename': file_name,
                    'upload-timestamp': datetime.now().isoformat(),
                    'uploader-ip': get_client_ip(event)
                }
            },
            ExpiresIn=expiration
        )
        
        logger.info(f"Generated upload URL for: {file_name} -> {object_key}")
        
        return create_response(200, {
            'uploadUrl': presigned_url,
            'objectKey': object_key,
            'expiresIn': expiration,
            'bucket': bucket_name,
            'fileInfo': {
                'originalName': file_name,
                'contentType': file_type,
                'size': file_size,
                'maxSize': max_size
            }
        })
        
    except ClientError as e:
        logger.error(f"AWS error generating upload URL: {str(e)}")
        return create_response(500, {
            'error': 'AWS service error',
            'message': str(e)
        })

def generate_download_url(query_params):
    """Generate presigned URL for file download"""
    try:
        object_key = query_params.get('key')
        if not object_key:
            return create_response(400, {
                'error': 'Missing object key parameter'
            })
        
        # Validate object exists
        bucket_name = os.environ['MEDIA_BUCKET']
        
        try:
            s3_client.head_object(Bucket=bucket_name, Key=object_key)
        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                return create_response(404, {
                    'error': 'File not found'
                })
            raise
        
        # Generate presigned URL for download
        expiration = 3600  # 1 hour
        
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': bucket_name,
                'Key': object_key
            },
            ExpiresIn=expiration
        )
        
        logger.info(f"Generated download URL for: {object_key}")
        
        return create_response(200, {
            'downloadUrl': presigned_url,
            'objectKey': object_key,
            'expiresIn': expiration,
            'bucket': bucket_name
        })
        
    except ClientError as e:
        logger.error(f"AWS error generating download URL: {str(e)}")
        return create_response(500, {
            'error': 'AWS service error',
            'message': str(e)
        })

def get_allowed_file_types():
    """Get allowed file types and their constraints"""
    return {
        # Images
        'image/jpeg': {'max_size': 10 * 1024 * 1024},  # 10MB
        'image/jpg': {'max_size': 10 * 1024 * 1024},   # 10MB
        'image/png': {'max_size': 10 * 1024 * 1024},   # 10MB
        'image/gif': {'max_size': 5 * 1024 * 1024},    # 5MB
        'image/webp': {'max_size': 10 * 1024 * 1024},  # 10MB
        
        # Videos
        'video/mp4': {'max_size': 500 * 1024 * 1024},  # 500MB
        'video/avi': {'max_size': 500 * 1024 * 1024},  # 500MB
        'video/mov': {'max_size': 500 * 1024 * 1024},  # 500MB
        'video/wmv': {'max_size': 500 * 1024 * 1024},  # 500MB
        'video/webm': {'max_size': 500 * 1024 * 1024}, # 500MB
        
        # Audio
        'audio/mp3': {'max_size': 50 * 1024 * 1024},   # 50MB
        'audio/wav': {'max_size': 100 * 1024 * 1024},  # 100MB
        'audio/ogg': {'max_size': 50 * 1024 * 1024},   # 50MB
        'audio/aac': {'max_size': 50 * 1024 * 1024},   # 50MB
        
        # Documents
        'application/pdf': {'max_size': 25 * 1024 * 1024},  # 25MB
        'text/plain': {'max_size': 1 * 1024 * 1024},        # 1MB
        'application/json': {'max_size': 1 * 1024 * 1024},  # 1MB
    }

def get_file_extension(filename):
    """Extract file extension from filename"""
    if '.' in filename:
        return '.' + filename.rsplit('.', 1)[1].lower()
    return ''

def get_client_ip(event):
    """Extract client IP from API Gateway event"""
    # Try different headers for client IP
    headers = event.get('headers', {})
    
    # Check X-Forwarded-For header first
    x_forwarded_for = headers.get('X-Forwarded-For', headers.get('x-forwarded-for'))
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()
    
    # Check X-Real-IP header
    x_real_ip = headers.get('X-Real-IP', headers.get('x-real-ip'))
    if x_real_ip:
        return x_real_ip
    
    # Fallback to source IP from request context
    request_context = event.get('requestContext', {})
    return request_context.get('identity', {}).get('sourceIp', 'unknown')

def create_response(status_code, body):
    """Create HTTP response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps(body)
    }