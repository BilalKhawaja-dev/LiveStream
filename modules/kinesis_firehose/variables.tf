# Variables for Kinesis Firehose Module

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

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for log storage"
  type        = string
}

variable "s3_error_bucket_arn" {
  description = "ARN of the S3 bucket for error logs"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

# Firehose Configuration
variable "buffer_size" {
  description = "Kinesis Firehose buffer size in MB"
  type        = number
  default     = 1
}

variable "buffer_interval" {
  description = "Kinesis Firehose buffer interval in seconds"
  type        = number
  default     = 60
}

variable "compression_format" {
  description = "Compression format for S3 objects"
  type        = string
  default     = "GZIP"
}

# Data Transformation Configuration
variable "enable_data_format_conversion" {
  description = "Enable data format conversion to Parquet"
  type        = bool
  default     = false
}

variable "enable_data_processing" {
  description = "Enable data processing with Lambda"
  type        = bool
  default     = false
}

variable "glue_database_name" {
  description = "Name of the Glue database for schema configuration"
  type        = string
  default     = ""
}

variable "glue_table_name" {
  description = "Name of the Glue table for schema configuration"
  type        = string
  default     = ""
}

variable "data_transformation_lambda_arn" {
  description = "ARN of the Lambda function for data transformation"
  type        = string
  default     = ""
}

# Monitoring Configuration
variable "enable_firehose_alarms" {
  description = "Enable CloudWatch alarms for Firehose monitoring"
  type        = bool
  default     = true
}

variable "firehose_error_threshold" {
  description = "Threshold for Firehose delivery error alarm"
  type        = number
  default     = 10
}