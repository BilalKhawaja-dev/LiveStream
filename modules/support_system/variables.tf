# Variables for Support System Module

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
variable "dynamodb_tickets_table" {
  description = "DynamoDB table for support tickets"
  type        = string
}

# AI Configuration
variable "bedrock_model_id" {
  description = "Bedrock model ID for AI support"
  type        = string
  default     = "anthropic.claude-v2"
}

variable "knowledge_base_id" {
  description = "Bedrock knowledge base ID"
  type        = string
  default     = ""
}

# Email Configuration
variable "support_email_addresses" {
  description = "Email addresses for general support notifications"
  type        = list(string)
  default     = []
}

variable "technical_email_addresses" {
  description = "Email addresses for technical support notifications"
  type        = list(string)
  default     = []
}

variable "billing_email_addresses" {
  description = "Email addresses for billing support notifications"
  type        = list(string)
  default     = []
}

variable "urgent_email_addresses" {
  description = "Email addresses for urgent support notifications"
  type        = list(string)
  default     = []
}

# Monitoring Configuration
variable "enable_support_dashboard" {
  description = "Enable CloudWatch dashboard for support metrics"
  type        = bool
  default     = true
}

variable "enable_support_monitoring" {
  description = "Enable CloudWatch alarms for support monitoring"
  type        = bool
  default     = true
}

variable "high_ticket_volume_threshold" {
  description = "Threshold for high ticket volume alarm"
  type        = number
  default     = 50
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