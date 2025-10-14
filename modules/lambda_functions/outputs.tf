# Outputs for Lambda Functions Module

# JWT Middleware Lambda
output "jwt_middleware_function_name" {
  description = "JWT middleware Lambda function name"
  value       = aws_lambda_function.jwt_middleware.function_name
}

output "jwt_middleware_function_arn" {
  description = "JWT middleware Lambda function ARN"
  value       = aws_lambda_function.jwt_middleware.arn
}

output "jwt_middleware_invoke_arn" {
  description = "JWT middleware Lambda function invoke ARN"
  value       = aws_lambda_function.jwt_middleware.invoke_arn
}

# JWT Refresh Lambda
output "jwt_refresh_function_name" {
  description = "JWT refresh Lambda function name"
  value       = aws_lambda_function.jwt_refresh.function_name
}

output "jwt_refresh_function_arn" {
  description = "JWT refresh Lambda function ARN"
  value       = aws_lambda_function.jwt_refresh.arn
}

output "jwt_refresh_invoke_arn" {
  description = "JWT refresh Lambda function invoke ARN"
  value       = aws_lambda_function.jwt_refresh.invoke_arn
}

# IAM Role
output "jwt_lambda_role_arn" {
  description = "JWT Lambda functions IAM role ARN"
  value       = aws_iam_role.lambda_jwt.arn
}

# Lambda Layer
output "common_dependencies_layer_arn" {
  description = "Common dependencies Lambda layer ARN"
  value       = aws_lambda_layer_version.common_dependencies.arn
}

# Configuration Summary
output "jwt_configuration_summary" {
  description = "Summary of JWT Lambda configuration"
  value = {
    jwt_middleware_function = aws_lambda_function.jwt_middleware.function_name
    jwt_refresh_function    = aws_lambda_function.jwt_refresh.function_name
    runtime                 = "python3.9"
    timeout                 = 30
    memory_size             = 256
    log_retention_days      = var.log_retention_days

    cognito_integration = {
      user_pool_id        = var.cognito_user_pool_id
      user_pool_client_id = var.cognito_user_pool_client_id
    }

    features = [
      "JWT token validation",
      "Token refresh handling",
      "User context extraction",
      "Role-based access control",
      "Automatic token refresh detection"
    ]
  }
}