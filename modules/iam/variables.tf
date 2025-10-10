# IAM Module Variables

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

# Resource ARNs for cross-service permissions
variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs for service access"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs for encryption access"
  type        = list(string)
  default     = []
}

variable "kinesis_firehose_arns" {
  description = "List of Kinesis Firehose delivery stream ARNs"
  type        = list(string)
  default     = []
}

variable "kinesis_stream_arns" {
  description = "List of Kinesis stream ARNs"
  type        = list(string)
  default     = []
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs"
  type        = list(string)
  default     = []
}

variable "aurora_cluster_arns" {
  description = "List of Aurora cluster ARNs"
  type        = list(string)
  default     = []
}

variable "glue_catalog_arns" {
  description = "List of Glue catalog ARNs"
  type        = list(string)
  default     = []
}

variable "sns_topic_arns" {
  description = "List of SNS topic ARNs for notifications"
  type        = list(string)
  default     = []
}

# Role configuration
variable "enable_cross_account_access" {
  description = "Enable cross-account access for roles"
  type        = bool
  default     = false
}

variable "trusted_account_ids" {
  description = "List of trusted AWS account IDs for cross-account access"
  type        = list(string)
  default     = []
}

variable "external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = ""
}

# Policy customization
variable "additional_cloudwatch_permissions" {
  description = "Additional CloudWatch permissions for service roles"
  type        = list(string)
  default     = []
}

variable "additional_s3_permissions" {
  description = "Additional S3 permissions for service roles"
  type        = list(string)
  default     = []
}

variable "additional_dynamodb_permissions" {
  description = "Additional DynamoDB permissions for service roles"
  type        = list(string)
  default     = []
}

# Security settings
variable "require_mfa" {
  description = "Require MFA for role assumption"
  type        = bool
  default     = false
}

variable "max_session_duration" {
  description = "Maximum session duration for role assumption (seconds)"
  type        = number
  default     = 3600  # 1 hour
}

variable "force_detach_policies" {
  description = "Force detach policies when destroying roles"
  type        = bool
  default     = false
}

# Tagging
variable "additional_tags" {
  description = "Additional tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}

# User and application policy configuration
variable "create_user_groups" {
  description = "Create IAM groups for role-based access"
  type        = bool
  default     = true
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names for resource-based policies"
  type        = list(string)
  default     = []
}

variable "kms_key_ids" {
  description = "List of KMS key IDs for key policies"
  type        = list(string)
  default     = []
}

# Application-specific settings
variable "enable_developer_access" {
  description = "Enable developer access policies (dev environment only)"
  type        = bool
  default     = true
}

variable "enable_cross_service_access" {
  description = "Enable cross-service access in resource-based policies"
  type        = bool
  default     = true
}

variable "log_retention_policy_days" {
  description = "Log retention period for policy enforcement"
  type        = number
  default     = 7
}