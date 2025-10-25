variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aurora_cluster_arn" {
  description = "ARN of the Aurora cluster"
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN of the Aurora cluster secret"
  type        = string
}

variable "alarm_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}