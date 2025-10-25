variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "videos_table_name" {
  description = "Name of the videos DynamoDB table"
  type        = string
}

variable "videos_table_arn" {
  description = "ARN of the videos DynamoDB table"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}