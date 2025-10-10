# DynamoDB Module Variables

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

# DynamoDB configuration
variable "billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
  
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "Billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "read_capacity" {
  description = "Read capacity units for provisioned billing mode"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units for provisioned billing mode"
  type        = number
  default     = 5
}

variable "gsi_read_capacity" {
  description = "Read capacity units for Global Secondary Indexes"
  type        = number
  default     = 5
}

variable "gsi_write_capacity" {
  description = "Write capacity units for Global Secondary Indexes"
  type        = number
  default     = 5
}

# Backup and recovery configuration
variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Point-in-time recovery retention period in days"
  type        = number
  default     = 7
}

# Streaming configuration
variable "enable_streams" {
  description = "Enable DynamoDB Streams for change data capture"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "Stream view type (KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES)"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
  
  validation {
    condition = contains([
      "KEYS_ONLY", 
      "NEW_IMAGE", 
      "OLD_IMAGE", 
      "NEW_AND_OLD_IMAGES"
    ], var.stream_view_type)
    error_message = "Stream view type must be one of: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES."
  }
}

# TTL configuration
variable "enable_ttl" {
  description = "Enable Time To Live (TTL) for automatic data cleanup"
  type        = bool
  default     = true
}

# Security configuration
variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

# Table-specific configurations
variable "log_metadata_table_config" {
  description = "Configuration for log metadata table"
  type = object({
    enable_ttl                    = optional(bool, true)
    enable_point_in_time_recovery = optional(bool, true)
    enable_streams               = optional(bool, false)
  })
  default = {
    enable_ttl                    = true
    enable_point_in_time_recovery = true
    enable_streams               = false
  }
}

variable "user_sessions_table_config" {
  description = "Configuration for user sessions table"
  type = object({
    enable_ttl                    = optional(bool, true)
    enable_point_in_time_recovery = optional(bool, true)
    enable_streams               = optional(bool, false)
  })
  default = {
    enable_ttl                    = true
    enable_point_in_time_recovery = true
    enable_streams               = false
  }
}

variable "system_config_table_config" {
  description = "Configuration for system config table"
  type = object({
    enable_ttl                    = optional(bool, false)
    enable_point_in_time_recovery = optional(bool, true)
    enable_streams               = optional(bool, true)
  })
  default = {
    enable_ttl                    = false
    enable_point_in_time_recovery = true
    enable_streams               = true
  }
}

variable "audit_trail_table_config" {
  description = "Configuration for audit trail table"
  type = object({
    enable_ttl                    = optional(bool, true)
    enable_point_in_time_recovery = optional(bool, true)
    enable_streams               = optional(bool, false)
  })
  default = {
    enable_ttl                    = true
    enable_point_in_time_recovery = true
    enable_streams               = false
  }
}

# Monitoring configuration
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for DynamoDB tables"
  type        = bool
  default     = true
}

variable "read_throttle_threshold" {
  description = "Read throttle events threshold for alarms"
  type        = number
  default     = 5
}

variable "write_throttle_threshold" {
  description = "Write throttle events threshold for alarms"
  type        = number
  default     = 5
}

variable "consumed_read_capacity_threshold" {
  description = "Consumed read capacity threshold percentage for alarms"
  type        = number
  default     = 80
}

variable "consumed_write_capacity_threshold" {
  description = "Consumed write capacity threshold percentage for alarms"
  type        = number
  default     = 80
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = ""
}

# Auto-scaling configuration (for provisioned billing mode)
variable "enable_autoscaling" {
  description = "Enable auto-scaling for provisioned tables"
  type        = bool
  default     = false
}

variable "autoscaling_read_target" {
  description = "Target utilization percentage for read capacity auto-scaling"
  type        = number
  default     = 70
}

variable "autoscaling_write_target" {
  description = "Target utilization percentage for write capacity auto-scaling"
  type        = number
  default     = 70
}

variable "autoscaling_min_read_capacity" {
  description = "Minimum read capacity for auto-scaling"
  type        = number
  default     = 5
}

variable "autoscaling_max_read_capacity" {
  description = "Maximum read capacity for auto-scaling"
  type        = number
  default     = 100
}

variable "autoscaling_min_write_capacity" {
  description = "Minimum write capacity for auto-scaling"
  type        = number
  default     = 5
}

variable "autoscaling_max_write_capacity" {
  description = "Maximum write capacity for auto-scaling"
  type        = number
  default     = 100
}

# Backup monitoring and validation configuration
variable "backup_storage_threshold_bytes" {
  description = "Backup storage usage threshold in bytes for alarms"
  type        = number
  default     = 10737418240  # 10 GB
}

variable "enable_backup_validation" {
  description = "Enable automated backup validation with Lambda function"
  type        = bool
  default     = true
}

variable "backup_validation_schedule" {
  description = "Schedule expression for backup validation (cron or rate)"
  type        = string
  default     = "rate(6 hours)"  # Run every 6 hours
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}