# API Gateway for WebSocket chat
resource "aws_apigatewayv2_api" "chat" {
  name                       = "${var.project_name}-${var.environment}-chat"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  tags = merge(var.tags, {
    Service = "chat"
    Type    = "websocket-api"
  })
}

# WebSocket routes
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect.id}"
}

resource "aws_apigatewayv2_route" "message" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "message"
  target    = "integrations/${aws_apigatewayv2_integration.message.id}"
}

# IAM role for chat Lambda functions
resource "aws_iam_role" "chat_lambda_role" {
  name = "${var.project_name}-${var.environment}-chat-lambda-role"

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

  tags = merge(var.tags, {
    Service = "chat"
    Type    = "iam-role"
  })
}

# IAM policy for chat Lambda functions
resource "aws_iam_role_policy" "chat_lambda_policy" {
  name = "${var.project_name}-${var.environment}-chat-lambda-policy"
  role = aws_iam_role.chat_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/${var.connections_table_name}",
          "arn:aws:dynamodb:*:*:table/${var.messages_table_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:ManageConnections"
        ]
        Resource = "arn:aws:execute-api:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectSentiment",
          "comprehend:DetectPiiEntities"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda integrations
resource "aws_apigatewayv2_integration" "connect" {
  api_id           = aws_apigatewayv2_api.chat.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.chat_connect.invoke_arn
}

resource "aws_apigatewayv2_integration" "disconnect" {
  api_id           = aws_apigatewayv2_api.chat.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.chat_disconnect.invoke_arn
}

resource "aws_apigatewayv2_integration" "message" {
  api_id           = aws_apigatewayv2_api.chat.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.chat_message.invoke_arn
}

# Lambda function source code
data "archive_file" "chat_connect" {
  type        = "zip"
  output_path = "${path.module}/chat_connect.zip"
  source_file = "${path.module}/functions/chat_connect.py"
}

data "archive_file" "chat_disconnect" {
  type        = "zip"
  output_path = "${path.module}/chat_disconnect.zip"
  source_file = "${path.module}/functions/chat_disconnect.py"
}

data "archive_file" "chat_message" {
  type        = "zip"
  output_path = "${path.module}/chat_message.zip"
  source_file = "${path.module}/functions/chat_message.py"
}

# Lambda functions for chat
resource "aws_lambda_function" "chat_connect" {
  filename         = data.archive_file.chat_connect.output_path
  function_name    = "${var.project_name}-${var.environment}-chat-connect"
  role             = aws_iam_role.chat_lambda_role.arn
  handler          = "chat_connect.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  source_code_hash = data.archive_file.chat_connect.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = var.connections_table_name
    }
  }

  tags = merge(var.tags, {
    Service = "chat"
    Type    = "lambda-function"
  })
}

resource "aws_lambda_function" "chat_disconnect" {
  filename         = data.archive_file.chat_disconnect.output_path
  function_name    = "${var.project_name}-${var.environment}-chat-disconnect"
  role             = aws_iam_role.chat_lambda_role.arn
  handler          = "chat_disconnect.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  source_code_hash = data.archive_file.chat_disconnect.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = var.connections_table_name
    }
  }

  tags = merge(var.tags, {
    Service = "chat"
    Type    = "lambda-function"
  })
}

resource "aws_lambda_function" "chat_message" {
  filename         = data.archive_file.chat_message.output_path
  function_name    = "${var.project_name}-${var.environment}-chat-message"
  role             = aws_iam_role.chat_lambda_role.arn
  handler          = "chat_message.lambda_handler"
  runtime          = "python3.9"
  timeout          = 60
  source_code_hash = data.archive_file.chat_message.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = var.connections_table_name
      MESSAGES_TABLE    = var.messages_table_name
    }
  }

  tags = merge(var.tags, {
    Service = "chat"
    Type    = "lambda-function"
  })
}

# API Gateway deployment
resource "aws_apigatewayv2_deployment" "chat" {
  api_id = aws_apigatewayv2_api.chat.id

  depends_on = [
    aws_apigatewayv2_route.connect,
    aws_apigatewayv2_route.disconnect,
    aws_apigatewayv2_route.message
  ]
}

resource "aws_apigatewayv2_stage" "chat" {
  api_id        = aws_apigatewayv2_api.chat.id
  deployment_id = aws_apigatewayv2_deployment.chat.id
  name          = var.environment

  tags = merge(var.tags, {
    Service = "chat"
    Type    = "api-stage"
  })
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "chat_connect_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_connect.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chat.execution_arn}/*/*"
}

resource "aws_lambda_permission" "chat_disconnect_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_disconnect.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chat.execution_arn}/*/*"
}

resource "aws_lambda_permission" "chat_message_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_message.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chat.execution_arn}/*/*"
}

# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "chat_connect_logs" {
  name              = "/aws/lambda/${aws_lambda_function.chat_connect.function_name}"
  retention_in_days = 7

  tags = merge(var.tags, {
    Service = "chat"
    Type    = "log-group"
  })
}

resource "aws_cloudwatch_log_group" "chat_disconnect_logs" {
  name              = "/aws/lambda/${aws_lambda_function.chat_disconnect.function_name}"
  retention_in_days = 7

  tags = merge(var.tags, {
    Service = "chat"
    Type    = "log-group"
  })
}

resource "aws_cloudwatch_log_group" "chat_message_logs" {
  name              = "/aws/lambda/${aws_lambda_function.chat_message.function_name}"
  retention_in_days = 7

  tags = merge(var.tags, {
    Service = "chat"
    Type    = "log-group"
  })
}