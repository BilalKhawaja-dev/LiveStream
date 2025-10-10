# ALB Module Variables
# Requirements: 7.3, 8.1, 8.6

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
}

variable "frontend_applications" {
  description = "Map of frontend applications with their configurations"
  type = map(object({
    port              = number
    priority          = number
    health_check_path = string
  }))
  default = {
    viewer = {
      port              = 80
      priority          = 10
      health_check_path = "/health"
    }
    creator = {
      port              = 80
      priority          = 20
      health_check_path = "/health"
    }
    admin = {
      port              = 80
      priority          = 30
      health_check_path = "/health"
    }
    support = {
      port              = 80
      priority          = 40
      health_check_path = "/health"
    }
    analytics = {
      port              = 80
      priority          = 50
      health_check_path = "/health"
    }
    dev = {
      port              = 80
      priority          = 60
      health_check_path = "/health"
    }
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ALB Configuration
variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle"
  type        = number
  default     = 60
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# Access Logs
variable "enable_access_logs" {
  description = "Enable access logs for the ALB"
  type        = bool
  default     = true
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  type        = string
  default     = null
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for ALB"
  type        = bool
  default     = false
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

# Health Check Configuration
variable "health_check_port" {
  description = "Port for health checks"
  type        = number
  default     = 80
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 3
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

# Target Group Configuration
variable "enable_stickiness" {
  description = "Enable session stickiness"
  type        = bool
  default     = false
}

variable "stickiness_duration" {
  description = "Stickiness duration in seconds"
  type        = number
  default     = 86400
}

variable "deregistration_delay" {
  description = "Time to wait before deregistering targets"
  type        = number
  default     = 300
}

variable "slow_start_duration" {
  description = "Slow start duration in seconds"
  type        = number
  default     = 0
}

variable "load_balancing_algorithm" {
  description = "Load balancing algorithm"
  type        = string
  default     = "round_robin"
  validation {
    condition     = contains(["round_robin", "least_outstanding_requests"], var.load_balancing_algorithm)
    error_message = "Load balancing algorithm must be either 'round_robin' or 'least_outstanding_requests'."
  }
}

# Monitoring
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for ALB"
  type        = bool
  default     = true
}

variable "sns_topic_arns" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "response_time_threshold" {
  description = "Response time threshold in seconds for alarms"
  type        = number
  default     = 5
}

variable "unhealthy_host_threshold" {
  description = "Unhealthy host count threshold for alarms"
  type        = number
  default     = 1
}

variable "http_5xx_threshold" {
  description = "HTTP 5XX error count threshold for alarms"
  type        = number
  default     = 10
}

# Security
variable "waf_web_acl_arn" {
  description = "ARN of WAF Web ACL to associate with ALB"
  type        = string
  default     = null
}