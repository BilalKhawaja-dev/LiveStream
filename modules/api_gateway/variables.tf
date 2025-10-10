# API Gateway Module Variables
# Requirements: 7.1, 7.2, 10.2

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the API Gateway"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the domain"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for API Gateway"
  type        = bool
  default     = true
}

variable "api_gateway_logging_level" {
  description = "API Gateway logging level (OFF, ERROR, INFO)"
  type        = string
  default     = "INFO"
}

variable "enable_data_trace" {
  description = "Enable data trace logging"
  type        = bool
  default     = false
}

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

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for API Gateway"
  type        = bool
  default     = true
}

variable "sns_topic_arns" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "error_4xx_threshold" {
  description = "Threshold for 4XX error alarm"
  type        = number
  default     = 10
}

variable "error_5xx_threshold" {
  description = "Threshold for 5XX error alarm"
  type        = number
  default     = 5
}

variable "latency_threshold_ms" {
  description = "Latency threshold in milliseconds"
  type        = number
  default     = 5000
}