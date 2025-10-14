# Variables for WAF Module

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

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "kms_key_arn" {
  description = "KMS key ARN for log encryption"
  type        = string
  default     = null
}

# Rate Limiting Configuration
variable "rate_limit_per_5min" {
  description = "Rate limit per 5 minutes per IP address"
  type        = number
  default     = 2000
  validation {
    condition     = var.rate_limit_per_5min >= 100 && var.rate_limit_per_5min <= 20000000
    error_message = "Rate limit must be between 100 and 20,000,000 requests per 5 minutes."
  }
}

# Geographic Blocking
variable "enable_geo_blocking" {
  description = "Enable geographic blocking"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for country in var.blocked_countries : length(country) == 2
    ])
    error_message = "Country codes must be 2-character ISO 3166-1 alpha-2 codes."
  }
}

# IP Access Control
variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges in CIDR notation"
  type        = list(string)
  default     = []
}

variable "admin_ip_ranges" {
  description = "List of admin IP ranges in CIDR notation for admin path access"
  type        = list(string)
  default     = []
}

# Request Size Limits
variable "max_request_body_size" {
  description = "Maximum request body size in bytes"
  type        = number
  default     = 8192 # 8KB - suitable for API requests
  validation {
    condition     = var.max_request_body_size >= 1024 && var.max_request_body_size <= 65536
    error_message = "Maximum request body size must be between 1KB and 64KB."
  }
}

# Rule Exclusions
variable "excluded_common_rules" {
  description = "List of AWS Managed Common Rule Set rules to exclude"
  type        = list(string)
  default     = []
}

# Monitoring Configuration
variable "enable_waf_alarms" {
  description = "Enable CloudWatch alarms for WAF"
  type        = bool
  default     = true
}

variable "sns_topic_arns" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "blocked_requests_threshold" {
  description = "Threshold for blocked requests alarm"
  type        = number
  default     = 100
}

variable "rate_limit_alarm_threshold" {
  description = "Threshold for rate limit alarm"
  type        = number
  default     = 50
}

# Security Configuration
variable "enable_sql_injection_protection" {
  description = "Enable SQL injection protection"
  type        = bool
  default     = true
}

variable "enable_xss_protection" {
  description = "Enable XSS protection"
  type        = bool
  default     = true
}

variable "enable_size_restrictions" {
  description = "Enable request size restrictions"
  type        = bool
  default     = true
}

variable "enable_admin_path_protection" {
  description = "Enable admin path protection"
  type        = bool
  default     = true
}