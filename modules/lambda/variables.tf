# Lambda Module Variables

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

# Network Configuration
variable "private_subnet_ids" {
  description = "List of private subnet IDs for Lambda functions"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

# Cognito Configuration
variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  type        = string
}

variable "jwt_secret_arn" {
  description = "ARN of JWT secret in Secrets Manager"
  type        = string
}

# Aurora Configuration
variable "aurora_cluster_arn" {
  description = "Aurora cluster ARN"
  type        = string
}

variable "aurora_secret_arn" {
  description = "Aurora master password secret ARN"
  type        = string
}

# DynamoDB Configuration
variable "dynamodb_streams_table" {
  description = "DynamoDB streams table name"
  type        = string
}

variable "dynamodb_tickets_table" {
  description = "DynamoDB support tickets table name"
  type        = string
}

variable "dynamodb_analytics_table" {
  description = "DynamoDB analytics table name"
  type        = string
}

# Media Services Configuration
variable "medialive_role_arn" {
  description = "MediaLive service role ARN"
  type        = string
  default     = ""
}

variable "s3_media_bucket" {
  description = "S3 media bucket name"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  type        = string
  default     = ""
}

# Payment Configuration - DISABLED FOR DEVELOPMENT
# Payment processing removed to simplify development workflow

# Support Configuration
variable "bedrock_model_id" {
  description = "Bedrock model ID for AI support"
  type        = string
  default     = "anthropic.claude-v2"
}

variable "support_notifications_topic_arn" {
  description = "SNS topic ARN for support notifications"
  type        = string
}

# Analytics Configuration
variable "athena_database_name" {
  description = "Athena database name"
  type        = string
}

variable "athena_workgroup_name" {
  description = "Athena workgroup name"
  type        = string
}

variable "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  type        = string
}

# Content Moderation Configuration
variable "rekognition_confidence_threshold" {
  description = "Minimum confidence threshold for Rekognition"
  type        = number
  default     = 80
}

variable "comprehend_confidence_threshold" {
  description = "Minimum confidence threshold for Comprehend"
  type        = number
  default     = 70
}

variable "moderation_notifications_topic_arn" {
  description = "SNS topic ARN for moderation notifications"
  type        = string
}