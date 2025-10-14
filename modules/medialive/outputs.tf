# Outputs for MediaLive Module

# MediaLive Channel
output "channel_id" {
  description = "MediaLive channel ID"
  value       = var.enable_medialive ? aws_medialive_channel.streaming_channel[0].id : null
}

output "channel_arn" {
  description = "MediaLive channel ARN"
  value       = var.enable_medialive ? aws_medialive_channel.streaming_channel[0].arn : null
}

output "channel_name" {
  description = "MediaLive channel name"
  value       = var.enable_medialive ? aws_medialive_channel.streaming_channel[0].name : null
}

# RTMP Input
output "rtmp_input_id" {
  description = "MediaLive RTMP input ID"
  value       = var.enable_medialive ? aws_medialive_input.rtmp_input[0].id : null
}

output "rtmp_input_destinations" {
  description = "RTMP input destinations for streaming"
  value = var.enable_medialive ? [
    for dest in aws_medialive_input.rtmp_input[0].destinations : {
      url         = "rtmp://${dest.url}:1935/live"
      stream_name = dest.stream_name
    }
  ] : []
}

# Cost Control
output "medialive_controller_function_name" {
  description = "MediaLive controller Lambda function name"
  value       = var.enable_medialive && var.enable_cost_controls ? aws_lambda_function.medialive_controller[0].function_name : null
}

output "medialive_controller_function_arn" {
  description = "MediaLive controller Lambda function ARN"
  value       = var.enable_medialive && var.enable_cost_controls ? aws_lambda_function.medialive_controller[0].arn : null
}

# IAM Role
output "medialive_access_role_arn" {
  description = "MediaLive access role ARN"
  value       = var.enable_medialive ? aws_iam_role.medialive_access_role[0].arn : null
}

# Configuration Summary
output "medialive_configuration" {
  description = "MediaLive configuration summary"
  value = var.enable_medialive ? {
    # Channel Configuration
    channel = {
      id          = aws_medialive_channel.streaming_channel[0].id
      name        = aws_medialive_channel.streaming_channel[0].name
      class       = var.channel_class
      resolution  = var.input_resolution
      max_bitrate = var.maximum_bitrate
    }

    # RTMP Input Configuration
    rtmp_input = {
      id = aws_medialive_input.rtmp_input[0].id
      destinations = [
        for dest in aws_medialive_input.rtmp_input[0].destinations : {
          url         = "rtmp://${dest.url}:1935/live"
          stream_name = dest.stream_name
        }
      ]
    }

    # Video Quality Configuration
    video_quality = {
      high_bitrate   = var.video_bitrates.high
      medium_bitrate = var.video_bitrates.medium
      low_bitrate    = var.video_bitrates.low
      resolutions    = ["1080p", "720p", "480p"]
    }

    # Cost Control Configuration
    cost_controls = {
      enabled               = var.enable_cost_controls
      max_runtime_hours     = var.max_runtime_hours
      cost_alert_threshold  = var.cost_alert_threshold
      auto_shutdown_enabled = var.auto_shutdown_enabled
      controller_function   = var.enable_cost_controls ? aws_lambda_function.medialive_controller[0].function_name : null
    }

    # Output Configuration
    output = {
      s3_bucket      = var.s3_destination_bucket_name
      output_format  = "HLS"
      segment_length = 6
      manifest_type  = "M3U8"
    }

    # Estimated Costs (USD per hour)
    estimated_costs = {
      single_pipeline_hd = 1.50
      standard_hd        = 3.00
      note               = "Actual costs may vary by region and usage"
    }

    # Security Configuration
    security = {
      allowed_cidr_blocks  = var.allowed_cidr_blocks
      input_security_group = aws_medialive_input_security_group.rtmp_input_sg[0].id
    }

    # Monitoring
    monitoring = {
      log_group_name     = var.enable_cost_controls ? aws_cloudwatch_log_group.medialive_controller[0].name : null
      sns_topic_arn      = var.sns_topic_arn
      auto_shutdown_rule = var.auto_shutdown_enabled ? aws_cloudwatch_event_rule.medialive_auto_shutdown[0].name : null
    }
  } : null
}

# Streaming URLs
output "streaming_info" {
  description = "Information for setting up streaming clients"
  value = var.enable_medialive ? {
    rtmp_endpoints = [
      for dest in aws_medialive_input.rtmp_input[0].destinations : {
        primary_url = "rtmp://${dest.url}:1935/live/${dest.stream_name}"
        stream_key  = dest.stream_name
        description = dest.stream_name == "${var.project_name}-primary" ? "Primary stream endpoint" : "Backup stream endpoint"
      }
    ]

    output_location = "s3://${var.s3_destination_bucket_name}/live-streams/"

    recommended_settings = {
      video_codec       = "H.264"
      audio_codec       = "AAC"
      keyframe_interval = "2 seconds"
      bitrate_1080p     = "${var.video_bitrates.high / 1000000} Mbps"
      bitrate_720p      = "${var.video_bitrates.medium / 1000000} Mbps"
      bitrate_480p      = "${var.video_bitrates.low / 1000000} Mbps"
    }

    cost_warning = "MediaLive incurs costs when running (~$${var.channel_class == \"SINGLE_PIPELINE\" ? \"1.50\" : \"3.00\"}/hour for HD). Use cost controls to manage expenses."
  } : null
}

# For integration with other modules
output "hls_output_bucket" {
  description = "S3 bucket for HLS output"
  value       = var.enable_medialive ? var.s3_destination_bucket_name : null
}

output "is_enabled" {
  description = "Whether MediaLive is enabled"
  value       = var.enable_medialive
}