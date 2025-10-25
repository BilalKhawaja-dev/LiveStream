# Monitoring Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "streaming-logs"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Resource identifiers for dashboard metrics
variable "s3_logs_bucket_name" {
  description = "Name of the S3 logs bucket"
  type        = string
}

variable "s3_error_logs_bucket_name" {
  description = "Name of the S3 error logs bucket"
  type        = string
}

variable "s3_backups_bucket_name" {
  description = "Name of the S3 backups bucket"
  type        = string
}

variable "s3_athena_results_bucket_name" {
  description = "Name of the S3 Athena results bucket"
  type        = string
}

variable "aurora_cluster_id" {
  description = "Aurora cluster identifier"
  type        = string
}

variable "dynamodb_log_metadata_table_name" {
  description = "DynamoDB log metadata table name"
  type        = string
}

variable "athena_workgroup_name" {
  description = "Athena workgroup name"
  type        = string
}

variable "glue_crawler_name" {
  description = "Glue crawler name"
  type        = string
}

# Dashboard configuration
variable "enable_security_dashboard" {
  description = "Enable security monitoring dashboard"
  type        = bool
  default     = true
}

variable "enable_cost_dashboard" {
  description = "Enable cost monitoring dashboard"
  type        = bool
  default     = true
}

variable "enable_performance_dashboard" {
  description = "Enable query performance dashboard"
  type        = bool
  default     = true
}

variable "dashboard_refresh_interval" {
  description = "Dashboard refresh interval in seconds"
  type        = number
  default     = 300
}

# Custom metrics configuration
variable "custom_metrics_namespace" {
  description = "Namespace for custom metrics"
  type        = string
  default     = ""
}

variable "enable_custom_widgets" {
  description = "Enable custom dashboard widgets"
  type        = bool
  default     = false
}

# Tagging
variable "additional_tags" {
  description = "Additional tags to apply to monitoring resources"
  type        = map(string)
  default     = {}
}

# Cost monitoring and budget configuration
variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 100
}

variable "budget_notification_emails" {
  description = "List of email addresses for budget notifications"
  type        = list(string)
  default     = []
}

variable "enable_service_budgets" {
  description = "Enable service-specific budgets"
  type        = bool
  default     = true
}

variable "s3_budget_limit" {
  description = "S3 monthly budget limit in USD"
  type        = number
  default     = 30
}

variable "rds_budget_limit" {
  description = "RDS monthly budget limit in USD"
  type        = number
  default     = 40
}

variable "billing_alarm_threshold" {
  description = "Billing alarm threshold in USD"
  type        = number
  default     = 80
}

variable "enable_service_cost_alarms" {
  description = "Enable service-specific cost alarms"
  type        = bool
  default     = true
}

variable "s3_cost_alarm_threshold" {
  description = "S3 cost alarm threshold in USD"
  type        = number
  default     = 25
}

variable "athena_cost_alarm_threshold" {
  description = "Athena cost alarm threshold in USD"
  type        = number
  default     = 10
}

variable "data_transfer_cost_alarm_threshold" {
  description = "Data transfer cost alarm threshold in USD"
  type        = number
  default     = 15
}

variable "enable_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection"
  type        = bool
  default     = true
}

variable "anomaly_detection_email" {
  description = "Email address for anomaly detection notifications"
  type        = string
  default     = ""
}

variable "anomaly_threshold_amount" {
  description = "Anomaly detection threshold amount in USD"
  type        = number
  default     = 20
}

variable "enable_cost_optimization_lambda" {
  description = "Enable automated cost optimization recommendations"
  type        = bool
  default     = true
}

variable "cost_optimization_schedule" {
  description = "Schedule expression for cost optimization analysis"
  type        = string
  default     = "rate(7 days)" # Weekly analysis
}

# Automated cleanup configuration
variable "enable_automated_cleanup" {
  description = "Enable automated cleanup procedures"
  type        = bool
  default     = true
}

variable "athena_results_retention_days" {
  description = "Retention period for Athena query results in days"
  type        = number
  default     = 30
}

variable "query_results_retention_days" {
  description = "Retention period for query results in days"
  type        = number
  default     = 30
}

variable "log_cleanup_retention_days" {
  description = "Retention period for CloudWatch log streams in days"
  type        = number
  default     = 14
}

variable "s3_cleanup_schedule" {
  description = "Schedule expression for S3 cleanup"
  type        = string
  default     = "rate(7 days)" # Weekly cleanup
}

variable "logs_cleanup_schedule" {
  description = "Schedule expression for CloudWatch logs cleanup"
  type        = string
  default     = "rate(3 days)" # Every 3 days
}

# Security and encryption configuration
variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

variable "enable_sns_encryption" {
  description = "Enable SNS topic encryption with customer-managed keys"
  type        = bool
  default     = true
}

variable "sns_message_retention_seconds" {
  description = "SNS message retention period in seconds"
  type        = number
  default     = 1209600 # 14 days
  validation {
    condition     = var.sns_message_retention_seconds >= 60 && var.sns_message_retention_seconds <= 1209600
    error_message = "SNS message retention must be between 60 seconds and 14 days."
  }
}

# Lambda Function URL configuration
variable "enable_lambda_function_urls" {
  description = "Enable Lambda function URLs with authentication"
  type        = bool
  default     = false
}

variable "allowed_origins" {
  description = "Allowed origins for Lambda function URL CORS"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for origin in var.allowed_origins : can(regex("^https://", origin))
    ])
    error_message = "All origins must use HTTPS protocol."
  }
}

# Streaming Platform Specific Variables
variable "alb_name" {
  description = "Application Load Balancer name for monitoring"
  type        = string
  default     = ""
}

variable "medialive_channel_id" {
  description = "MediaLive channel ID for monitoring"
  type        = string
  default     = ""
}

variable "s3_media_bucket_name" {
  description = "S3 media bucket name for monitoring"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for monitoring"
  type        = string
  default     = ""
}

variable "websocket_api_id" {
  description = "WebSocket API Gateway ID for monitoring"
  type        = string
  default     = ""
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID for monitoring"
  type        = string
  default     = ""
}

# ECS Monitoring Configuration
variable "enable_ecs_monitoring" {
  description = "Enable ECS service monitoring and alarms"
  type        = bool
  default     = true
}

variable "ecs_cpu_threshold" {
  description = "CPU utilization threshold for ECS alarms"
  type        = number
  default     = 80
  validation {
    condition     = var.ecs_cpu_threshold > 0 && var.ecs_cpu_threshold <= 100
    error_message = "ECS CPU threshold must be between 1 and 100."
  }
}

variable "ecs_memory_threshold" {
  description = "Memory utilization threshold for ECS alarms"
  type        = number
  default     = 85
  validation {
    condition     = var.ecs_memory_threshold > 0 && var.ecs_memory_threshold <= 100
    error_message = "ECS memory threshold must be between 1 and 100."
  }
}

# Lambda Monitoring Configuration
variable "enable_lambda_monitoring" {
  description = "Enable Lambda function monitoring and alarms"
  type        = bool
  default     = true
}

variable "lambda_error_threshold" {
  description = "Error count threshold for Lambda alarms"
  type        = number
  default     = 5
}

variable "lambda_duration_threshold" {
  description = "Duration threshold for Lambda alarms in milliseconds"
  type        = number
  default     = 10000
}

# API Gateway Monitoring Configuration
variable "enable_api_monitoring" {
  description = "Enable API Gateway monitoring and alarms"
  type        = bool
  default     = true
}

variable "api_4xx_error_threshold" {
  description = "4XX error count threshold for API Gateway alarms"
  type        = number
  default     = 20
}

variable "api_5xx_error_threshold" {
  description = "5XX error count threshold for API Gateway alarms"
  type        = number
  default     = 5
}

variable "api_latency_threshold" {
  description = "Latency threshold for API Gateway alarms in milliseconds"
  type        = number
  default     = 5000
}

# Database Monitoring Configuration
variable "enable_database_monitoring" {
  description = "Enable database monitoring and alarms"
  type        = bool
  default     = true
}

variable "aurora_connection_threshold" {
  description = "Connection count threshold for Aurora alarms"
  type        = number
  default     = 80
}

variable "aurora_cpu_threshold" {
  description = "CPU utilization threshold for Aurora alarms"
  type        = number
  default     = 80
}

variable "dynamodb_throttle_threshold" {
  description = "Throttle count threshold for DynamoDB alarms"
  type        = number
  default     = 0
}

# Streaming Services Monitoring
variable "enable_streaming_monitoring" {
  description = "Enable streaming services monitoring"
  type        = bool
  default     = true
}

variable "medialive_error_threshold" {
  description = "Error count threshold for MediaLive alarms"
  type        = number
  default     = 1
}

variable "websocket_error_threshold" {
  description = "Error count threshold for WebSocket API alarms"
  type        = number
  default     = 10
}

# Notification Configuration
variable "enable_slack_notifications" {
  description = "Enable Slack notifications for alerts"
  type        = bool
  default     = false
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_pagerduty_integration" {
  description = "Enable PagerDuty integration for critical alerts"
  type        = bool
  default     = false
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key"
  type        = string
  default     = ""
  sensitive   = true
}

# Advanced Monitoring Features
variable "enable_x_ray_tracing" {
  description = "Enable AWS X-Ray tracing for distributed monitoring"
  type        = bool
  default     = false
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS"
  type        = bool
  default     = true
}

variable "enable_application_insights" {
  description = "Enable CloudWatch Application Insights"
  type        = bool
  default     = false
}

# Log Analysis Configuration
variable "enable_log_insights_queries" {
  description = "Enable predefined CloudWatch Logs Insights queries"
  type        = bool
  default     = true
}

variable "log_insights_retention_days" {
  description = "Retention period for Log Insights query results"
  type        = number
  default     = 7
}

# Performance Monitoring
variable "enable_synthetic_monitoring" {
  description = "Enable CloudWatch Synthetics for endpoint monitoring"
  type        = bool
  default     = false
}

variable "synthetic_canary_schedule" {
  description = "Schedule expression for synthetic canary runs"
  type        = string
  default     = "rate(5 minutes)"
}

variable "monitored_endpoints" {
  description = "List of endpoints to monitor with synthetic canaries"
  type        = list(string)
  default     = []
}