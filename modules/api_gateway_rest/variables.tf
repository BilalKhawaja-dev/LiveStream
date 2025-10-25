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
} #
# ALB Integration for Frontend Proxy
variable "alb_dns_name" {
  description = "ALB DNS name for frontend proxy integration"
  type        = string
  default     = ""
}

# Lambda Integration Variables
variable "lambda_function_arns" {
  description = "Map of Lambda function ARNs"
  type        = map(string)
  default     = {}
}

variable "lambda_function_invoke_arns" {
  description = "Map of Lambda function invoke ARNs"
  type        = map(string)
  default     = {}
}

# WAF Configuration
variable "enable_waf" {
  description = "Enable WAF for API Gateway"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit per 5-minute period"
  type        = number
  default     = 2000
}

variable "enable_geo_blocking" {
  description = "Enable geographic blocking in WAF"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block"
  type        = list(string)
  default     = []
}

# Custom Domain Configuration
variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
  default     = ""
}

variable "custom_domain_name" {
  description = "Custom domain name for API Gateway"
  type        = string
  default     = ""
}

# Monitoring and Alerting Configuration
variable "alarm_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "api_4xx_error_threshold" {
  description = "Threshold for 4XX error alarm"
  type        = number
  default     = 20
}

variable "api_5xx_error_threshold" {
  description = "Threshold for 5XX error alarm"
  type        = number
  default     = 5
}

variable "api_latency_threshold" {
  description = "Threshold for latency alarm in milliseconds"
  type        = number
  default     = 5000
}

variable "enable_api_dashboard" {
  description = "Enable CloudWatch dashboard for API Gateway"
  type        = bool
  default     = true
}

# Usage Analytics Configuration
variable "enable_usage_analytics" {
  description = "Enable detailed usage analytics"
  type        = bool
  default     = true
}

# Advanced Security Configuration
variable "enable_request_validation" {
  description = "Enable request validation"
  type        = bool
  default     = true
}

variable "enable_response_compression" {
  description = "Enable response compression"
  type        = bool
  default     = true
}

variable "minimum_compression_size" {
  description = "Minimum response size for compression in bytes"
  type        = number
  default     = 1024
}

# Performance Configuration
variable "enable_api_cache_encryption" {
  description = "Enable API Gateway cache encryption"
  type        = bool
  default     = true
}

variable "cache_cluster_size" {
  description = "API Gateway cache cluster size"
  type        = string
  default     = "0.5"
  validation {
    condition = contains([
      "0.5", "1.6", "6.1", "13.5", "28.4", "58.2", "118", "237"
    ], var.cache_cluster_size)
    error_message = "Cache cluster size must be a valid API Gateway cache size."
  }
}

# Integration Configuration
variable "integration_timeout" {
  description = "Integration timeout in milliseconds"
  type        = number
  default     = 29000
  validation {
    condition     = var.integration_timeout >= 50 && var.integration_timeout <= 29000
    error_message = "Integration timeout must be between 50 and 29000 milliseconds."
  }
}

variable "enable_integration_caching" {
  description = "Enable integration response caching"
  type        = bool
  default     = false
}

# API Documentation Configuration
variable "enable_api_documentation" {
  description = "Enable API documentation generation"
  type        = bool
  default     = true
}

variable "api_description" {
  description = "API description for documentation"
  type        = string
  default     = "Streaming Platform REST API"
}

variable "api_version" {
  description = "API version"
  type        = string
  default     = "1.0.0"
}

# Resource Policy Configuration
variable "enable_resource_policy" {
  description = "Enable API Gateway resource policy"
  type        = bool
  default     = true
}

variable "allowed_principals" {
  description = "List of allowed AWS principals"
  type        = list(string)
  default     = []
}

variable "denied_principals" {
  description = "List of denied AWS principals"
  type        = list(string)
  default     = []
}

# Client Certificate Configuration
variable "enable_client_certificate" {
  description = "Enable client certificate for backend authentication"
  type        = bool
  default     = false
}

variable "client_certificate_description" {
  description = "Description for client certificate"
  type        = string
  default     = "Client certificate for API Gateway backend authentication"
}

# Canary Deployment Configuration
variable "enable_canary_deployment" {
  description = "Enable canary deployment for API Gateway"
  type        = bool
  default     = false
}

variable "canary_traffic_percentage" {
  description = "Percentage of traffic to route to canary deployment"
  type        = number
  default     = 10
  validation {
    condition     = var.canary_traffic_percentage >= 0 && var.canary_traffic_percentage <= 100
    error_message = "Canary traffic percentage must be between 0 and 100."
  }
}

# SDK Generation Configuration
variable "enable_sdk_generation" {
  description = "Enable SDK generation for API"
  type        = bool
  default     = false
}

variable "sdk_types" {
  description = "List of SDK types to generate"
  type        = list(string)
  default     = ["javascript", "python", "java"]
  validation {
    condition = alltrue([
      for sdk_type in var.sdk_types : contains([
        "android", "ios", "javascript", "java", "python", "ruby", "go", "csharp"
      ], sdk_type)
    ])
    error_message = "SDK types must be valid API Gateway SDK types."
  }
}