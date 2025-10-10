# Variables for Glue Data Catalog Module

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

# S3 Configuration
variable "s3_logs_bucket_name" {
  description = "Name of the S3 bucket containing streaming logs"
  type        = string
}

variable "s3_logs_bucket_arn" {
  description = "ARN of the S3 bucket containing streaming logs"
  type        = string
}

# KMS Configuration
variable "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  type        = string
}

# Crawler Configuration
variable "crawler_schedule" {
  description = "Schedule for running the Glue Crawler (cron expression)"
  type        = string
  default     = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
}

variable "enable_crawler" {
  description = "Enable or disable the Glue Crawler"
  type        = bool
  default     = true
}

# Table Configuration
variable "enable_partition_projection" {
  description = "Enable partition projection for cost optimization"
  type        = bool
  default     = true
}

variable "partition_projection_year_range" {
  description = "Year range for partition projection (start,end)"
  type        = string
  default     = "2024,2030"
}

# Development Environment Optimizations
variable "crawler_recrawl_behavior" {
  description = "Recrawl behavior for the Glue Crawler"
  type        = string
  default     = "CRAWL_EVERYTHING"
  
  validation {
    condition = contains([
      "CRAWL_EVERYTHING",
      "CRAWL_NEW_FOLDERS_ONLY"
    ], var.crawler_recrawl_behavior)
    error_message = "Crawler recrawl behavior must be either CRAWL_EVERYTHING or CRAWL_NEW_FOLDERS_ONLY."
  }
}

variable "schema_change_update_behavior" {
  description = "How to handle schema changes in the Glue Crawler"
  type        = string
  default     = "UPDATE_IN_DATABASE"
  
  validation {
    condition = contains([
      "UPDATE_IN_DATABASE",
      "LOG"
    ], var.schema_change_update_behavior)
    error_message = "Schema change update behavior must be either UPDATE_IN_DATABASE or LOG."
  }
}

variable "schema_change_delete_behavior" {
  description = "How to handle deleted schemas in the Glue Crawler"
  type        = string
  default     = "LOG"
  
  validation {
    condition = contains([
      "LOG",
      "DELETE_FROM_DATABASE",
      "DEPRECATE_IN_DATABASE"
    ], var.schema_change_delete_behavior)
    error_message = "Schema change delete behavior must be LOG, DELETE_FROM_DATABASE, or DEPRECATE_IN_DATABASE."
  }
}

# Log Categories Configuration
variable "log_categories" {
  description = "List of log categories to create tables for"
  type        = list(string)
  default = [
    "application-logs",
    "security-events", 
    "performance-metrics",
    "user-activity",
    "system-changes"
  ]
}