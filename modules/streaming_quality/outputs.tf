# Outputs for Streaming Quality Module

# Lambda Functions
output "quality_manager_function_name" {
  description = "Quality manager Lambda function name"
  value       = aws_lambda_function.quality_manager.function_name
}

output "quality_manager_function_arn" {
  description = "Quality manager Lambda function ARN"
  value       = aws_lambda_function.quality_manager.arn
}

output "adaptive_bitrate_function_name" {
  description = "Adaptive bitrate Lambda function name"
  value       = aws_lambda_function.adaptive_bitrate.function_name
}

output "viewer_optimizer_function_name" {
  description = "Viewer optimizer Lambda function name"
  value       = aws_lambda_function.viewer_optimizer.function_name
}

# Quality Configuration
output "quality_tiers" {
  description = "Quality tier definitions"
  value       = var.quality_tiers
}

output "optimization_rules" {
  description = "Quality optimization rules"
  value       = var.optimization_rules
}

# Monitoring
output "quality_dashboard_name" {
  description = "CloudWatch dashboard name for quality metrics"
  value       = var.enable_quality_dashboard ? aws_cloudwatch_dashboard.quality_metrics[0].dashboard_name : null
}

output "quality_dashboard_url" {
  description = "CloudWatch dashboard URL for quality metrics"
  value       = var.enable_quality_dashboard ? "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.quality_metrics[0].dashboard_name}" : null
}

# Configuration Summary
output "streaming_quality_configuration" {
  description = "Streaming quality system configuration summary"
  value = {
    # Lambda Functions
    functions = {
      quality_manager  = aws_lambda_function.quality_manager.function_name
      adaptive_bitrate = aws_lambda_function.adaptive_bitrate.function_name
      viewer_optimizer = aws_lambda_function.viewer_optimizer.function_name
    }

    # Quality Tiers
    subscription_tiers = {
      for tier, config in var.quality_tiers : tier => {
        max_resolution     = config.max_resolution
        max_bitrate_mbps   = config.max_bitrate / 1000000
        allowed_qualities  = config.allowed_qualities
        concurrent_streams = config.concurrent_streams
        priority_access    = config.priority_access
      }
    }

    # Optimization Features
    optimization = {
      periodic_enabled   = var.enable_periodic_optimization
      schedule           = var.optimization_schedule
      buffer_threshold   = var.optimization_rules.buffer_ratio_threshold
      rebuffer_threshold = var.optimization_rules.rebuffer_count_threshold
      startup_threshold  = var.optimization_rules.startup_time_threshold
    }

    # Monitoring Features
    monitoring = {
      dashboard_enabled        = var.enable_quality_dashboard
      alarms_enabled           = var.enable_quality_monitoring
      buffer_alarm_threshold   = var.buffer_ratio_threshold
      rebuffer_alarm_threshold = var.rebuffer_threshold
    }

    # Integration Points
    integration = {
      aurora_cluster          = var.aurora_cluster_arn
      dynamodb_table          = var.dynamodb_analytics_table
      cloudfront_distribution = var.cloudfront_distribution_id
    }

    # Key Features
    features = [
      "Subscription-based quality enforcement",
      "Adaptive bitrate streaming",
      "Real-time viewer experience optimization",
      "Concurrent stream limiting",
      "Network condition adaptation",
      "Performance analytics and monitoring"
    ]
  }
}