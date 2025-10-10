# Variables for Athena Module

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "athena_results_bucket_name" {
  description = "Name of the S3 bucket for Athena query results"
  type        = string
}

variable "athena_results_bucket_arn" {
  description = "ARN of the S3 bucket for Athena query results"
  type        = string
}

variable "s3_logs_bucket_arn" {
  description = "ARN of the S3 bucket containing logs for querying"
  type        = string
}

variable "glue_database_name" {
  description = "Name of the Glue database for log analytics"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "athena_results_retention_days" {
  description = "Retention period for Athena query results in days"
  type        = number
  default     = 30
}

variable "enable_query_logging" {
  description = "Enable CloudWatch logging for Athena queries"
  type        = bool
  default     = true
}

variable "enable_cost_monitoring" {
  description = "Enable CloudWatch alarms for cost monitoring"
  type        = bool
  default     = true
}

variable "enable_performance_monitoring" {
  description = "Enable CloudWatch alarms for performance monitoring"
  type        = bool
  default     = true
}

variable "data_scanned_alarm_threshold" {
  description = "Threshold for data scanned alarm in bytes (1GB default for dev)"
  type        = number
  default     = 1073741824 # 1GB
}

variable "query_execution_time_threshold" {
  description = "Threshold for query execution time alarm in milliseconds"
  type        = number
  default     = 300000 # 5 minutes
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}