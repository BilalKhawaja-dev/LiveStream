# Variables for ACM Certificate Module

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

# Domain Configuration
variable "domain_name" {
  description = "Primary domain name for the certificate (leave empty to skip certificate creation)"
  type        = string
  default     = ""
}

variable "subject_alternative_names" {
  description = "Additional domain names for the certificate"
  type        = list(string)
  default     = []
}

variable "enable_wildcard_certificate" {
  description = "Create a wildcard certificate for subdomains"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Enable IPv6 AAAA records"
  type        = bool
  default     = false
}

# ALB Integration
variable "alb_dns_name" {
  description = "ALB DNS name for Route53 alias record"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID for Route53 alias record"
  type        = string
  default     = ""
}

# Monitoring Configuration
variable "enable_certificate_monitoring" {
  description = "Enable certificate expiry monitoring"
  type        = bool
  default     = true
}

variable "certificate_expiry_threshold_days" {
  description = "Number of days before certificate expiry to trigger alarm"
  type        = number
  default     = 30
  validation {
    condition     = var.certificate_expiry_threshold_days >= 7 && var.certificate_expiry_threshold_days <= 90
    error_message = "Certificate expiry threshold must be between 7 and 90 days."
  }
}

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

variable "sns_topic_arns" {
  description = "SNS topic ARNs for certificate expiry notifications"
  type        = list(string)
  default     = []
}