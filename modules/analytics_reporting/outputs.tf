output "analytics_bucket_name" {
  description = "Name of the analytics data S3 bucket"
  value       = aws_s3_bucket.analytics_data.bucket
}

output "analytics_bucket_arn" {
  description = "ARN of the analytics data S3 bucket"
  value       = aws_s3_bucket.analytics_data.arn
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.analytics_workgroup.name
}

output "athena_database_name" {
  description = "Name of the Athena database"
  value       = aws_athena_database.analytics_database.name
}

output "analytics_processor_function_name" {
  description = "Name of the analytics processor Lambda function"
  value       = aws_lambda_function.analytics_processor.function_name
}

output "analytics_processor_function_arn" {
  description = "ARN of the analytics processor Lambda function"
  value       = aws_lambda_function.analytics_processor.arn
}

output "report_generator_function_name" {
  description = "Name of the report generator Lambda function"
  value       = aws_lambda_function.report_generator.function_name
}

output "analytics_api_function_name" {
  description = "Name of the analytics API Lambda function"
  value       = aws_lambda_function.analytics_api.function_name
}

output "analytics_api_function_arn" {
  description = "ARN of the analytics API Lambda function"
  value       = aws_lambda_function.analytics_api.arn
}