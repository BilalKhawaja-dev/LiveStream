# Media Services Module - Development Streaming Setup
# Simplified but functional: RTMP Ingest → S3 → CloudFront

# S3 bucket for media storage and HLS segments
resource "aws_s3_bucket" "media_storage" {
  bucket = "${var.project_name}-${var.environment}-media-storage"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "media_storage" {
  bucket = aws_s3_bucket.media_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "media_storage" {
  bucket = aws_s3_bucket.media_storage.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# MediaLive Channel for basic streaming (on-demand mode)
resource "aws_medialive_channel" "streaming_channel" {
  count = var.enable_streaming ? 1 : 0
  name  = "${var.project_name}-${var.environment}-channel"
  
  channel_class = "SINGLE_PIPELINE"  # Cheapest option
  role_arn      = aws_iam_role.medialive_role[0].arn
  
  # On-demand configuration - only charges when running
  input_attachments {
    input_attachment_name = "primary-input"
    input_id             = aws_medialive_input.mediaconnect_input[0].id
    
    # Auto-stop after 30 minutes of no input
    automatic_input_failover_settings {
      error_clear_time_msec = 1800000  # 30 minutes
      input_preference     = "PRIMARY"
    }
  }

  input_specification {
    codec            = "AVC"
    input_resolution = "HD"
    maximum_bitrate  = "MAX_10_MBPS"
  }

  destinations {
    id = "destination1"
    settings {
      url = "s3://${aws_s3_bucket.media_storage.bucket}/live/"
    }
  }

  encoder_settings {
    # Global configuration for cost optimization
    timecode_config {
      source = "EMBEDDED"
    }
    
    output_groups {
      name = "HLS"
      output_group_settings {
        hls_group_settings {
          destination {
            destination_ref_id = "destination1"
          }
          # Optimize for cost - shorter segments, less storage
          segment_length = 6
          segments_per_subdirectory = 5000
          hls_cdn_settings {
            hls_s3_settings {}
          }
        }
      }
      outputs {
        output_name = "720p"
        video_description_name = "video_720p"
        audio_description_names = ["audio_1"]
        output_settings {
          hls_output_settings {
            name_modifier = "_720p"
            hls_settings {
              standard_hls_settings {
                m3u8_settings {
                  audio_frames_per_pes = 4
                }
              }
            }
          }
        }
      }
    }

    video_descriptions {
      name = "video_720p"
      codec_settings {
        h264_settings {
          bitrate = 2000000
          rate_control_mode = "CBR"
        }
      }
      height = 720
      width  = 1280
    }

    audio_descriptions {
      name = "audio_1"
      codec_settings {
        aac_settings {
          bitrate = 128000
        }
      }
    }
  }

  tags = var.tags
}

# MediaConnect Flow for stream ingestion
resource "aws_mediaconnect_flow" "stream_ingestion" {
  count = var.enable_streaming ? 1 : 0
  name  = "${var.project_name}-${var.environment}-flow"
  
  source {
    name        = "rtmp-source"
    protocol    = "rtmp"
    description = "RTMP stream source"
  }
  
  tags = var.tags
}

# MediaConnect Output to MediaLive
resource "aws_mediaconnect_flow_output" "to_medialive" {
  count   = var.enable_streaming ? 1 : 0
  flow_arn = aws_mediaconnect_flow.stream_ingestion[0].arn
  name     = "medialive-output"
  protocol = "rtmp"
  
  destination = aws_medialive_input.mediaconnect_input[0].destinations[0].url
}

# MediaLive Input from MediaConnect
resource "aws_medialive_input" "mediaconnect_input" {
  count = var.enable_streaming ? 1 : 0
  name  = "${var.project_name}-${var.environment}-mediaconnect-input"
  type  = "MEDIACONNECT"
  
  mediaconnect_flows {
    flow_arn = aws_mediaconnect_flow.stream_ingestion[0].arn
  }
  
  tags = var.tags
}

# IAM role for MediaLive
resource "aws_iam_role" "medialive_role" {
  count = var.enable_streaming ? 1 : 0
  name  = "${var.project_name}-${var.environment}-medialive-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "medialive.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "medialive_policy" {
  count = var.enable_streaming ? 1 : 0
  name  = "${var.project_name}-${var.environment}-medialive-policy"
  role  = aws_iam_role.medialive_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.media_storage.arn,
          "${aws_s3_bucket.media_storage.arn}/*"
        ]
      }
    ]
  })
}

# Lambda function to auto-stop MediaLive channel after inactivity
resource "aws_lambda_function" "medialive_auto_stop" {
  count = var.enable_streaming ? 1 : 0
  
  filename         = "medialive_auto_stop.zip"
  function_name    = "${var.project_name}-${var.environment}-medialive-auto-stop"
  role            = aws_iam_role.lambda_auto_stop_role[0].arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      CHANNEL_ID = aws_medialive_channel.streaming_channel[0].id
      REGION     = data.aws_region.current.name
    }
  }

  tags = var.tags
}

# Create the Lambda deployment package
data "archive_file" "lambda_auto_stop" {
  count = var.enable_streaming ? 1 : 0
  
  type        = "zip"
  output_path = "medialive_auto_stop.zip"
  
  source {
    content = <<EOF
import boto3
import os
from datetime import datetime, timedelta

def handler(event, context):
    medialive = boto3.client('medialive', region_name=os.environ['REGION'])
    cloudwatch = boto3.client('cloudwatch', region_name=os.environ['REGION'])
    
    channel_id = os.environ['CHANNEL_ID']
    
    try:
        response = medialive.describe_channel(ChannelId=channel_id)
        state = response['State']
        
        if state != 'RUNNING':
            return {'statusCode': 200, 'body': f'Channel not running: {state}'}
        
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=30)
        
        metrics = cloudwatch.get_metric_statistics(
            Namespace='AWS/MediaLive',
            MetricName='InputVideoFrameRate',
            Dimensions=[{'Name': 'ChannelId', 'Value': channel_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average']
        )
        
        if not metrics['Datapoints'] or all(dp['Average'] == 0 for dp in metrics['Datapoints']):
            print(f'No input detected for 30 minutes, stopping channel {channel_id}')
            medialive.stop_channel(ChannelId=channel_id)
            return {'statusCode': 200, 'body': 'Channel stopped due to inactivity'}
        
        return {'statusCode': 200, 'body': 'Channel active, continuing'}
        
    except Exception as e:
        print(f'Error: {str(e)}')
        return {'statusCode': 500, 'body': f'Error: {str(e)}'}
EOF
    filename = "index.py"
  }
}

# IAM role for Lambda auto-stop function
resource "aws_iam_role" "lambda_auto_stop_role" {
  count = var.enable_streaming ? 1 : 0
  name  = "${var.project_name}-${var.environment}-lambda-auto-stop-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_auto_stop_policy" {
  count = var.enable_streaming ? 1 : 0
  name  = "${var.project_name}-${var.environment}-lambda-auto-stop-policy"
  role  = aws_iam_role.lambda_auto_stop_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "medialive:DescribeChannel",
          "medialive:StopChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Event Rule to trigger Lambda every 30 minutes
resource "aws_cloudwatch_event_rule" "medialive_check" {
  count = var.enable_streaming ? 1 : 0
  
  name                = "${var.project_name}-${var.environment}-medialive-check"
  description         = "Check MediaLive channel activity"
  schedule_expression = "rate(30 minutes)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  count = var.enable_streaming ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.medialive_check[0].name
  target_id = "MediaLiveAutoStopTarget"
  arn       = aws_lambda_function.medialive_auto_stop[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  count = var.enable_streaming ? 1 : 0
  
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.medialive_auto_stop[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.medialive_check[0].arn
}

# Data source for current region
data "aws_region" "current" {}

# CloudFront distribution (simplified)
resource "aws_cloudfront_distribution" "media_cdn" {
  count = var.enable_cdn ? 1 : 0

  origin {
    domain_name = aws_s3_bucket.media_storage.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.media_storage.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.media_oai[0].cloudfront_access_identity_path
    }
  }

  enabled = true
  comment = "Media CDN for ${var.environment}"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.media_storage.id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}

resource "aws_cloudfront_origin_access_identity" "media_oai" {
  count   = var.enable_cdn ? 1 : 0
  comment = "OAI for media storage"
}