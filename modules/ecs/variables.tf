# Variables for ECS Module

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

# Network Configuration
variable "vpc_id" {
  description = "VPC ID where ECS cluster will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS services"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the Application Load Balancer"
  type        = string
}

# ECS Configuration
variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the cluster"
  type        = bool
  default     = true
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for debugging containers"
  type        = bool
  default     = false
}

# Capacity Provider Configuration
variable "fargate_base_capacity" {
  description = "Base capacity for Fargate capacity provider"
  type        = number
  default     = 1
}

variable "fargate_weight" {
  description = "Weight for Fargate capacity provider"
  type        = number
  default     = 1
}

variable "fargate_spot_base_capacity" {
  description = "Base capacity for Fargate Spot capacity provider"
  type        = number
  default     = 0
}

variable "fargate_spot_weight" {
  description = "Weight for Fargate Spot capacity provider"
  type        = number
  default     = 4
}

# Auto Scaling Configuration
variable "min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
  default     = 70
  validation {
    condition     = var.cpu_target_value > 0 && var.cpu_target_value <= 100
    error_message = "CPU target value must be between 1 and 100."
  }
}

variable "memory_target_value" {
  description = "Target memory utilization percentage for auto scaling"
  type        = number
  default     = 80
  validation {
    condition     = var.memory_target_value > 0 && var.memory_target_value <= 100
    error_message = "Memory target value must be between 1 and 100."
  }
}

variable "scale_in_cooldown" {
  description = "Cooldown period in seconds for scale in operations"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period in seconds for scale out operations"
  type        = number
  default     = 60
}

# Container Configuration
variable "ecr_repository_url" {
  description = "ECR repository URL for container images"
  type        = string
}

variable "image_tag" {
  description = "Container image tag to deploy"
  type        = string
  default     = "latest"
}

# Application Configuration
variable "api_base_url" {
  description = "Base URL for API Gateway"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

variable "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  type        = string
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

# Cost Optimization
variable "enable_spot_instances" {
  description = "Enable Fargate Spot instances for cost optimization"
  type        = bool
  default     = true
}

variable "scheduled_scaling_enabled" {
  description = "Enable scheduled scaling for predictable workloads"
  type        = bool
  default     = false
}

variable "scheduled_scaling_rules" {
  description = "List of scheduled scaling rules"
  type = list(object({
    name         = string
    schedule     = string
    min_capacity = number
    max_capacity = number
    timezone     = string
  }))
  default = []
}

# ALB Integration
variable "target_group_arns" {
  description = "Map of target group ARNs from ALB module"
  type        = map(string)
  default     = {}
}

# Monitoring Configuration
variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = ""
}