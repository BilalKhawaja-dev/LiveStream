# Variables for S3 Storage Module

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

# KMS Configuration
variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

# Lifecycle Policy Configuration
variable "hot_tier_days" {
  description = "Number of days to keep logs in hot tier (Standard storage)"
  type        = number
  default     = 7
}

variable "warm_tier_days" {
  description = "Number of days to keep logs in warm tier (Standard-IA storage)"
  type        = number
  default     = 30
}

variable "cold_tier_days" {
  description = "Number of days to keep logs in cold tier (Glacier storage)"
  type        = number
  default     = 365
}

variable "athena_results_retention_days" {
  description = "Number of days to retain Athena query results"
  type        = number
  default     = 30
}

# Versioning Configuration
variable "enable_versioning" {
  description = "Enable versioning for S3 buckets"
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days after which noncurrent versions are deleted"
  type        = number
  default     = 30
}