# Outputs for CloudWatch Logs Module

# Log Group Outputs
output "medialive_log_group_name" {
  description = "Name of the MediaLive log group"
  value       = aws_cloudwatch_log_group.medialive.name
}

output "medialive_log_group_arn" {
  description = "ARN of the MediaLive log group"
  value       = aws_cloudwatch_log_group.medialive.arn
}

output "mediastore_log_group_name" {
  description = "Name of the MediaStore log group"
  value       = aws_cloudwatch_log_group.mediastore.name
}

output "mediastore_log_group_arn" {
  description = "ARN of the MediaStore log group"
  value       = aws_cloudwatch_log_group.mediastore.arn
}

output "ecs_log_group_name" {
  description = "Name of the ECS log group"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "ecs_log_group_arn" {
  description = "ARN of the ECS log group"
  value       = aws_cloudwatch_log_group.ecs.arn
}

output "api_gateway_log_group_name" {
  description = "Name of the API Gateway log group"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "api_gateway_log_group_arn" {
  description = "ARN of the API Gateway log group"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

output "cognito_log_group_name" {
  description = "Name of the Cognito log group"
  value       = aws_cloudwatch_log_group.cognito.name
}

output "cognito_log_group_arn" {
  description = "ARN of the Cognito log group"
  value       = aws_cloudwatch_log_group.cognito.arn
}

output "payment_log_group_name" {
  description = "Name of the Payment log group"
  value       = aws_cloudwatch_log_group.payment.name
}

output "payment_log_group_arn" {
  description = "ARN of the Payment log group"
  value       = aws_cloudwatch_log_group.payment.arn
}

output "application_log_group_name" {
  description = "Name of the Application log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "application_log_group_arn" {
  description = "ARN of the Application log group"
  value       = aws_cloudwatch_log_group.application.arn
}

output "infrastructure_log_group_name" {
  description = "Name of the Infrastructure log group"
  value       = aws_cloudwatch_log_group.infrastructure.name
}

output "infrastructure_log_group_arn" {
  description = "ARN of the Infrastructure log group"
  value       = aws_cloudwatch_log_group.infrastructure.arn
}

# IAM Role Outputs
output "cloudwatch_logs_role_arn" {
  description = "ARN of the CloudWatch Logs IAM role"
  value       = aws_iam_role.cloudwatch_logs_role.arn
}

output "service_logs_role_arn" {
  description = "ARN of the Service Logs IAM role"
  value       = aws_iam_role.service_logs_role.arn
}

# Consolidated Outputs
output "log_group_names" {
  description = "Map of all log group names"
  value = {
    medialive      = aws_cloudwatch_log_group.medialive.name
    mediastore     = aws_cloudwatch_log_group.mediastore.name
    ecs            = aws_cloudwatch_log_group.ecs.name
    api_gateway    = aws_cloudwatch_log_group.api_gateway.name
    cognito        = aws_cloudwatch_log_group.cognito.name
    payment        = aws_cloudwatch_log_group.payment.name
    application    = aws_cloudwatch_log_group.application.name
    infrastructure = aws_cloudwatch_log_group.infrastructure.name
  }
}

output "log_group_arns" {
  description = "Map of all log group ARNs"
  value = {
    medialive      = aws_cloudwatch_log_group.medialive.arn
    mediastore     = aws_cloudwatch_log_group.mediastore.arn
    ecs            = aws_cloudwatch_log_group.ecs.arn
    api_gateway    = aws_cloudwatch_log_group.api_gateway.arn
    cognito        = aws_cloudwatch_log_group.cognito.arn
    payment        = aws_cloudwatch_log_group.payment.arn
    application    = aws_cloudwatch_log_group.application.arn
    infrastructure = aws_cloudwatch_log_group.infrastructure.arn
  }
}

# Subscription Filter Outputs
output "subscription_filter_names" {
  description = "Map of subscription filter names"
  value = var.enable_subscription_filters ? {
    medialive      = aws_cloudwatch_log_subscription_filter.medialive_filter[0].name
    mediastore     = aws_cloudwatch_log_subscription_filter.mediastore_filter[0].name
    ecs            = aws_cloudwatch_log_subscription_filter.ecs_filter[0].name
    api_gateway    = aws_cloudwatch_log_subscription_filter.api_gateway_filter[0].name
    cognito        = aws_cloudwatch_log_subscription_filter.cognito_filter[0].name
    payment        = aws_cloudwatch_log_subscription_filter.payment_filter[0].name
    application    = aws_cloudwatch_log_subscription_filter.application_filter[0].name
    infrastructure = aws_cloudwatch_log_subscription_filter.infrastructure_filter[0].name
  } : {}
}

# CloudWatch Alarms Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for log alerts"
  value       = aws_sns_topic.log_alerts.arn
}

output "alarm_names" {
  description = "Map of CloudWatch alarm names"
  value = var.enable_alarms ? {
    high_error_rate   = aws_cloudwatch_metric_alarm.high_error_rate[0].alarm_name
    log_volume_spike  = aws_cloudwatch_metric_alarm.log_volume_spike[0].alarm_name
    payment_errors    = aws_cloudwatch_metric_alarm.payment_errors[0].alarm_name
    api_gateway_4xx   = aws_cloudwatch_metric_alarm.api_gateway_4xx[0].alarm_name
    api_gateway_5xx   = aws_cloudwatch_metric_alarm.api_gateway_5xx[0].alarm_name
    medialive_errors  = aws_cloudwatch_metric_alarm.medialive_errors[0].alarm_name
  } : {}
}