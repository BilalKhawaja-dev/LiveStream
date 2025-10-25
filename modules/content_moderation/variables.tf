variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "moderation_table_name" {
  description = "Name of the moderation DynamoDB table"
  type        = string
}

variable "moderation_table_arn" {
  description = "ARN of the moderation DynamoDB table"
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

variable "messages_table_name" {
  description = "Name of the messages DynamoDB table"
  type        = string
}

variable "messages_table_arn" {
  description = "ARN of the messages DynamoDB table"
  type        = string
}

variable "video_upload_bucket_arn" {
  description = "ARN of the video upload S3 bucket"
  type        = string
}

variable "processed_videos_bucket_arn" {
  description = "ARN of the processed videos S3 bucket"
  type        = string
}

variable "moderation_email" {
  description = "Email address for moderation notifications"
  type        = string
  default     = "admin@example.com"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}