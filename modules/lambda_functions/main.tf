# Lambda Functions Module for Streaming Platform Business Logic
# This module creates all the Lambda functions needed for the streaming platform

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Lambda Layer for common dependencies
resource "aws_lambda_layer_version" "common_dependencies" {
  filename    = "${path.module}/layers/common_dependencies.zip"
  layer_name  = "${var.project_name}-${var.environment}-common-dependencies"
  description = "Common dependencies for streaming platform Lambda functions"

  compatible_runtimes = ["python3.9", "python3.10"]

  depends_on = [data.archive_file.common_dependencies_layer]
}

# Create common dependencies layer
data "archive_file" "common_dependencies_layer" {
  type        = "zip"
  source_dir  = "${path.module}/layers/python"
  output_path = "${path.module}/layers/common_dependencies.zip"
}

# JWT Middleware Lambda for API Gateway Authorization
resource "aws_lambda_function" "jwt_middleware" {
  filename      = "${path.module}/functions/jwt_middleware.zip"
  function_name = "${var.project_name}-${var.environment}-jwt-middleware"
  role          = aws_iam_role.lambda_jwt.arn
  handler       = "jwt_middleware.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30
  memory_size   = 256

  layers = [aws_lambda_layer_version.common_dependencies.arn]

  environment {
    variables = {
      COGNITO_USER_POOL_ID        = var.cognito_user_pool_id
      COGNITO_USER_POOL_CLIENT_ID = var.cognito_user_pool_client_id
      AWS_REGION                  = data.aws_region.current.name
      ENVIRONMENT                 = var.environment
      LOG_LEVEL                   = var.lambda_log_level
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_jwt_basic,
    aws_cloudwatch_log_group.jwt_middleware,
    data.archive_file.jwt_middleware
  ]

  tags = var.tags
}

# JWT Token Refresh Lambda
resource "aws_lambda_function" "jwt_refresh" {
  filename      = "${path.module}/functions/jwt_middleware.zip"
  function_name = "${var.project_name}-${var.environment}-jwt-refresh"
  role          = aws_iam_role.lambda_jwt.arn
  handler       = "jwt_middleware.refresh_token_handler"
  runtime       = "python3.9"
  timeout       = 30
  memory_size   = 256

  layers = [aws_lambda_layer_version.common_dependencies.arn]

  environment {
    variables = {
      COGNITO_USER_POOL_ID        = var.cognito_user_pool_id
      COGNITO_USER_POOL_CLIENT_ID = var.cognito_user_pool_client_id
      AWS_REGION                  = data.aws_region.current.name
      ENVIRONMENT                 = var.environment
      LOG_LEVEL                   = var.lambda_log_level
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_jwt_basic,
    aws_cloudwatch_log_group.jwt_refresh,
    data.archive_file.jwt_middleware
  ]

  tags = var.tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "jwt_middleware" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-jwt-middleware"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "jwt_refresh" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-jwt-refresh"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Archive files for Lambda functions
data "archive_file" "jwt_middleware" {
  type        = "zip"
  source_file = "${path.module}/functions/jwt_middleware.py"
  output_path = "${path.module}/functions/jwt_middleware.zip"
}

# IAM Role for JWT Lambda functions
resource "aws_iam_role" "lambda_jwt" {
  name = "${var.project_name}-${var.environment}-lambda-jwt-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_jwt_basic" {
  role       = aws_iam_role.lambda_jwt.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_jwt_cognito" {
  name = "${var.project_name}-${var.environment}-lambda-jwt-cognito-policy"
  role = aws_iam_role.lambda_jwt.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminInitiateAuth",
          "cognito-idp:AdminGetUser",
          "cognito-idp:GetUser"
        ]
        Resource = "arn:aws:cognito-idp:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:userpool/${var.cognito_user_pool_id}"
      }
    ]
  })
}

# Lambda Permission for API Gateway to invoke JWT middleware
resource "aws_lambda_permission" "jwt_middleware_api_gateway" {
  count = var.api_gateway_execution_arn != "" ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jwt_middleware.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

# Lambda Permission for API Gateway to invoke JWT refresh
resource "aws_lambda_permission" "jwt_refresh_api_gateway" {
  count = var.api_gateway_execution_arn != "" ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jwt_refresh.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}