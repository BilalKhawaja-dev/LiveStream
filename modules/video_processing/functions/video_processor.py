import json
import boto3
import os
import logging
from datetime import datetime
from urllib.parse import unquote_plus
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
mediaconvert_client = boto3.client('mediaconvert')
dynamodb = boto3.resource('dynamodb')

# Environment variables
UPLOAD_BUCKET = os.environ['UPLOAD_BUCKET']
PROCESSED_BUCKET = os.environ['PROCESSED_BUCKET']
MEDIACONVERT_ROLE = os.environ['MEDIACONVERT_ROLE']
MEDIACONVERT_QUEUE = os.environ['MEDIACONVERT_QUEUE']
VIDEOS_TABLE = os.environ['VIDEOS_TABLE']

# Initialize DynamoDB table
videos_table = dynamodb.Table(VIDEOS_TABLE)

def lambda_handler(event, context):
    """
    Process video uploads using MediaConvert for transcoding
    """
    try:
        logger.info(f"Processing S3 event: {json.dumps(event)}")
        
        # Process each S3 record
        for record in event['Records']:
            try:
                process_video_upload(record)
            except Exception as e:
                logger.error(f"Error processing record: {str(e)}")
                continue
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Video processing initiated successfully'})
        }
        
    except Exception as e:
        logger.error(f"Error processing video uploads: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to process video uploads'})
        }

def process_video_upload(record):
    """Process individual video upload"""
    try:
        # Extract S3 event information
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        
        logger.info(f"Processing video upload: {bucket}/{key}")
        
        # Extract video metadata
        video_id = extract_video_id_from_key(key)
        user_id = extract_user_id_from_key(key)
        
        if not video_id or not user_id:
            logger.error(f"Could not extract video_id or user_id from key: {key}")
            return
        
        # Update video status in DynamoDB
        update_video_status(video_id, user_id, 'processing', {
            'uploadKey': key,
            'uploadBucket': bucket,
            'uploadedAt': datetime.now().isoformat()
        })
        
        # Create MediaConvert job
        job_id = create_mediaconvert_job(bucket, key, video_id)
        
        # Update video status with job ID
        update_video_status(video_id, user_id, 'transcoding', {
            'mediaConvertJobId': job_id,
            'transcodingStartedAt': datetime.now().isoformat()
        })
        
        logger.info(f"MediaConvert job created: {job_id} for video {video_id}")
        
    except Exception as e:
        logger.error(f"Error processing video upload {key}: {str(e)}")
        # Update video status to failed
        try:
            if 'video_id' in locals() and 'user_id' in locals():
                update_video_status(video_id, user_id, 'failed', {
                    'error': str(e),
                    'failedAt': datetime.now().isoformat()
                })
        except:
            pass
        raise

def extract_video_id_from_key(key):
    """Extract video ID from S3 key"""
    try:
        # Key format: uploads/{user_id}/{timestamp}_{filename}
        parts = key.split('/')
        if len(parts) >= 3:
            filename = parts[-1]
            # Extract timestamp from filename
            if '_' in filename:
                timestamp_part = filename.split('_')[0]
                user_id = parts[1]
                return f"{user_id}_{timestamp_part}"
        return None
    except Exception as e:
        logger.error(f"Error extracting video ID from key {key}: {str(e)}")
        return None

def extract_user_id_from_key(key):
    """Extract user ID from S3 key"""
    try:
        # Key format: uploads/{user_id}/{timestamp}_{filename}
        parts = key.split('/')
        if len(parts) >= 2:
            return parts[1]
        return None
    except Exception as e:
        logger.error(f"Error extracting user ID from key {key}: {str(e)}")
        return None

def create_mediaconvert_job(input_bucket, input_key, video_id):
    """Create MediaConvert transcoding job"""
    try:
        # Get MediaConvert endpoint
        endpoints = mediaconvert_client.describe_endpoints()
        endpoint_url = endpoints['Endpoints'][0]['Url']
        
        # Create MediaConvert client with endpoint
        mc_client = boto3.client('mediaconvert', endpoint_url=endpoint_url)
        
        # Input and output settings
        input_uri = f"s3://{input_bucket}/{input_key}"
        output_group_settings = create_output_group_settings(video_id)
        
        # Job settings
        job_settings = {
            "TimecodeConfig": {
                "Source": "ZEROBASED"
            },
            "OutputGroups": [output_group_settings],
            "Inputs": [
                {
                    "AudioSelectors": {
                        "Audio Selector 1": {
                            "Offset": 0,
                            "DefaultSelection": "DEFAULT",
                            "ProgramSelection": 1
                        }
                    },
                    "VideoSelector": {
                        "ColorSpace": "FOLLOW"
                    },
                    "FilterEnable": "AUTO",
                    "PsiControl": "USE_PSI",
                    "FilterStrength": 0,
                    "DeblockFilter": "DISABLED",
                    "DenoiseFilter": "DISABLED",
                    "TimecodeSource": "EMBEDDED",
                    "FileInput": input_uri
                }
            ]
        }
        
        # Create the job
        response = mc_client.create_job(
            Role=MEDIACONVERT_ROLE,
            Settings=job_settings,
            Queue=MEDIACONVERT_QUEUE,
            UserMetadata={
                'VideoId': video_id,
                'InputKey': input_key
            }
        )
        
        return response['Job']['Id']
        
    except Exception as e:
        logger.error(f"Error creating MediaConvert job: {str(e)}")
        raise

def create_output_group_settings(video_id):
    """Create output group settings for different video qualities"""
    return {
        "Name": "File Group",
        "OutputGroupSettings": {
            "Type": "FILE_GROUP_SETTINGS",
            "FileGroupSettings": {
                "Destination": f"s3://{PROCESSED_BUCKET}/processed/{video_id}_"
            }
        },
        "Outputs": [
            # 480p SD output
            {
                "NameModifier": "480p",
                "Preset": "System-Generic_Sd_Mp4_Avc_Aac_16x9_640x480p_24Hz_1.5Mbps",
                "VideoDescription": {
                    "Width": 640,
                    "Height": 480,
                    "CodecSettings": {
                        "Codec": "H_264",
                        "H264Settings": {
                            "MaxBitrate": 1500000,
                            "RateControlMode": "QVBR",
                            "QvbrSettings": {
                                "QvbrQualityLevel": 7
                            }
                        }
                    }
                },
                "AudioDescriptions": [
                    {
                        "AudioTypeControl": "FOLLOW_INPUT",
                        "CodecSettings": {
                            "Codec": "AAC",
                            "AacSettings": {
                                "AudioDescriptionBroadcasterMix": "NORMAL",
                                "Bitrate": 96000,
                                "RateControlMode": "CBR",
                                "CodecProfile": "LC",
                                "CodingMode": "CODING_MODE_2_0",
                                "RawFormat": "NONE",
                                "SampleRate": 48000,
                                "Specification": "MPEG4"
                            }
                        }
                    }
                ],
                "ContainerSettings": {
                    "Container": "MP4",
                    "Mp4Settings": {
                        "CslgAtom": "INCLUDE",
                        "FreeSpaceBox": "EXCLUDE",
                        "MoovPlacement": "PROGRESSIVE_DOWNLOAD"
                    }
                }
            },
            # 720p HD output
            {
                "NameModifier": "720p",
                "VideoDescription": {
                    "Width": 1280,
                    "Height": 720,
                    "CodecSettings": {
                        "Codec": "H_264",
                        "H264Settings": {
                            "MaxBitrate": 3000000,
                            "RateControlMode": "QVBR",
                            "QvbrSettings": {
                                "QvbrQualityLevel": 7
                            }
                        }
                    }
                },
                "AudioDescriptions": [
                    {
                        "AudioTypeControl": "FOLLOW_INPUT",
                        "CodecSettings": {
                            "Codec": "AAC",
                            "AacSettings": {
                                "AudioDescriptionBroadcasterMix": "NORMAL",
                                "Bitrate": 128000,
                                "RateControlMode": "CBR",
                                "CodecProfile": "LC",
                                "CodingMode": "CODING_MODE_2_0",
                                "RawFormat": "NONE",
                                "SampleRate": 48000,
                                "Specification": "MPEG4"
                            }
                        }
                    }
                ],
                "ContainerSettings": {
                    "Container": "MP4",
                    "Mp4Settings": {
                        "CslgAtom": "INCLUDE",
                        "FreeSpaceBox": "EXCLUDE",
                        "MoovPlacement": "PROGRESSIVE_DOWNLOAD"
                    }
                }
            },
            # 1080p FHD output
            {
                "NameModifier": "1080p",
                "VideoDescription": {
                    "Width": 1920,
                    "Height": 1080,
                    "CodecSettings": {
                        "Codec": "H_264",
                        "H264Settings": {
                            "MaxBitrate": 5000000,
                            "RateControlMode": "QVBR",
                            "QvbrSettings": {
                                "QvbrQualityLevel": 7
                            }
                        }
                    }
                },
                "AudioDescriptions": [
                    {
                        "AudioTypeControl": "FOLLOW_INPUT",
                        "CodecSettings": {
                            "Codec": "AAC",
                            "AacSettings": {
                                "AudioDescriptionBroadcasterMix": "NORMAL",
                                "Bitrate": 160000,
                                "RateControlMode": "CBR",
                                "CodecProfile": "LC",
                                "CodingMode": "CODING_MODE_2_0",
                                "RawFormat": "NONE",
                                "SampleRate": 48000,
                                "Specification": "MPEG4"
                            }
                        }
                    }
                ],
                "ContainerSettings": {
                    "Container": "MP4",
                    "Mp4Settings": {
                        "CslgAtom": "INCLUDE",
                        "FreeSpaceBox": "EXCLUDE",
                        "MoovPlacement": "PROGRESSIVE_DOWNLOAD"
                    }
                }
            }
        ]
    }

def update_video_status(video_id, user_id, status, additional_data=None):
    """Update video processing status in DynamoDB"""
    try:
        update_expression = "SET #status = :status, updated_at = :updated_at"
        expression_attribute_names = {"#status": "status"}
        expression_attribute_values = {
            ":status": status,
            ":updated_at": datetime.now().isoformat()
        }
        
        # Add additional data if provided
        if additional_data:
            for key, value in additional_data.items():
                update_expression += f", #{key} = :{key}"
                expression_attribute_names[f"#{key}"] = key
                expression_attribute_values[f":{key}"] = value
        
        videos_table.update_item(
            Key={
                'video_id': video_id,
                'user_id': user_id
            },
            UpdateExpression=update_expression,
            ExpressionAttributeNames=expression_attribute_names,
            ExpressionAttributeValues=expression_attribute_values
        )
        
        logger.info(f"Updated video {video_id} status to {status}")
        
    except Exception as e:
        logger.error(f"Error updating video status: {str(e)}")
        raise