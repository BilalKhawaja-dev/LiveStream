# Variables for centralized logging and DR infrastructure
# Development environment defaults with cost optimization

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "streaming-platform"
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7 # Development optimized (vs 30 for prod)
}

variable "s3_lifecycle_hot_days" {
  description = "Days to keep logs in S3 Standard storage"
  type        = number
  default     = 7 # Development optimized (vs 30 for prod)
}

variable "s3_lifecycle_warm_days" {
  description = "Days to keep logs in S3 Standard-IA storage"
  type        = number
  default     = 30 # Development optimized (vs 90 for prod)
}

variable "s3_lifecycle_cold_days" {
  description = "Days to keep logs in S3 Glacier storage"
  type        = number
  default     = 365 # Development optimized (vs 2555 for prod - 7 years)
}

# Kinesis Firehose Configuration
variable "firehose_buffer_size" {
  description = "Kinesis Firehose buffer size in MB"
  type        = number
  default     = 1 # Development optimized (vs 5 for prod)
}

variable "firehose_buffer_interval" {
  description = "Kinesis Firehose buffer interval in seconds"
  type        = number
  default     = 60 # Development optimized (vs 300 for prod)
}

# Aurora Configuration
variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum capacity units"
  type        = number
  default     = 0.5 # Development optimized (vs 2 for prod)
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum capacity units"
  type        = number
  default     = 2 # Development optimized (vs 16 for prod)
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances to create"
  type        = number
  default     = 1 # Development optimized (vs 2+ for prod)
}

variable "enable_aurora" {
  description = "Enable Aurora database (disable for cost optimization in dev)"
  type        = bool
  default     = true
}

variable "aurora_engine_version" {
  description = "Aurora MySQL engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.02.0"
}

variable "aurora_database_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "streaming_logs"
}

variable "aurora_master_username" {
  description = "Master username for Aurora cluster"
  type        = string
  default     = "admin"
}

variable "aurora_port" {
  description = "Port for Aurora cluster"
  type        = number
  default     = 3306
}

variable "aurora_backup_retention_period" {
  description = "Aurora backup retention period in days"
  type        = number
  default     = 7 # Development optimized (vs 30 for prod)
}

variable "aurora_backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "aurora_maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection for Aurora cluster"
  type        = bool
  default     = false # Development optimized (vs true for prod)
}

variable "aurora_enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["error", "general", "slowquery"]
}

variable "aurora_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds"
  type        = number
  default     = 60 # Development optimized
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.aurora_monitoring_interval)
    error_message = "Enhanced monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60 seconds."
  }
}

variable "aurora_performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "aurora_performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7 # Development optimized (vs 30+ for prod)
}

variable "aurora_auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "aurora_enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for Aurora"
  type        = bool
  default     = true
}

variable "aurora_alarm_cpu_threshold" {
  description = "CPU utilization threshold for alarms (%)"
  type        = number
  default     = 80
  validation {
    condition     = var.aurora_alarm_cpu_threshold >= 10 && var.aurora_alarm_cpu_threshold <= 100
    error_message = "CPU threshold must be between 10 and 100 percent."
  }
}

variable "aurora_alarm_connection_threshold" {
  description = "Database connection count threshold for alarms"
  type        = number
  default     = 80
}

variable "aurora_alarm_freeable_memory_threshold" {
  description = "Freeable memory threshold for alarms (bytes)"
  type        = number
  default     = 134217728 # 128 MB
}

variable "aurora_backup_alarm_enabled" {
  description = "Enable backup failure alarms"
  type        = bool
  default     = true
}

variable "aurora_backup_window_hours" {
  description = "Expected backup completion time in hours"
  type        = number
  default     = 2
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST" # Development optimized for cost
}

variable "dynamodb_read_capacity" {
  description = "Read capacity units for provisioned billing mode"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "Write capacity units for provisioned billing mode"
  type        = number
  default     = 5
}

variable "dynamodb_enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = true
}

variable "dynamodb_backup_retention_days" {
  description = "DynamoDB point-in-time recovery retention in days"
  type        = number
  default     = 7 # Development optimized (vs 35 for prod)
}

variable "dynamodb_enable_streams" {
  description = "Enable DynamoDB Streams for change data capture"
  type        = bool
  default     = false
}

variable "dynamodb_stream_view_type" {
  description = "Stream view type for DynamoDB Streams"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}

variable "dynamodb_enable_ttl" {
  description = "Enable Time To Live (TTL) for automatic data cleanup"
  type        = bool
  default     = true
}

variable "dynamodb_enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for DynamoDB tables"
  type        = bool
  default     = true
}

variable "dynamodb_read_throttle_threshold" {
  description = "Read throttle events threshold for alarms"
  type        = number
  default     = 5
}

variable "dynamodb_write_throttle_threshold" {
  description = "Write throttle events threshold for alarms"
  type        = number
  default     = 5
}

variable "dynamodb_consumed_read_capacity_threshold" {
  description = "Consumed read capacity threshold percentage for alarms"
  type        = number
  default     = 80
}

variable "dynamodb_consumed_write_capacity_threshold" {
  description = "Consumed write capacity threshold percentage for alarms"
  type        = number
  default     = 80
}

variable "dynamodb_enable_autoscaling" {
  description = "Enable auto-scaling for provisioned tables"
  type        = bool
  default     = false
}

variable "dynamodb_autoscaling_read_target" {
  description = "Target utilization percentage for read capacity auto-scaling"
  type        = number
  default     = 70
}

variable "dynamodb_autoscaling_write_target" {
  description = "Target utilization percentage for write capacity auto-scaling"
  type        = number
  default     = 70
}

variable "dynamodb_autoscaling_min_read_capacity" {
  description = "Minimum read capacity for auto-scaling"
  type        = number
  default     = 5
}

variable "dynamodb_autoscaling_max_read_capacity" {
  description = "Maximum read capacity for auto-scaling"
  type        = number
  default     = 100
}

variable "dynamodb_autoscaling_min_write_capacity" {
  description = "Minimum write capacity for auto-scaling"
  type        = number
  default     = 5
}

variable "dynamodb_autoscaling_max_write_capacity" {
  description = "Maximum write capacity for auto-scaling"
  type        = number
  default     = 100
}

variable "dynamodb_backup_storage_threshold_bytes" {
  description = "Backup storage usage threshold in bytes for alarms"
  type        = number
  default     = 10737418240 # 10 GB
}

variable "dynamodb_enable_backup_validation" {
  description = "Enable automated backup validation with Lambda function"
  type        = bool
  default     = true
}

variable "dynamodb_backup_validation_schedule" {
  description = "Schedule expression for backup validation"
  type        = string
  default     = "rate(6 hours)"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for Multi-AZ deployment"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access (costs ~$45/month)"
  type        = bool
  default     = false # Disabled by default for cost optimization in dev
}

# Cost Optimization Flags
variable "enable_cross_region_backup" {
  description = "Enable cross-region backup (disabled for dev cost optimization)"
  type        = bool
  default     = false
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring (basic for dev cost optimization)"
  type        = bool
  default     = false
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights (disabled for dev cost optimization)"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "cloudwatch_alarm_evaluation_periods" {
  description = "Number of periods for CloudWatch alarm evaluation"
  type        = number
  default     = 2
}

variable "cloudwatch_alarm_threshold_error_rate" {
  description = "Error rate threshold for CloudWatch alarms (percentage)"
  type        = number
  default     = 5.0
}

# Security Configuration
variable "enable_mfa_delete" {
  description = "Enable MFA delete for S3 buckets (disabled for dev)"
  type        = bool
  default     = false
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7 # Development optimized (vs 30 for prod)
}

# Glue Data Catalog Configuration
variable "glue_crawler_schedule" {
  description = "Schedule for running the Glue Crawler (cron expression)"
  type        = string
  default     = "cron(0 2 * * ? *)" # Daily at 2 AM UTC for development
}

variable "enable_glue_crawler" {
  description = "Enable or disable the Glue Crawler"
  type        = bool
  default     = true
}

variable "glue_partition_projection_enabled" {
  description = "Enable partition projection for cost optimization"
  type        = bool
  default     = true
}

# Athena Configuration
variable "athena_results_retention_days" {
  description = "Retention period for Athena query results in days"
  type        = number
  default     = 30 # Development optimized (vs 90 for prod)
}

variable "athena_bytes_scanned_cutoff_gb" {
  description = "Athena bytes scanned cutoff per query in GB"
  type        = number
  default     = 1 # Development optimized (vs 10 for prod)
}

variable "enable_athena_query_logging" {
  description = "Enable CloudWatch logging for Athena queries"
  type        = bool
  default     = true
}

variable "enable_athena_cost_monitoring" {
  description = "Enable CloudWatch alarms for Athena cost monitoring"
  type        = bool
  default     = true
}

variable "enable_athena_performance_monitoring" {
  description = "Enable CloudWatch alarms for Athena performance monitoring"
  type        = bool
  default     = true
}

variable "athena_query_execution_time_threshold_minutes" {
  description = "Threshold for Athena query execution time alarm in minutes"
  type        = number
  default     = 5 # Development optimized
}

# IAM Configuration
variable "iam_create_user_groups" {
  description = "Create IAM groups for role-based access"
  type        = bool
  default     = true
}

variable "iam_enable_developer_access" {
  description = "Enable developer access policies (dev environment only)"
  type        = bool
  default     = true
}

variable "iam_enable_cross_service_access" {
  description = "Enable cross-service access in resource-based policies"
  type        = bool
  default     = true
}

variable "iam_require_mfa" {
  description = "Require MFA for role assumption"
  type        = bool
  default     = false
}

variable "iam_max_session_duration" {
  description = "Maximum session duration for role assumption (seconds)"
  type        = number
  default     = 3600 # 1 hour
}

variable "iam_enable_cross_account_access" {
  description = "Enable cross-account access for roles"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "monitoring_enable_security_dashboard" {
  description = "Enable security monitoring dashboard"
  type        = bool
  default     = true
}

variable "monitoring_enable_cost_dashboard" {
  description = "Enable cost monitoring dashboard"
  type        = bool
  default     = true
}

variable "monitoring_enable_performance_dashboard" {
  description = "Enable query performance dashboard"
  type        = bool
  default     = true
}

variable "monitoring_dashboard_refresh_interval" {
  description = "Dashboard refresh interval in seconds"
  type        = number
  default     = 300
}

variable "monitoring_monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 100
}

variable "monitoring_budget_notification_emails" {
  description = "List of email addresses for budget notifications"
  type        = list(string)
  default     = []
}

variable "monitoring_enable_service_budgets" {
  description = "Enable service-specific budgets"
  type        = bool
  default     = true
}

variable "monitoring_s3_budget_limit" {
  description = "S3 monthly budget limit in USD"
  type        = number
  default     = 30
}

variable "monitoring_rds_budget_limit" {
  description = "RDS monthly budget limit in USD"
  type        = number
  default     = 40
}

variable "monitoring_billing_alarm_threshold" {
  description = "Billing alarm threshold in USD"
  type        = number
  default     = 80
}

variable "monitoring_enable_service_cost_alarms" {
  description = "Enable service-specific cost alarms"
  type        = bool
  default     = true
}

variable "monitoring_s3_cost_alarm_threshold" {
  description = "S3 cost alarm threshold in USD"
  type        = number
  default     = 25
}

variable "monitoring_athena_cost_alarm_threshold" {
  description = "Athena cost alarm threshold in USD"
  type        = number
  default     = 10
}

variable "monitoring_data_transfer_cost_alarm_threshold" {
  description = "Data transfer cost alarm threshold in USD"
  type        = number
  default     = 15
}

variable "monitoring_enable_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection"
  type        = bool
  default     = true
}

variable "monitoring_anomaly_detection_email" {
  description = "Email address for anomaly detection notifications"
  type        = string
  default     = ""
}

variable "monitoring_anomaly_threshold_amount" {
  description = "Anomaly detection threshold amount in USD"
  type        = number
  default     = 20
}

variable "monitoring_enable_cost_optimization_lambda" {
  description = "Enable automated cost optimization recommendations"
  type        = bool
  default     = true
}

variable "monitoring_cost_optimization_schedule" {
  description = "Schedule expression for cost optimization analysis"
  type        = string
  default     = "rate(7 days)"
}

variable "monitoring_enable_automated_cleanup" {
  description = "Enable automated cleanup procedures"
  type        = bool
  default     = true
}

variable "monitoring_athena_results_retention_days" {
  description = "Retention period for Athena query results in days"
  type        = number
  default     = 30
}

variable "monitoring_query_results_retention_days" {
  description = "Retention period for query results in days"
  type        = number
  default     = 30
}

variable "monitoring_log_cleanup_retention_days" {
  description = "Retention period for CloudWatch log streams in days"
  type        = number
  default     = 14
}

variable "monitoring_s3_cleanup_schedule" {
  description = "Schedule expression for S3 cleanup"
  type        = string
  default     = "rate(7 days)"
}

variable "monitoring_logs_cleanup_schedule" {
  description = "Schedule expression for CloudWatch logs cleanup"
  type        = string
  default     = "rate(3 days)"
}

# ECS Configuration
variable "enable_ecs" {
  description = "Enable ECS for containerized applications"
  type        = bool
  default     = true # Enabled for streaming platform frontend applications
}

variable "ecs_applications" {
  description = "List of ECS applications to deploy"
  type        = list(string)
  default = [
    "viewer-portal",
    "creator-dashboard",
    "admin-portal",
    "support-system",
    "analytics-dashboard",
    "developer-console"
  ]
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks"
  type        = number
  default     = 256 # Development optimized
}

variable "ecs_task_memory" {
  description = "Memory for ECS tasks (MB)"
  type        = number
  default     = 512 # Development optimized
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks per service"
  type        = number
  default     = 1 # Development optimized
}

variable "ecs_use_spot_instances" {
  description = "Use Fargate Spot instances for cost optimization"
  type        = bool
  default     = true # Cost optimization
}

variable "ecs_enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = false # Disabled for cost optimization in dev
}

variable "ecs_enable_exec" {
  description = "Enable ECS Exec for debugging containers"
  type        = bool
  default     = false # Disabled by default for security
}

# ECS Capacity Provider Configuration
variable "ecs_fargate_base_capacity" {
  description = "Base capacity for Fargate capacity provider"
  type        = number
  default     = 1
}

variable "ecs_fargate_weight" {
  description = "Weight for Fargate capacity provider"
  type        = number
  default     = 1
}

variable "ecs_fargate_spot_base_capacity" {
  description = "Base capacity for Fargate Spot capacity provider"
  type        = number
  default     = 0
}

variable "ecs_fargate_spot_weight" {
  description = "Weight for Fargate Spot capacity provider"
  type        = number
  default     = 4 # Prefer Spot instances for cost optimization
}

# ECS Auto Scaling Configuration
variable "ecs_min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 10
}

variable "ecs_cpu_target_value" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
  default     = 70
}

variable "ecs_memory_target_value" {
  description = "Target memory utilization percentage for auto scaling"
  type        = number
  default     = 80
}

variable "ecs_scale_in_cooldown" {
  description = "Cooldown period in seconds for scale in operations"
  type        = number
  default     = 300
}

variable "ecs_scale_out_cooldown" {
  description = "Cooldown period in seconds for scale out operations"
  type        = number
  default     = 60
}

variable "ecs_enable_spot_instances" {
  description = "Enable Fargate Spot instances for cost optimization"
  type        = bool
  default     = true
}

variable "ecs_scheduled_scaling_enabled" {
  description = "Enable scheduled scaling for predictable workloads"
  type        = bool
  default     = false
}

# Container Configuration
variable "ecr_repository_url" {
  description = "ECR repository URL for container images (deprecated - now created by ECR module)"
  type        = string
  default     = ""
}

variable "ecr_image_tag_mutability" {
  description = "The tag mutability setting for the ECR repository"
  type        = string
  default     = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "Image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "ecr_scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the ECR repository"
  type        = bool
  default     = true
}

variable "ecr_encryption_type" {
  description = "The encryption type to use for the ECR repository"
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "KMS"], var.ecr_encryption_type)
    error_message = "Encryption type must be either AES256 or KMS."
  }
}

variable "ecr_max_image_count" {
  description = "Maximum number of images to keep in the ECR repository"
  type        = number
  default     = 10
}

variable "ecr_untagged_image_days" {
  description = "Number of days to keep untagged images in ECR"
  type        = number
  default     = 7
}

variable "ecr_allowed_account_ids" {
  description = "List of AWS account IDs that are allowed to access the ECR repository"
  type        = list(string)
  default     = []
}

variable "container_image_tag" {
  description = "Container image tag to deploy"
  type        = string
  default     = "latest"
}

# JWT Configuration
variable "jwt_authorizer_cache_ttl" {
  description = "JWT authorizer cache TTL in seconds"
  type        = number
  default     = 300
}

variable "lambda_log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.lambda_log_level)
    error_message = "Lambda log level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

# Media Services Configuration
variable "enable_media_services" {
  description = "Enable media services (S3 + CloudFront)"
  type        = bool
  default     = true
}

variable "media_enable_versioning" {
  description = "Enable S3 bucket versioning for media content"
  type        = bool
  default     = false
}

variable "media_ia_transition_days" {
  description = "Days after which media objects transition to IA storage"
  type        = number
  default     = 30
}

variable "media_glacier_transition_days" {
  description = "Days after which media objects transition to Glacier"
  type        = number
  default     = 90
}

variable "media_deep_archive_transition_days" {
  description = "Days after which media objects transition to Deep Archive"
  type        = number
  default     = 365
}

variable "media_noncurrent_version_expiration_days" {
  description = "Days after which noncurrent media versions expire"
  type        = number
  default     = 30
}

variable "enable_cloudfront" {
  description = "Enable CloudFront CDN for media delivery"
  type        = bool
  default     = true
}

variable "media_custom_domain" {
  description = "Custom domain for media CDN"
  type        = string
  default     = ""
}

variable "cloudfront_default_cache_ttl" {
  description = "Default CloudFront cache TTL in seconds"
  type        = number
  default     = 86400
}

variable "cloudfront_max_cache_ttl" {
  description = "Maximum CloudFront cache TTL in seconds"
  type        = number
  default     = 31536000
}

variable "cloudfront_price_class" {
  description = "CloudFront price class for cost optimization"
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_geo_restriction_type" {
  description = "CloudFront geographic restriction type"
  type        = string
  default     = "none"
}

variable "cloudfront_geo_restriction_locations" {
  description = "CloudFront geographic restriction locations"
  type        = list(string)
  default     = []
}

variable "media_cors_allowed_origins" {
  description = "CORS allowed origins for media content"
  type        = list(string)
  default     = ["*"]
}

variable "enable_media_monitoring" {
  description = "Enable media services monitoring"
  type        = bool
  default     = true
}

variable "media_s3_size_alarm_threshold_gb" {
  description = "S3 bucket size threshold in GB for alarms"
  type        = number
  default     = 100
}

variable "media_cloudfront_4xx_threshold" {
  description = "CloudFront 4xx error rate threshold"
  type        = number
  default     = 5
}

variable "media_enable_intelligent_tiering" {
  description = "Enable S3 Intelligent Tiering for media"
  type        = bool
  default     = true
}

variable "media_enable_transfer_acceleration" {
  description = "Enable S3 Transfer Acceleration for media"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "enable_monitoring_alerts" {
  description = "Enable monitoring alerts and notifications"
  type        = bool
  default     = true
}

# SSL Certificate and Domain Configuration
variable "ssl_certificate_arn" {
  description = "ARN of existing SSL certificate for ALB (leave empty to auto-create with ACM)"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Primary domain name for the application (leave empty for development without SSL)"
  type        = string
  default     = ""
}

variable "subject_alternative_names" {
  description = "Additional domain names for the SSL certificate"
  type        = list(string)
  default     = []
}

variable "enable_wildcard_certificate" {
  description = "Create a wildcard certificate for subdomains"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Enable IPv6 support"
  type        = bool
  default     = false
}

variable "enable_certificate_monitoring" {
  description = "Enable SSL certificate expiry monitoring"
  type        = bool
  default     = true
}

variable "certificate_expiry_threshold_days" {
  description = "Days before certificate expiry to trigger alarm"
  type        = number
  default     = 30
}

# WAF Configuration
variable "enable_waf" {
  description = "Enable AWS WAF for application security"
  type        = bool
  default     = true
}

variable "waf_rate_limit_per_5min" {
  description = "WAF rate limit per 5 minutes per IP address"
  type        = number
  default     = 2000
}

variable "waf_enable_geo_blocking" {
  description = "Enable geographic blocking in WAF"
  type        = bool
  default     = false
}

variable "waf_blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "waf_allowed_ip_ranges" {
  description = "List of allowed IP ranges in CIDR notation"
  type        = list(string)
  default     = []
}

variable "waf_admin_ip_ranges" {
  description = "List of admin IP ranges in CIDR notation for admin path access"
  type        = list(string)
  default     = []
}

variable "waf_max_request_body_size" {
  description = "Maximum request body size in bytes for WAF"
  type        = number
  default     = 8192
}

variable "waf_excluded_common_rules" {
  description = "List of AWS Managed Common Rule Set rules to exclude"
  type        = list(string)
  default     = []
}

variable "waf_enable_sql_injection_protection" {
  description = "Enable SQL injection protection in WAF"
  type        = bool
  default     = true
}

variable "waf_enable_xss_protection" {
  description = "Enable XSS protection in WAF"
  type        = bool
  default     = true
}

variable "waf_enable_size_restrictions" {
  description = "Enable request size restrictions in WAF"
  type        = bool
  default     = true
}

variable "waf_enable_admin_path_protection" {
  description = "Enable admin path protection in WAF"
  type        = bool
  default     = true
}

variable "waf_enable_alarms" {
  description = "Enable CloudWatch alarms for WAF"
  type        = bool
  default     = true
}

variable "waf_blocked_requests_threshold" {
  description = "Threshold for WAF blocked requests alarm"
  type        = number
  default     = 100
}

variable "waf_rate_limit_alarm_threshold" {
  description = "Threshold for WAF rate limit alarm"
  type        = number
  default     = 50
}

variable "enable_cdn" {
  description = "Enable CloudFront CDN"
  type        = bool
  default     = false
}

variable "enable_streaming" {
  description = "Enable MediaLive streaming (WARNING: Costs ~$10/day when running)"
  type        = bool
  default     = false
}

# API Gateway Configuration
variable "api_gateway_allowed_ips" {
  description = "List of allowed IP ranges for API Gateway access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "api_gateway_cors_origin" {
  description = "CORS allow origin header value for API Gateway"
  type        = string
  default     = "'*'"
}

variable "api_gateway_logging_level" {
  description = "API Gateway logging level"
  type        = string
  default     = "INFO"
}

variable "api_gateway_enable_xray" {
  description = "Enable X-Ray tracing for API Gateway"
  type        = bool
  default     = true
}

variable "api_gateway_rate_limit" {
  description = "API Gateway throttling rate limit (requests per second)"
  type        = number
  default     = 1000
}

variable "api_gateway_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 2000
}

variable "api_gateway_enable_caching" {
  description = "Enable API Gateway caching"
  type        = bool
  default     = false
}

variable "api_gateway_cache_ttl" {
  description = "API Gateway cache TTL in seconds"
  type        = number
  default     = 300
}

variable "api_gateway_basic_quota" {
  description = "Daily quota limit for basic API plan"
  type        = number
  default     = 10000
}

variable "api_gateway_basic_rate" {
  description = "Rate limit for basic API plan (requests per second)"
  type        = number
  default     = 100
}

variable "api_gateway_basic_burst" {
  description = "Burst limit for basic API plan"
  type        = number
  default     = 200
}

variable "api_gateway_premium_quota" {
  description = "Daily quota limit for premium API plan"
  type        = number
  default     = 50000
}

variable "api_gateway_premium_rate" {
  description = "Rate limit for premium API plan (requests per second)"
  type        = number
  default     = 500
}

variable "api_gateway_premium_burst" {
  description = "Burst limit for premium API plan"
  type        = number
  default     = 1000
}

variable "api_gateway_admin_quota" {
  description = "Daily quota limit for admin API plan"
  type        = number
  default     = 100000
}

variable "api_gateway_admin_rate" {
  description = "Rate limit for admin API plan (requests per second)"
  type        = number
  default     = 1000
}

variable "api_gateway_admin_burst" {
  description = "Burst limit for admin API plan"
  type        = number
  default     = 2000
}

variable "api_gateway_create_keys" {
  description = "Create API keys for usage plans"
  type        = bool
  default     = true
}

# Aurora backup and maintenance windows
variable "aurora_preferred_backup_window" {
  description = "Preferred backup window for Aurora cluster"
  type        = string
  default     = "03:00-04:00"
}

variable "aurora_preferred_maintenance_window" {
  description = "Preferred maintenance window for Aurora cluster"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# ECS Configuration
variable "ecs_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "api_base_url" {
  description = "Base URL for API endpoints"
  type        = string
  default     = ""
}
# API Gateway Configuration
variable "api_allowed_ip_ranges" {
  description = "List of allowed IP ranges for API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cors_allow_origin" {
  description = "CORS allow origin header value"
  type        = string
  default     = "'*'"
}

variable "api_throttling_rate_limit" {
  description = "API Gateway throttling rate limit (requests per second)"
  type        = number
  default     = 1000
}

variable "api_throttling_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 2000
}

variable "api_basic_plan_quota_limit" {
  description = "Daily quota limit for basic plan"
  type        = number
  default     = 10000
}

variable "api_basic_plan_rate_limit" {
  description = "Rate limit for basic plan (requests per second)"
  type        = number
  default     = 100
}

variable "api_premium_plan_quota_limit" {
  description = "Daily quota limit for premium plan"
  type        = number
  default     = 50000
}

variable "api_premium_plan_rate_limit" {
  description = "Rate limit for premium plan (requests per second)"
  type        = number
  default     = 500
}



variable "enable_medialive" {
  description = "Enable MediaLive for live streaming (costs ~$1.50/hour when running)"
  type        = bool
  default     = false
}