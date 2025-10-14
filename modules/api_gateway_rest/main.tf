# REST API Gateway for backend services
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "REST API for streaming platform backend services"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # API Gateway policy for security
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      }
    ]
  })

  # Binary media types for file uploads
  binary_media_types = [
    "image/*",
    "video/*",
    "audio/*",
    "application/octet-stream"
  ]

  tags = var.tags
}

# Cognito User Pool Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name                   = "${var.project_name}-${var.environment}-cognito-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.main.id
  type                   = "COGNITO_USER_POOLS"
  provider_arns          = [var.cognito_user_pool_arn]
  identity_source        = "method.request.header.Authorization"
  authorizer_credentials = aws_iam_role.api_gateway_authorizer.arn
}

# Lambda JWT Authorizer
resource "aws_api_gateway_authorizer" "jwt_lambda" {
  count = var.jwt_authorizer_function_arn != "" ? 1 : 0

  name                   = "${var.project_name}-${var.environment}-jwt-lambda-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.main.id
  type                   = "TOKEN"
  authorizer_uri         = var.jwt_authorizer_function_invoke_arn
  authorizer_credentials = aws_iam_role.api_gateway_authorizer.arn
  identity_source        = "method.request.header.Authorization"

  # Cache settings for performance
  authorizer_result_ttl_in_seconds = var.jwt_authorizer_cache_ttl
}

# IAM role for API Gateway authorizer
resource "aws_iam_role" "api_gateway_authorizer" {
  name = "${var.project_name}-${var.environment}-api-gateway-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# API Gateway resources structure
locals {
  api_resources = {
    # Authentication endpoints
    auth = {
      path_part = "auth"
      parent_id = aws_api_gateway_rest_api.main.root_resource_id
      children = {
        login    = { path_part = "login" }
        logout   = { path_part = "logout" }
        refresh  = { path_part = "refresh" }
        register = { path_part = "register" }
      }
    }

    # User management endpoints
    users = {
      path_part = "users"
      parent_id = aws_api_gateway_rest_api.main.root_resource_id
      children = {
        profile      = { path_part = "profile" }
        subscription = { path_part = "subscription" }
        preferences  = { path_part = "preferences" }
      }
    }

    # Streaming endpoints
    streams = {
      path_part = "streams"
      parent_id = aws_api_gateway_rest_api.main.root_resource_id
      children = {
        live     = { path_part = "live" }
        schedule = { path_part = "schedule" }
        archive  = { path_part = "archive" }
        metrics  = { path_part = "metrics" }
      }
    }

    # Support system endpoints
    support = {
      path_part = "support"
      parent_id = aws_api_gateway_rest_api.main.root_resource_id
      children = {
        tickets = { path_part = "tickets" }
        chat    = { path_part = "chat" }
        ai      = { path_part = "ai" }
      }
    }

    # Analytics endpoints
    analytics = {
      path_part = "analytics"
      parent_id = aws_api_gateway_rest_api.main.root_resource_id
      children = {
        users   = { path_part = "users" }
        streams = { path_part = "streams" }
        revenue = { path_part = "revenue" }
        reports = { path_part = "reports" }
      }
    }

    # Payment endpoints
    payments = {
      path_part = "payments"
      parent_id = aws_api_gateway_rest_api.main.root_resource_id
      children = {
        stripe   = { path_part = "stripe" }
        webhooks = { path_part = "webhooks" }
        refunds  = { path_part = "refunds" }
      }
    }

    # Media services endpoints
    media = {
      path_part = "media"
      parent_id = aws_api_gateway_rest_api.main.root_resource_id
      children = {
        upload    = { path_part = "upload" }
        transcode = { path_part = "transcode" }
        cdn       = { path_part = "cdn" }
      }
    }
  }
}

# Create parent resources
resource "aws_api_gateway_resource" "parent" {
  for_each = local.api_resources

  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = each.value.parent_id
  path_part   = each.value.path_part
}

# Create child resources
resource "aws_api_gateway_resource" "child" {
  for_each = merge([
    for parent_key, parent_value in local.api_resources : {
      for child_key, child_value in parent_value.children :
      "${parent_key}_${child_key}" => {
        parent_resource_id = aws_api_gateway_resource.parent[parent_key].id
        path_part          = child_value.path_part
      }
    }
  ]...)

  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = each.value.parent_resource_id
  path_part   = each.value.path_part
}

# Request validators
resource "aws_api_gateway_request_validator" "body_validator" {
  name                        = "${var.project_name}-${var.environment}-body-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = false
}

resource "aws_api_gateway_request_validator" "params_validator" {
  name                        = "${var.project_name}-${var.environment}-params-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = false
  validate_request_parameters = true
}

resource "aws_api_gateway_request_validator" "full_validator" {
  name                        = "${var.project_name}-${var.environment}-full-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = true
}

# Gateway responses for better error handling
resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "UNAUTHORIZED"
  status_code   = "401"

  response_templates = {
    "application/json" = jsonencode({
      error   = "Unauthorized"
      message = "Authentication required"
    })
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_gateway_response" "access_denied" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "ACCESS_DENIED"
  status_code   = "403"

  response_templates = {
    "application/json" = jsonencode({
      error   = "Access Denied"
      message = "Insufficient permissions"
    })
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_gateway_response" "throttled" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "THROTTLED"
  status_code   = "429"

  response_templates = {
    "application/json" = jsonencode({
      error   = "Too Many Requests"
      message = "Rate limit exceeded"
    })
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# CORS configuration for all resources
locals {
  all_resources = merge(
    { for k, v in aws_api_gateway_resource.parent : k => v.id },
    { for k, v in aws_api_gateway_resource.child : k => v.id }
  )
}

resource "aws_api_gateway_method" "options" {
  for_each = local.all_resources

  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each = aws_api_gateway_method.options

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  for_each = aws_api_gateway_method.options

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each = aws_api_gateway_method.options

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,PATCH,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = var.cors_allow_origin
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [
    aws_api_gateway_method.options,
    aws_api_gateway_integration.options,
    aws_api_gateway_gateway_response.unauthorized,
    aws_api_gateway_gateway_response.access_denied,
    aws_api_gateway_gateway_response.throttled
  ]

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.main.body,
      aws_api_gateway_authorizer.cognito.id,
    ]))
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  # Enable logging
  access_log_destination_arn = aws_cloudwatch_log_group.api_gateway.arn
  access_log_format = jsonencode({
    requestId      = "$context.requestId"
    ip             = "$context.identity.sourceIp"
    caller         = "$context.identity.caller"
    user           = "$context.identity.user"
    requestTime    = "$context.requestTime"
    httpMethod     = "$context.httpMethod"
    resourcePath   = "$context.resourcePath"
    status         = "$context.status"
    protocol       = "$context.protocol"
    responseLength = "$context.responseLength"
    error          = "$context.error.message"
    errorType      = "$context.error.messageString"
  })

  # Enable X-Ray tracing
  xray_tracing_enabled = var.enable_xray_tracing

  # Method settings
  method_settings {
    method_path = "*/*"

    # Logging settings
    logging_level      = var.api_logging_level
    data_trace_enabled = var.environment != "prod"
    metrics_enabled    = true

    # Throttling settings
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit

    # Caching settings
    caching_enabled      = var.enable_caching
    cache_ttl_in_seconds = var.cache_ttl_seconds
    cache_key_parameters = []
  }

  tags = var.tags
}

# Usage Plans for rate limiting
resource "aws_api_gateway_usage_plan" "basic" {
  name        = "${var.project_name}-${var.environment}-basic-plan"
  description = "Basic usage plan for authenticated users"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = var.basic_plan_quota_limit
    period = "DAY"
  }

  throttle_settings {
    rate_limit  = var.basic_plan_rate_limit
    burst_limit = var.basic_plan_burst_limit
  }

  tags = var.tags
}

resource "aws_api_gateway_usage_plan" "premium" {
  name        = "${var.project_name}-${var.environment}-premium-plan"
  description = "Premium usage plan for creators and premium users"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = var.premium_plan_quota_limit
    period = "DAY"
  }

  throttle_settings {
    rate_limit  = var.premium_plan_rate_limit
    burst_limit = var.premium_plan_burst_limit
  }

  tags = var.tags
}

resource "aws_api_gateway_usage_plan" "admin" {
  name        = "${var.project_name}-${var.environment}-admin-plan"
  description = "Admin usage plan for administrative operations"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = var.admin_plan_quota_limit
    period = "DAY"
  }

  throttle_settings {
    rate_limit  = var.admin_plan_rate_limit
    burst_limit = var.admin_plan_burst_limit
  }

  tags = var.tags
}

# API Keys for usage plans
resource "aws_api_gateway_api_key" "basic" {
  count = var.create_api_keys ? 1 : 0

  name        = "${var.project_name}-${var.environment}-basic-key"
  description = "API key for basic usage plan"
  enabled     = true

  tags = var.tags
}

resource "aws_api_gateway_api_key" "premium" {
  count = var.create_api_keys ? 1 : 0

  name        = "${var.project_name}-${var.environment}-premium-key"
  description = "API key for premium usage plan"
  enabled     = true

  tags = var.tags
}

resource "aws_api_gateway_api_key" "admin" {
  count = var.create_api_keys ? 1 : 0

  name        = "${var.project_name}-${var.environment}-admin-key"
  description = "API key for admin usage plan"
  enabled     = true

  tags = var.tags
}

# Usage plan key associations
resource "aws_api_gateway_usage_plan_key" "basic" {
  count = var.create_api_keys ? 1 : 0

  key_id        = aws_api_gateway_api_key.basic[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.basic.id
}

resource "aws_api_gateway_usage_plan_key" "premium" {
  count = var.create_api_keys ? 1 : 0

  key_id        = aws_api_gateway_api_key.premium[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.premium.id
}

resource "aws_api_gateway_usage_plan_key" "admin" {
  count = var.create_api_keys ? 1 : 0

  key_id        = aws_api_gateway_api_key.admin[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.admin.id
}