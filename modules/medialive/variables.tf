# Variables for MediaLive Module

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# MediaLive Configuration
variable "enable_medialive" {
  description = "Enable MediaLive streaming (WARNING: This incurs costs when running)"
  type        = bool
  default     = false
}

variable "channel_class" {
  description = "MediaLive channel class (STANDARD or SINGLE_PIPELINE)"
  type        = string
  default     = "SINGLE_PIPELINE" # Cost-optimized option
  validation {
    condition = contains([
      "STANDARD",
      "SINGLE_PIPELINE"
    ], var.channel_class)
    error_message = "Channel class must be STANDARD or SINGLE_PIPELINE."
  }
}

variable "input_resolution" {
  description = "Input resolution for MediaLive channel"
  type        = string
  default     = "HD"
  validation {
    condition = contains([
      "SD",
      "HD",
      "UHD"
    ], var.input_resolution)
    error_message = "Input resolution must be SD, HD, or UHD."
  }
}

variable "maximum_bitrate" {
  description = "Maximum bitrate for MediaLive input"
  type        = string
  default     = "MAX_10_MBPS"
  validation {
    condition = contains([
      "MAX_10_MBPS",
      "MAX_20_MBPS",
      "MAX_50_MBPS"
    ], var.maximum_bitrate)
    error_message = "Maximum bitrate must be MAX_10_MBPS, MAX_20_MBPS, or MAX_50_MBPS."
  }
}

# Video Quality Configuration
variable "video_bitrates" {
  description = "Video bitrates for different quality levels"
  type = object({
    high   = number
    medium = number
    low    = number
  })
  default = {
    high   = 5000000 # 5 Mbps for 1080p
    medium = 2500000 # 2.5 Mbps for 720p
    low    = 1000000 # 1 Mbps for 480p
  }
}

# S3 Integration
variable "s3_destination_bucket_name" {
  description = "S3 bucket name for MediaLive output"
  type        = string
}

variable "s3_destination_bucket_arn" {
  description = "S3 bucket ARN for MediaLive output"
  type        = string
}

# Cost Control Configuration
variable "enable_cost_controls" {
  description = "Enable cost control features (auto-shutdown, alerts)"
  type        = bool
  default     = true
}

variable "max_runtime_hours" {
  description = "Maximum runtime hours before auto-shutdown"
  type        = number
  default     = 4
  validation {
    condition     = var.max_runtime_hours >= 1 && var.max_runtime_hours <= 24
    error_message = "Maximum runtime hours must be between 1 and 24."
  }
}

variable "cost_alert_threshold" {
  description = "Cost threshold in USD for alerts"
  type        = number
  default     = 50
}

variable "auto_shutdown_enabled" {
  description = "Enable automatic shutdown after max runtime"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = ""
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to push RTMP streams"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict in production
}