variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}



variable "connections_table_name" {
  description = "DynamoDB connections table name"
  type        = string
}

variable "messages_table_name" {
  description = "DynamoDB messages table name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}