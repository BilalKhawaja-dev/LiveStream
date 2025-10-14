# Variables for Streaming Quality Module

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

# Database Configuration
variable "aurora_cluster_arn" {
  description = "Aurora cluster ARN for user data"
  type        = string
}

variable "aurora_secret_arn" {
  description = "Aurora secret ARN for database access"
  type        = string
}

variable "dynamodb_analytics_table" {
  description = "DynamoDB table for analytics and metrics"
  type        = string
}

# CloudFront Configuration
variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache management"
  type        = string
}

# Quality Tier Configuration
variable "quality_tiers" {
  description = "Quality tier definitions"
  type = map(object({
    max_resolution     = string
    max_bitrate        = number
    allowed_qualities  = list(string)
    concurrent_streams = number
    priority_access    = optional(bool, false)
  }))
  default = {
    bronze = {
      max_resolution     = "480p"
      max_bitrate        = 1000000
      allowed_qualities  = ["480p"]
      concurrent_streams = 1
    }
    silver = {
      max_resolution     = "720p"
      max_bitrate        = 2500000
      allowed_qualities  = ["480p", "720p"]
      concurrent_streams = 2
    }
    gold = {
      max_resolution     = "1080p"
      max_bitrate        = 5000000
      allowed_qualities  = ["480p", "720p", "1080p"]
      concurrent_streams = 3
    }
    platinum = {
      max_resolution     = "1080p"
      max_bitrate        = 8000000
      allowed_qualities  = ["480p", "720p", "1080p"]
      concurrent_streams = 5
      priority_access    = true
    }
  }
}

# Optimization Configuration
variable "optimization_rules" {
  description = "Quality optimization rules"
  type = object({
    buffer_ratio_threshold   = number
    rebuffer_count_threshold = number
    startup_time_threshold   = number
    quality_switch_threshold = number
  })
  default = {
    buffer_ratio_threshold   = 0.2
    rebuffer_count_threshold = 3
    startup_time_threshold   = 5000
    quality_switch_threshold = 5
  }
}

variable "enable_periodic_optimization" {
  description = "Enable periodic quality optimization"
  type        = bool
  default     = true
}

variable "optimization_schedule" {
  description = "Schedule for periodic optimization (EventBridge expression)"
  type        = string
  default     = "rate(15 minutes)"
}

# Monitoring Configuration
variable "enable_quality_dashboard" {
  description = "Enable CloudWatch dashboard for quality metrics"
  type        = bool
  default     = true
}

variable "enable_quality_monitoring" {
  description = "Enable CloudWatch alarms for quality monitoring"
  type        = bool
  default     = true
}

variable "buffer_ratio_threshold" {
  description = "Buffer ratio threshold for alarms"
  type        = number
  default     = 0.3
}

variable "rebuffer_threshold" {
  description = "Rebuffer count threshold for alarms"
  type        = number
  default     = 5
}

variable "sns_topic_arns" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}