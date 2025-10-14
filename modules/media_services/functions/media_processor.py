import json
import boto3
import os
import logging
from urllib.parse import unquote_plus
from PIL import Image
import io

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
s3_client = boto3.client('s3')
cloudfront_client = boto3.client('cloudfront')

def lambda_handler(event, context):
    """
    Media processor Lambda function
    Handles thumbnail generation and media processing triggers
    """
    
    try:
        # Process S3 event records
        for record in event['Records']:
            # Get bucket and object key from the event
            bucket = record['s3']['bucket']['name']
            key = unquote_plus(record['s3']['object']['key'])
            
            logger.info(f"Processing file: {key} from bucket: {bucket}")
            
            # Process based on file type
            if is_image_file(key):
                process_image(bucket, key)
            elif is_video_file(key):
                process_video(bucket, key)
            else:
                logger.info(f"Unsupported file type: {key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Media processing completed successfully',
                'processed_files': len(event['Records'])
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing media: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Media processing failed',
                'message': str(e)
            })
        }

def is_image_file(key):
    """Check if file is an image"""
    image_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
    return any(key.lower().endswith(ext) for ext in image_extensions)

def is_video_file(key):
    """Check if file is a video"""
    video_extensions = ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv']
    return any(key.lower().endswith(ext) for ext in video_extensions)

def process_image(bucket, key):
    """Process image files - generate thumbnails"""
    try:
        # Download the image from S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        image_data = response['Body'].read()
        
        # Open image with PIL
        with Image.open(io.BytesIO(image_data)) as image:
            # Convert to RGB if necessary
            if image.mode in ('RGBA', 'LA', 'P'):
                image = image.convert('RGB')
            
            # Generate different thumbnail sizes
            thumbnail_sizes = [
                (150, 150, 'thumb'),
                (300, 300, 'small'),
                (600, 600, 'medium'),
                (1200, 1200, 'large')
            ]
            
            processed_bucket = os.environ['PROCESSED_BUCKET']
            base_key = key.replace('uploads/', '').rsplit('.', 1)[0]
            
            for width, height, size_name in thumbnail_sizes:
                # Create thumbnail
                thumbnail = image.copy()
                thumbnail.thumbnail((width, height), Image.Resampling.LANCZOS)
                
                # Save thumbnail to bytes
                thumbnail_buffer = io.BytesIO()
                thumbnail.save(thumbnail_buffer, format='JPEG', quality=85, optimize=True)
                thumbnail_buffer.seek(0)
                
                # Upload thumbnail to processed media bucket
                thumbnail_key = f"thumbnails/{base_key}_{size_name}.jpg"
                s3_client.put_object(
                    Bucket=processed_bucket,
                    Key=thumbnail_key,
                    Body=thumbnail_buffer.getvalue(),
                    ContentType='image/jpeg',
                    CacheControl='max-age=31536000',  # 1 year
                    Metadata={
                        'original-file': key,
                        'thumbnail-size': size_name,
                        'generated-by': 'media-processor'
                    }
                )
                
                logger.info(f"Generated thumbnail: {thumbnail_key}")
        
        # Invalidate CloudFront cache if enabled
        if os.environ.get('CLOUDFRONT_DOMAIN'):
            invalidate_cloudfront_cache([f"/processed/thumbnails/{base_key}_*.jpg"])
        
        logger.info(f"Successfully processed image: {key}")
        
    except Exception as e:
        logger.error(f"Error processing image {key}: {str(e)}")
        raise

def process_video(bucket, key):
    """Process video files - extract metadata and trigger transcoding"""
    try:
        # Get video metadata
        response = s3_client.head_object(Bucket=bucket, Key=key)
        file_size = response['ContentLength']
        
        # Create metadata file
        metadata = {
            'original_file': key,
            'file_size': file_size,
            'content_type': response.get('ContentType', 'video/mp4'),
            'upload_time': response['LastModified'].isoformat(),
            'processing_status': 'pending',
            'transcoding_jobs': []
        }
        
        # Save metadata to processed bucket
        processed_bucket = os.environ['PROCESSED_BUCKET']
        base_key = key.replace('uploads/', '').rsplit('.', 1)[0]
        metadata_key = f"metadata/{base_key}.json"
        
        s3_client.put_object(
            Bucket=processed_bucket,
            Key=metadata_key,
            Body=json.dumps(metadata, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Created metadata for video: {key}")
        
        # TODO: Trigger MediaConvert job for transcoding
        # This would be implemented when MediaConvert is set up
        logger.info(f"Video processing queued: {key}")
        
    except Exception as e:
        logger.error(f"Error processing video {key}: {str(e)}")
        raise

def invalidate_cloudfront_cache(paths):
    """Invalidate CloudFront cache for specified paths"""
    try:
        distribution_id = get_distribution_id()
        if not distribution_id:
            logger.warning("CloudFront distribution ID not found")
            return
        
        response = cloudfront_client.create_invalidation(
            DistributionId=distribution_id,
            InvalidationBatch={
                'Paths': {
                    'Quantity': len(paths),
                    'Items': paths
                },
                'CallerReference': f"media-processor-{context.aws_request_id}"
            }
        )
        
        logger.info(f"CloudFront invalidation created: {response['Invalidation']['Id']}")
        
    except Exception as e:
        logger.error(f"Error invalidating CloudFront cache: {str(e)}")

def get_distribution_id():
    """Get CloudFront distribution ID from environment or by domain"""
    cloudfront_domain = os.environ.get('CLOUDFRONT_DOMAIN')
    if not cloudfront_domain:
        return None
    
    try:
        # List distributions and find by domain name
        response = cloudfront_client.list_distributions()
        
        for distribution in response.get('DistributionList', {}).get('Items', []):
            if distribution['DomainName'] == cloudfront_domain:
                return distribution['Id']
        
        logger.warning(f"Distribution not found for domain: {cloudfront_domain}")
        return None
        
    except Exception as e:
        logger.error(f"Error getting distribution ID: {str(e)}")
        return None