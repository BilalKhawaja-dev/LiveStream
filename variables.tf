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
  default     = "streaming-logs"
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
  default     = 10737418240  # 10 GB
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
}#
 IAM Configuration
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
  default     = 3600  # 1 hour
}

variable "iam_enable_cross_account_access" {
  description = "Enable cross-account access for roles"
  type        = bool
  default     = false
}#
 Monitoring Configuration
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