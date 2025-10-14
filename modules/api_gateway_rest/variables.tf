variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Authentication configuration
variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool for authentication"
  type        = string
}

# JWT Lambda Authorizer configuration
variable "jwt_authorizer_function_arn" {
  description = "ARN of the JWT authorizer Lambda function"
  type        = string
  default     = ""
}

variable "jwt_authorizer_function_invoke_arn" {
  description = "Invoke ARN of the JWT authorizer Lambda function"
  type        = string
  default     = ""
}

variable "jwt_authorizer_cache_ttl" {
  description = "JWT authorizer cache TTL in seconds"
  type        = number
  default     = 300
}

# Security configuration
variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges for API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cors_allow_origin" {
  description = "CORS allow origin header value"
  type        = string
  default     = "'*'"
}

# Logging configuration
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

variable "api_logging_level" {
  description = "API Gateway logging level"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["OFF", "ERROR", "INFO"], var.api_logging_level)
    error_message = "API logging level must be OFF, ERROR, or INFO."
  }
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for API Gateway"
  type        = bool
  default     = true
}

# Throttling configuration
variable "throttling_rate_limit" {
  description = "API Gateway throttling rate limit (requests per second)"
  type        = number
  default     = 1000
}

variable "throttling_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 2000
}

# Caching configuration
variable "enable_caching" {
  description = "Enable API Gateway caching"
  type        = bool
  default     = false
}

variable "cache_ttl_seconds" {
  description = "Cache TTL in seconds"
  type        = number
  default     = 300
}

# Usage plan configuration - Basic plan
variable "basic_plan_quota_limit" {
  description = "Daily quota limit for basic plan"
  type        = number
  default     = 10000
}

variable "basic_plan_rate_limit" {
  description = "Rate limit for basic plan (requests per second)"
  type        = number
  default     = 100
}

variable "basic_plan_burst_limit" {
  description = "Burst limit for basic plan"
  type        = number
  default     = 200
}

# Usage plan configuration - Premium plan
variable "premium_plan_quota_limit" {
  description = "Daily quota limit for premium plan"
  type        = number
  default     = 50000
}

variable "premium_plan_rate_limit" {
  description = "Rate limit for premium plan (requests per second)"
  type        = number
  default     = 500
}

variable "premium_plan_burst_limit" {
  description = "Burst limit for premium plan"
  type        = number
  default     = 1000
}

# Usage plan configuration - Admin plan
variable "admin_plan_quota_limit" {
  description = "Daily quota limit for admin plan"
  type        = number
  default     = 100000
}

variable "admin_plan_rate_limit" {
  description = "Rate limit for admin plan (requests per second)"
  type        = number
  default     = 1000
}

variable "admin_plan_burst_limit" {
  description = "Burst limit for admin plan"
  type        = number
  default     = 2000
}

# API Key configuration
variable "create_api_keys" {
  description = "Create API keys for usage plans"
  type        = bool
  default     = true
}