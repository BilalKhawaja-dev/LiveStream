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
}# Cost
 monitoring and budget configuration
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
  default     = "rate(7 days)"  # Weekly analysis
}# A
utomated cleanup configuration
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
  default     = "rate(7 days)"  # Weekly cleanup
}

variable "logs_cleanup_schedule" {
  description = "Schedule expression for CloudWatch logs cleanup"
  type        = string
  default     = "rate(3 days)"  # Every 3 days
}