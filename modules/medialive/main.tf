# MediaLive Module for Live Streaming
# This module creates MediaLive channels with cost controls and manual activation

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# MediaLive Input Security Group
resource "aws_medialive_input_security_group" "rtmp_input_sg" {
  count = var.enable_medialive ? 1 : 0

  whitelist_rules {
    cidr = "0.0.0.0/0" # Allow from anywhere - restrict in production
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rtmp-input-sg"
  })
}

# MediaLive RTMP Input
resource "aws_medialive_input" "rtmp_input" {
  count = var.enable_medialive ? 1 : 0

  name                  = "${var.project_name}-${var.environment}-rtmp-input"
  input_security_groups = [aws_medialive_input_security_group.rtmp_input_sg[0].id]
  type                  = "RTMP_PUSH"

  destinations {
    stream_name = "${var.project_name}-primary"
  }

  destinations {
    stream_name = "${var.project_name}-backup"
  }

  tags = var.tags
}

# IAM Role for MediaLive
resource "aws_iam_role" "medialive_access_role" {
  count = var.enable_medialive ? 1 : 0

  name = "${var.project_name}-${var.environment}-medialive-access-role"

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

# IAM Policy for MediaLive to access S3 and MediaStore
resource "aws_iam_role_policy" "medialive_s3_policy" {
  count = var.enable_medialive ? 1 : 0

  name = "${var.project_name}-${var.environment}-medialive-s3-policy"
  role = aws_iam_role.medialive_access_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.s3_destination_bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.s3_destination_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "mediastore:ListContainers",
          "mediastore:PutObject",
          "mediastore:GetObject",
          "mediastore:DeleteObject",
          "mediastore:DescribeObject"
        ]
        Resource = "*"
      }
    ]
  })
}

# MediaLive Channel (initially stopped to control costs)
resource "aws_medialive_channel" "streaming_channel" {
  count = var.enable_medialive ? 1 : 0

  name          = "${var.project_name}-${var.environment}-streaming-channel"
  channel_class = var.channel_class
  role_arn      = aws_iam_role.medialive_access_role[0].arn

  input_specification {
    codec            = "AVC"
    input_resolution = var.input_resolution
    maximum_bitrate  = var.maximum_bitrate
  }

  input_attachments {
    input_attachment_name = "primary-input"
    input_id              = aws_medialive_input.rtmp_input[0].id
  }

  # HLS Output Group for S3
  destinations {
    id = "s3-destination"
    settings {
      url = "s3://${var.s3_destination_bucket_name}/live-streams/"
    }
  }

  encoder_settings {
    # Audio descriptions
    audio_descriptions {
      audio_selector_name = "default"
      name                = "audio_1"
      codec_settings {
        aac_settings {
          bitrate           = 128000
          coding_mode       = "CODING_MODE_2_0"
          input_type        = "NORMAL"
          profile           = "LC"
          rate_control_mode = "CBR"
          raw_data_format   = "NONE"
          sample_rate       = 48000
          spec              = "MPEG4"
        }
      }
    }

    # Video descriptions for different quality tiers
    video_descriptions {
      name = "video_1080p"
      codec_settings {
        h264_settings {
          adaptive_quantization   = "HIGH"
          bitrate                 = var.video_bitrates.high
          entropy_encoding        = "CABAC"
          framerate_control       = "SPECIFIED"
          framerate_numerator     = 30
          framerate_denominator   = 1
          gop_b_reference         = "DISABLED"
          gop_closed_cadence      = 1
          gop_num_b_frames        = 2
          gop_size                = 90
          gop_size_units          = "FRAMES"
          level                   = "H264_LEVEL_4_1"
          look_ahead_rate_control = "HIGH"
          max_bitrate             = var.video_bitrates.high * 1.2
          num_ref_frames          = 3
          par_control             = "SPECIFIED"
          profile                 = "HIGH"
          rate_control_mode       = "VBR"
          scene_change_detect     = "ENABLED"
          syntax_control          = "DEFAULT"
        }
      }
      height = 1080
      width  = 1920
    }

    video_descriptions {
      name = "video_720p"
      codec_settings {
        h264_settings {
          adaptive_quantization   = "HIGH"
          bitrate                 = var.video_bitrates.medium
          entropy_encoding        = "CABAC"
          framerate_control       = "SPECIFIED"
          framerate_numerator     = 30
          framerate_denominator   = 1
          gop_b_reference         = "DISABLED"
          gop_closed_cadence      = 1
          gop_num_b_frames        = 2
          gop_size                = 90
          gop_size_units          = "FRAMES"
          level                   = "H264_LEVEL_4_1"
          look_ahead_rate_control = "HIGH"
          max_bitrate             = var.video_bitrates.medium * 1.2
          num_ref_frames          = 3
          par_control             = "SPECIFIED"
          profile                 = "HIGH"
          rate_control_mode       = "VBR"
          scene_change_detect     = "ENABLED"
          syntax_control          = "DEFAULT"
        }
      }
      height = 720
      width  = 1280
    }

    video_descriptions {
      name = "video_480p"
      codec_settings {
        h264_settings {
          adaptive_quantization   = "HIGH"
          bitrate                 = var.video_bitrates.low
          entropy_encoding        = "CABAC"
          framerate_control       = "SPECIFIED"
          framerate_numerator     = 30
          framerate_denominator   = 1
          gop_b_reference         = "DISABLED"
          gop_closed_cadence      = 1
          gop_num_b_frames        = 2
          gop_size                = 90
          gop_size_units          = "FRAMES"
          level                   = "H264_LEVEL_3_1"
          look_ahead_rate_control = "HIGH"
          max_bitrate             = var.video_bitrates.low * 1.2
          num_ref_frames          = 3
          par_control             = "SPECIFIED"
          profile                 = "HIGH"
          rate_control_mode       = "VBR"
          scene_change_detect     = "ENABLED"
          syntax_control          = "DEFAULT"
        }
      }
      height = 480
      width  = 854
    }

    # Output groups
    output_groups {
      name = "HLS_S3"
      output_group_settings {
        hls_group_settings {
          destination {
            destination_ref_id = "s3-destination"
          }
          hls_cdn_settings {
            hls_basic_put_settings {
              connection_retry_interval = 30
              filecache_duration        = 300
              num_retries               = 10
            }
          }
          codec_specification       = "RFC_4281"
          directory_structure       = "SINGLE_DIRECTORY"
          manifest_compression      = "NONE"
          manifest_duration_format  = "FLOATING_POINT"
          mode                      = "LIVE"
          program_date_time         = "INCLUDE"
          program_date_time_period  = 600
          segment_length            = 6
          segments_per_subdirectory = 10000
          stream_inf_resolution     = "INCLUDE"
          timed_metadata_id3_frame  = "PRIV"
          timed_metadata_id3_period = 10
        }
      }

      # 1080p output
      outputs {
        audio_description_names = ["audio_1"]
        output_name             = "1080p"
        video_description_name  = "video_1080p"
        output_settings {
          hls_output_settings {
            name_modifier = "_1080p"
            hls_settings {
              standard_hls_settings {
                audio_rendition_sets = "program_audio"
                m3u8_settings {
                  audio_frames_per_pes = 4
                  audio_pids           = "492-498"
                  pcr_control          = "PCR_EVERY_PES_PACKET"
                  pcr_period           = 80
                  program_num          = 1
                  video_pid            = 481
                }
              }
            }
          }
        }
      }

      # 720p output
      outputs {
        audio_description_names = ["audio_1"]
        output_name             = "720p"
        video_description_name  = "video_720p"
        output_settings {
          hls_output_settings {
            name_modifier = "_720p"
            hls_settings {
              standard_hls_settings {
                audio_rendition_sets = "program_audio"
                m3u8_settings {
                  audio_frames_per_pes = 4
                  audio_pids           = "492-498"
                  pcr_control          = "PCR_EVERY_PES_PACKET"
                  pcr_period           = 80
                  program_num          = 1
                  video_pid            = 481
                }
              }
            }
          }
        }
      }

      # 480p output
      outputs {
        audio_description_names = ["audio_1"]
        output_name             = "480p"
        video_description_name  = "video_480p"
        output_settings {
          hls_output_settings {
            name_modifier = "_480p"
            hls_settings {
              standard_hls_settings {
                audio_rendition_sets = "program_audio"
                m3u8_settings {
                  audio_frames_per_pes = 4
                  audio_pids           = "492-498"
                  pcr_control          = "PCR_EVERY_PES_PACKET"
                  pcr_period           = 80
                  program_num          = 1
                  video_pid            = 481
                }
              }
            }
          }
        }
      }
    }

    timecode_config {
      source = "EMBEDDED"
    }
  }

  # Start the channel in IDLE state to avoid costs
  lifecycle {
    ignore_changes = [state]
  }

  tags = var.tags
}

# Lambda function for MediaLive cost control
resource "aws_lambda_function" "medialive_controller" {
  count = var.enable_medialive && var.enable_cost_controls ? 1 : 0

  filename      = "${path.module}/functions/medialive_controller.zip"
  function_name = "${var.project_name}-${var.environment}-medialive-controller"
  role          = aws_iam_role.medialive_controller[0].arn
  handler       = "medialive_controller.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      CHANNEL_ID           = aws_medialive_channel.streaming_channel[0].id
      MAX_RUNTIME_HOURS    = var.max_runtime_hours
      COST_ALERT_THRESHOLD = var.cost_alert_threshold
      SNS_TOPIC_ARN        = var.sns_topic_arn
      ENVIRONMENT          = var.environment
      LOG_LEVEL            = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.medialive_controller_basic,
    aws_cloudwatch_log_group.medialive_controller,
    data.archive_file.medialive_controller
  ]

  tags = var.tags
}

# Archive file for MediaLive controller
data "archive_file" "medialive_controller" {
  count = var.enable_medialive && var.enable_cost_controls ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/functions/medialive_controller.py"
  output_path = "${path.module}/functions/medialive_controller.zip"
}

# IAM role for MediaLive controller Lambda
resource "aws_iam_role" "medialive_controller" {
  count = var.enable_medialive && var.enable_cost_controls ? 1 : 0

  name = "${var.project_name}-${var.environment}-medialive-controller-role"

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

resource "aws_iam_role_policy_attachment" "medialive_controller_basic" {
  count = var.enable_medialive && var.enable_cost_controls ? 1 : 0

  role       = aws_iam_role.medialive_controller[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# MediaLive permissions for controller
resource "aws_iam_role_policy" "medialive_controller_policy" {
  count = var.enable_medialive && var.enable_cost_controls ? 1 : 0

  name = "${var.project_name}-${var.environment}-medialive-controller-policy"
  role = aws_iam_role.medialive_controller[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "medialive:StartChannel",
          "medialive:StopChannel",
          "medialive:DescribeChannel",
          "medialive:ListChannels"
        ]
        Resource = aws_medialive_channel.streaming_channel[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch log group for MediaLive controller
resource "aws_cloudwatch_log_group" "medialive_controller" {
  count = var.enable_medialive && var.enable_cost_controls ? 1 : 0

  name              = "/aws/lambda/${var.project_name}-${var.environment}-medialive-controller"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# EventBridge rule for automatic shutdown
resource "aws_cloudwatch_event_rule" "medialive_auto_shutdown" {
  count = var.enable_medialive && var.enable_cost_controls && var.auto_shutdown_enabled ? 1 : 0

  name                = "${var.project_name}-${var.environment}-medialive-auto-shutdown"
  description         = "Automatically shutdown MediaLive channel after max runtime"
  schedule_expression = "rate(1 hour)" # Check every hour

  tags = var.tags
}

# EventBridge target for auto shutdown
resource "aws_cloudwatch_event_target" "medialive_auto_shutdown_target" {
  count = var.enable_medialive && var.enable_cost_controls && var.auto_shutdown_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.medialive_auto_shutdown[0].name
  target_id = "MediaLiveControllerTarget"
  arn       = aws_lambda_function.medialive_controller[0].arn

  input = jsonencode({
    action = "check_runtime"
  })
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "medialive_controller_eventbridge" {
  count = var.enable_medialive && var.enable_cost_controls && var.auto_shutdown_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.medialive_controller[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.medialive_auto_shutdown[0].arn
}

# CloudWatch Alarms for cost monitoring
resource "aws_cloudwatch_metric_alarm" "medialive_running_time" {
  count = var.enable_medialive && var.enable_cost_controls ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-medialive-running-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ChannelRunningTime"
  namespace           = "Custom/MediaLive"
  period              = "3600" # 1 hour
  statistic           = "Maximum"
  threshold           = var.max_runtime_hours
  alarm_description   = "MediaLive channel has been running too long"
  alarm_actions       = [var.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ChannelId = aws_medialive_channel.streaming_channel[0].id
  }

  tags = var.tags
}