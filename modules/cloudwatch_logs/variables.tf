# Variables for CloudWatch Logs Module

variable "project_name" {
  description = "Name of the project"
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

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for log encryption"
  type        = string
}

# Subscription Filter Configuration
variable "enable_subscription_filters" {
  description = "Enable CloudWatch Logs subscription filters"
  type        = bool
  default     = false
}

variable "firehose_delivery_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream"
  type        = string
  default     = ""
}

# Filter Patterns for Different Services
variable "medialive_filter_pattern" {
  description = "Filter pattern for MediaLive logs"
  type        = string
  default     = "[timestamp, request_id, level=\"ERROR\" || level=\"WARN\", ...]"
}

variable "mediastore_filter_pattern" {
  description = "Filter pattern for MediaStore logs"
  type        = string
  default     = "[timestamp, request_id, level=\"ERROR\" || level=\"WARN\", ...]"
}

variable "ecs_filter_pattern" {
  description = "Filter pattern for ECS logs"
  type        = string
  default     = "[timestamp, request_id, level=\"ERROR\" || level=\"WARN\", ...]"
}

variable "api_gateway_filter_pattern" {
  description = "Filter pattern for API Gateway logs"
  type        = string
  default     = "[timestamp, request_id, status_code>=400, ...]"
}

variable "cognito_filter_pattern" {
  description = "Filter pattern for Cognito logs"
  type        = string
  default     = "[timestamp, request_id, level=\"ERROR\" || level=\"WARN\", ...]"
}

variable "payment_filter_pattern" {
  description = "Filter pattern for Payment logs"
  type        = string
  default     = "[timestamp, request_id, level=\"ERROR\" || level=\"WARN\" || level=\"INFO\", ...]"
}

variable "application_filter_pattern" {
  description = "Filter pattern for Application logs"
  type        = string
  default     = "[timestamp, request_id, level=\"ERROR\" || level=\"WARN\", ...]"
}

variable "infrastructure_filter_pattern" {
  description = "Filter pattern for Infrastructure logs"
  type        = string
  default     = "[timestamp, request_id, level=\"ERROR\" || level=\"WARN\", ...]"
}

# CloudWatch Alarms Configuration
variable "enable_alarms" {
  description = "Enable CloudWatch alarms for log monitoring"
  type        = bool
  default     = true
}

variable "alarm_evaluation_periods" {
  description = "Number of periods for CloudWatch alarm evaluation"
  type        = number
  default     = 2
}

variable "error_rate_threshold" {
  description = "Threshold for error rate alarm"
  type        = number
  default     = 10
}

variable "log_volume_threshold" {
  description = "Threshold for log volume spike alarm"
  type        = number
  default     = 1000
}

variable "payment_error_threshold" {
  description = "Threshold for payment service error alarm"
  type        = number
  default     = 1
}

variable "api_4xx_threshold" {
  description = "Threshold for API Gateway 4xx error alarm"
  type        = number
  default     = 20
}

variable "api_5xx_threshold" {
  description = "Threshold for API Gateway 5xx error alarm"
  type        = number
  default     = 5
}

variable "medialive_error_threshold" {
  description = "Threshold for MediaLive error alarm"
  type        = number
  default     = 3
}