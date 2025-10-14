# Lambda Module Outputs

# Lambda Function ARNs
output "lambda_function_arns" {
  description = "Map of Lambda function ARNs"
  value = {
    auth_handler       = aws_lambda_function.auth_handler.arn
    streaming_handler  = aws_lambda_function.streaming_handler.arn
    payment_handler    = aws_lambda_function.payment_handler.arn
    support_handler    = aws_lambda_function.support_handler.arn
    analytics_handler  = aws_lambda_function.analytics_handler.arn
    moderation_handler = aws_lambda_function.moderation_handler.arn
  }
}

# Lambda Function Names
output "lambda_function_names" {
  description = "Map of Lambda function names"
  value = {
    auth_handler       = aws_lambda_function.auth_handler.function_name
    streaming_handler  = aws_lambda_function.streaming_handler.function_name
    payment_handler    = aws_lambda_function.payment_handler.function_name
    support_handler    = aws_lambda_function.support_handler.function_name
    analytics_handler  = aws_lambda_function.analytics_handler.function_name
    moderation_handler = aws_lambda_function.moderation_handler.function_name
  }
}

# Lambda Function Invoke ARNs (for API Gateway integration)
output "lambda_function_invoke_arns" {
  description = "Map of Lambda function invoke ARNs for API Gateway"
  value = {
    auth_handler       = aws_lambda_function.auth_handler.invoke_arn
    streaming_handler  = aws_lambda_function.streaming_handler.invoke_arn
    payment_handler    = aws_lambda_function.payment_handler.invoke_arn
    support_handler    = aws_lambda_function.support_handler.invoke_arn
    analytics_handler  = aws_lambda_function.analytics_handler.invoke_arn
    moderation_handler = aws_lambda_function.moderation_handler.invoke_arn
  }
}

# Individual Function Outputs for API Gateway Integration
output "auth_handler_arn" {
  description = "Authentication handler Lambda function ARN"
  value       = aws_lambda_function.auth_handler.arn
}

output "auth_handler_invoke_arn" {
  description = "Authentication handler Lambda function invoke ARN"
  value       = aws_lambda_function.auth_handler.invoke_arn
}

output "streaming_handler_arn" {
  description = "Streaming handler Lambda function ARN"
  value       = aws_lambda_function.streaming_handler.arn
}

output "streaming_handler_invoke_arn" {
  description = "Streaming handler Lambda function invoke ARN"
  value       = aws_lambda_function.streaming_handler.invoke_arn
}

output "payment_handler_arn" {
  description = "Payment handler Lambda function ARN"
  value       = aws_lambda_function.payment_handler.arn
}

output "payment_handler_invoke_arn" {
  description = "Payment handler Lambda function invoke ARN"
  value       = aws_lambda_function.payment_handler.invoke_arn
}

output "support_handler_arn" {
  description = "Support handler Lambda function ARN"
  value       = aws_lambda_function.support_handler.arn
}

output "support_handler_invoke_arn" {
  description = "Support handler Lambda function invoke ARN"
  value       = aws_lambda_function.support_handler.invoke_arn
}

output "analytics_handler_arn" {
  description = "Analytics handler Lambda function ARN"
  value       = aws_lambda_function.analytics_handler.arn
}

output "analytics_handler_invoke_arn" {
  description = "Analytics handler Lambda function invoke ARN"
  value       = aws_lambda_function.analytics_handler.invoke_arn
}

output "moderation_handler_arn" {
  description = "Moderation handler Lambda function ARN"
  value       = aws_lambda_function.moderation_handler.arn
}

output "moderation_handler_invoke_arn" {
  description = "Moderation handler Lambda function invoke ARN"
  value       = aws_lambda_function.moderation_handler.invoke_arn
}

# Lambda Layer
output "shared_dependencies_layer_arn" {
  description = "Shared dependencies Lambda layer ARN"
  value       = aws_lambda_layer_version.shared_dependencies.arn
}

# IAM Role ARNs
output "lambda_role_arns" {
  description = "Map of Lambda IAM role ARNs"
  value = {
    auth_role       = aws_iam_role.lambda_auth_role.arn
    streaming_role  = aws_iam_role.lambda_streaming_role.arn
    payment_role    = aws_iam_role.lambda_payment_role.arn
    support_role    = aws_iam_role.lambda_support_role.arn
    analytics_role  = aws_iam_role.lambda_analytics_role.arn
    moderation_role = aws_iam_role.lambda_moderation_role.arn
  }
}

# CloudWatch Log Groups
output "lambda_log_group_names" {
  description = "Map of Lambda CloudWatch log group names"
  value = {
    auth_handler       = aws_cloudwatch_log_group.auth_handler.name
    streaming_handler  = aws_cloudwatch_log_group.streaming_handler.name
    payment_handler    = aws_cloudwatch_log_group.payment_handler.name
    support_handler    = aws_cloudwatch_log_group.support_handler.name
    analytics_handler  = aws_cloudwatch_log_group.analytics_handler.name
    moderation_handler = aws_cloudwatch_log_group.moderation_handler.name
  }
}

# Configuration Summary
output "lambda_configuration_summary" {
  description = "Summary of Lambda configuration"
  value = {
    total_functions    = 6
    runtime            = "python3.9"
    vpc_enabled        = true
    layer_enabled      = true
    log_retention_days = var.log_retention_days
    environment        = var.environment
    project_name       = var.project_name
  }
}