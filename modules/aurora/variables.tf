# Aurora Serverless v2 Module Variables

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

# Aurora cluster configuration
variable "engine_version" {
  description = "Aurora MySQL engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.02.0"
}

variable "database_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "streaming_logs"
}

variable "master_username" {
  description = "Master username for Aurora cluster"
  type        = string
  default     = "admin"
}

variable "port" {
  description = "Port for Aurora cluster"
  type        = number
  default     = 3306
}

# Serverless v2 scaling configuration
variable "min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity units"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity units"
  type        = number
  default     = 2.0
}

variable "instance_count" {
  description = "Number of Aurora instances to create"
  type        = number
  default     = 1
}

# Backup and maintenance configuration
variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  description = "Enable deletion protection for Aurora cluster"
  type        = bool
  default     = false
}

# Monitoring and logging configuration
variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["error", "general", "slowquery"]
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

# Security configuration
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

# CloudWatch alarms configuration
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for Aurora"
  type        = bool
  default     = true
}

variable "alarm_cpu_threshold" {
  description = "CPU utilization threshold for alarms (%)"
  type        = number
  default     = 80
}

variable "alarm_connection_threshold" {
  description = "Database connection count threshold for alarms"
  type        = number
  default     = 80
}

variable "alarm_freeable_memory_threshold" {
  description = "Freeable memory threshold for alarms (bytes)"
  type        = number
  default     = 134217728  # 128 MB
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = ""
}

# Backup monitoring configuration
variable "backup_alarm_enabled" {
  description = "Enable backup failure alarms"
  type        = bool
  default     = true
}

variable "backup_window_hours" {
  description = "Expected backup completion time in hours"
  type        = number
  default     = 2
}