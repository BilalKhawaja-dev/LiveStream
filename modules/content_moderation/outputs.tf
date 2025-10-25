output "content_analyzer_function_name" {
  description = "Name of the content analyzer Lambda function"
  value       = aws_lambda_function.content_analyzer.function_name
}

output "content_analyzer_function_arn" {
  description = "ARN of the content analyzer Lambda function"
  value       = aws_lambda_function.content_analyzer.arn
}

output "moderation_api_function_name" {
  description = "Name of the moderation API Lambda function"
  value       = aws_lambda_function.moderation_api.function_name
}

output "moderation_api_function_arn" {
  description = "ARN of the moderation API Lambda function"
  value       = aws_lambda_function.moderation_api.arn
}

output "flagged_content_bucket_name" {
  description = "Name of the flagged content S3 bucket"
  value       = aws_s3_bucket.flagged_content.bucket
}

output "moderation_alerts_topic_arn" {
  description = "ARN of the moderation alerts SNS topic"
  value       = aws_sns_topic.moderation_alerts.arn
}