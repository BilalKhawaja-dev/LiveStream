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

# Lambda JWT Authorizer (disabled for now - using Cognito instead)
# resource "aws_api_gateway_authorizer" "jwt_lambda" {
#   count = var.jwt_authorizer_function_arn != "" ? 1 : 0
#
#   name                   = "${var.project_name}-${var.environment}-jwt-lambda-authorizer"
#   rest_api_id            = aws_api_gateway_rest_api.main.id
#   type                   = "TOKEN"
#   authorizer_uri         = var.jwt_authorizer_function_invoke_arn
#   authorizer_credentials = aws_iam_role.api_gateway_authorizer.arn
#   identity_source        = "method.request.header.Authorization"
#
#   # Cache settings for performance
#   authorizer_result_ttl_in_seconds = var.jwt_authorizer_cache_ttl
# }

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

    # Payment endpoints - DISABLED FOR DEVELOPMENT
    # Payment processing removed to simplify development workflow

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
  # Static list of all resource keys for CORS
  all_resource_keys = concat(
    keys(local.api_resources),
    flatten([
      for parent_key, parent_value in local.api_resources : [
        for child_key, child_value in parent_value.children :
        "${parent_key}_${child_key}"
      ]
    ])
  )
}

resource "aws_api_gateway_method" "options" {
  for_each = toset(local.all_resource_keys)

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = contains(keys(local.api_resources), each.key) ? aws_api_gateway_resource.parent[each.key].id : aws_api_gateway_resource.child[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each = toset(local.all_resource_keys)

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_method.options[each.key].resource_id
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  for_each = toset(local.all_resource_keys)

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_method.options[each.key].resource_id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each = toset(local.all_resource_keys)

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_method.options[each.key].resource_id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,PATCH,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = var.cors_allow_origin
  }

  depends_on = [
    aws_api_gateway_integration.options,
    aws_api_gateway_method_response.options
  ]
}

# CloudWatch Logs role for API Gateway (required for logging)
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-${var.environment}-api-gateway-cloudwatch-role"

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

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Set the CloudWatch Logs role for API Gateway account settings
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  # Remove KMS key for now to avoid permission issues
  # kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [
    # CORS configuration
    aws_api_gateway_method.options,
    aws_api_gateway_integration.options,
    aws_api_gateway_method_response.options,
    aws_api_gateway_integration_response.options,
    
    # Gateway responses
    aws_api_gateway_gateway_response.unauthorized,
    aws_api_gateway_gateway_response.access_denied,
    aws_api_gateway_gateway_response.throttled,
    
    # Parent resource methods
    aws_api_gateway_method.auth,
    aws_api_gateway_integration.auth,
    aws_api_gateway_method_response.auth,
    aws_api_gateway_method.users,
    aws_api_gateway_integration.users,
    aws_api_gateway_method_response.users,
    aws_api_gateway_method.support,
    aws_api_gateway_integration.support,
    aws_api_gateway_method_response.support,
    aws_api_gateway_method.analytics,
    aws_api_gateway_integration.analytics,
    aws_api_gateway_method_response.analytics,
    aws_api_gateway_method.media,
    aws_api_gateway_integration.media,
    aws_api_gateway_method_response.media,
    
    # Auth endpoints
    aws_api_gateway_method.auth_login,
    aws_api_gateway_integration.auth_login,
    aws_api_gateway_method_response.auth_login,
    aws_api_gateway_method.auth_register,
    aws_api_gateway_integration.auth_register,
    aws_api_gateway_method_response.auth_register,
    aws_api_gateway_method.auth_refresh,
    aws_api_gateway_integration.auth_refresh,
    aws_api_gateway_method_response.auth_refresh,
    aws_api_gateway_method.auth_logout,
    aws_api_gateway_integration.auth_logout,
    aws_api_gateway_method_response.auth_logout,
    
    # User endpoints
    aws_api_gateway_method.users_profile,
    aws_api_gateway_integration.users_profile,
    aws_api_gateway_method_response.users_profile,
    aws_api_gateway_method.users_subscription,
    aws_api_gateway_integration.users_subscription,
    aws_api_gateway_method_response.users_subscription,
    aws_api_gateway_method.users_preferences,
    aws_api_gateway_integration.users_preferences,
    aws_api_gateway_method_response.users_preferences,
    
    # Stream endpoints
    aws_api_gateway_method.streams_list,
    aws_api_gateway_integration.streams_list,
    aws_api_gateway_method_response.streams_list,
    aws_api_gateway_method.streams_create,
    aws_api_gateway_integration.streams_create,
    aws_api_gateway_method_response.streams_create,
    aws_api_gateway_method.streams_live,
    aws_api_gateway_integration.streams_live,
    aws_api_gateway_method_response.streams_live,
    aws_api_gateway_method.streams_schedule,
    aws_api_gateway_integration.streams_schedule,
    aws_api_gateway_method_response.streams_schedule,
    aws_api_gateway_method.streams_archive,
    aws_api_gateway_integration.streams_archive,
    aws_api_gateway_method_response.streams_archive,
    aws_api_gateway_method.streams_metrics,
    aws_api_gateway_integration.streams_metrics,
    aws_api_gateway_method_response.streams_metrics,
    
    # Support endpoints
    aws_api_gateway_method.support_tickets,
    aws_api_gateway_integration.support_tickets,
    aws_api_gateway_method_response.support_tickets,
    aws_api_gateway_method.support_chat,
    aws_api_gateway_integration.support_chat,
    aws_api_gateway_method_response.support_chat,
    aws_api_gateway_method.support_ai,
    aws_api_gateway_integration.support_ai,
    aws_api_gateway_method_response.support_ai,
    
    # Analytics endpoints
    aws_api_gateway_method.analytics_users,
    aws_api_gateway_integration.analytics_users,
    aws_api_gateway_method_response.analytics_users,
    aws_api_gateway_method.analytics_streams,
    aws_api_gateway_integration.analytics_streams,
    aws_api_gateway_method_response.analytics_streams,
    aws_api_gateway_method.analytics_revenue,
    aws_api_gateway_integration.analytics_revenue,
    aws_api_gateway_method_response.analytics_revenue,
    aws_api_gateway_method.analytics_reports,
    aws_api_gateway_integration.analytics_reports,
    aws_api_gateway_method_response.analytics_reports,
    
    # Media endpoints
    aws_api_gateway_method.media_upload,
    aws_api_gateway_integration.media_upload,
    aws_api_gateway_method_response.media_upload,
    aws_api_gateway_method.media_transcode,
    aws_api_gateway_integration.media_transcode,
    aws_api_gateway_method_response.media_transcode,
    aws_api_gateway_method.media_cdn,
    aws_api_gateway_integration.media_cdn,
    aws_api_gateway_method_response.media_cdn,
    
    # Frontend proxy methods and integrations
    aws_api_gateway_method.frontend_proxy,
    aws_api_gateway_integration.frontend_proxy,
    aws_api_gateway_method.frontend_root,
    aws_api_gateway_integration.frontend_root,
    
    # Lambda permissions
    aws_lambda_permission.auth_handler,
    aws_lambda_permission.streaming_handler,
    aws_lambda_permission.support_handler,
    aws_lambda_permission.analytics_handler,
    aws_lambda_permission.moderation_handler
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

  # Enable X-Ray tracing
  xray_tracing_enabled = var.enable_xray_tracing

  # Ensure CloudWatch Logs role is set before creating stage
  depends_on = [aws_api_gateway_account.main]

  # Access logging configuration
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
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
} # Lambd


# Lambda Integration Methods and Integrations
# Authentication endpoints
resource "aws_api_gateway_method" "auth_login" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["auth_login"].id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.body_validator.id
}

resource "aws_api_gateway_integration" "auth_login" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["auth_login"].id
  http_method = aws_api_gateway_method.auth_login.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["auth_handler"]
}

resource "aws_api_gateway_method" "auth_register" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["auth_register"].id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.body_validator.id
}

resource "aws_api_gateway_integration" "auth_register" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["auth_register"].id
  http_method = aws_api_gateway_method.auth_register.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["auth_handler"]
}

resource "aws_api_gateway_method" "auth_refresh" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["auth_refresh"].id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.body_validator.id
}

resource "aws_api_gateway_integration" "auth_refresh" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["auth_refresh"].id
  http_method = aws_api_gateway_method.auth_refresh.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["auth_handler"]
}

# Streaming endpoints (protected)
resource "aws_api_gateway_method" "streams_list" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.parent["streams"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "streams_list" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["streams"].id
  http_method = aws_api_gateway_method.streams_list.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["streaming_handler"]
}

resource "aws_api_gateway_method" "streams_create" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.parent["streams"].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_validator_id = aws_api_gateway_request_validator.body_validator.id
}

resource "aws_api_gateway_integration" "streams_create" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["streams"].id
  http_method = aws_api_gateway_method.streams_create.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["streaming_handler"]
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "auth_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arns["auth_handler"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "streaming_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arns["streaming_handler"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Method responses for Lambda integrations
resource "aws_api_gateway_method_response" "auth_login" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["auth_login"].id
  http_method = aws_api_gateway_method.auth_login.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "auth_register" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["auth_register"].id
  http_method = aws_api_gateway_method.auth_register.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "auth_refresh" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["auth_refresh"].id
  http_method = aws_api_gateway_method.auth_refresh.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "streams_list" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["streams"].id
  http_method = aws_api_gateway_method.streams_list.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "streams_create" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["streams"].id
  http_method = aws_api_gateway_method.streams_create.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Additional Lambda integrations for missing endpoints

# Auth logout endpoint
resource "aws_api_gateway_method" "auth_logout" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["auth_logout"].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "auth_logout" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["auth_logout"].id
  http_method = aws_api_gateway_method.auth_logout.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["auth_handler"]
}

resource "aws_api_gateway_method_response" "auth_logout" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["auth_logout"].id
  http_method = aws_api_gateway_method.auth_logout.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Users endpoints
resource "aws_api_gateway_method" "users_profile" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["users_profile"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "users_profile" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["users_profile"].id
  http_method = aws_api_gateway_method.users_profile.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["auth_handler"]
}

resource "aws_api_gateway_method_response" "users_profile" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["users_profile"].id
  http_method = aws_api_gateway_method.users_profile.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "users_subscription" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["users_subscription"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "users_subscription" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["users_subscription"].id
  http_method = aws_api_gateway_method.users_subscription.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["auth_handler"]
}

resource "aws_api_gateway_method_response" "users_subscription" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["users_subscription"].id
  http_method = aws_api_gateway_method.users_subscription.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "users_preferences" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["users_preferences"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "users_preferences" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["users_preferences"].id
  http_method = aws_api_gateway_method.users_preferences.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["auth_handler"]
}

resource "aws_api_gateway_method_response" "users_preferences" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["users_preferences"].id
  http_method = aws_api_gateway_method.users_preferences.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Streaming child endpoints
resource "aws_api_gateway_method" "streams_live" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["streams_live"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "streams_live" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["streams_live"].id
  http_method = aws_api_gateway_method.streams_live.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["streaming_handler"]
}

resource "aws_api_gateway_method_response" "streams_live" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["streams_live"].id
  http_method = aws_api_gateway_method.streams_live.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "streams_schedule" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["streams_schedule"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "streams_schedule" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["streams_schedule"].id
  http_method = aws_api_gateway_method.streams_schedule.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["streaming_handler"]
}

resource "aws_api_gateway_method_response" "streams_schedule" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["streams_schedule"].id
  http_method = aws_api_gateway_method.streams_schedule.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "streams_archive" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["streams_archive"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "streams_archive" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["streams_archive"].id
  http_method = aws_api_gateway_method.streams_archive.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["streaming_handler"]
}

resource "aws_api_gateway_method_response" "streams_archive" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["streams_archive"].id
  http_method = aws_api_gateway_method.streams_archive.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "streams_metrics" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["streams_metrics"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "streams_metrics" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["streams_metrics"].id
  http_method = aws_api_gateway_method.streams_metrics.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["analytics_handler"]
}

resource "aws_api_gateway_method_response" "streams_metrics" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["streams_metrics"].id
  http_method = aws_api_gateway_method.streams_metrics.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Support endpoints
resource "aws_api_gateway_method" "support_tickets" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["support_tickets"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "support_tickets" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["support_tickets"].id
  http_method = aws_api_gateway_method.support_tickets.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["support_handler"]
}

resource "aws_api_gateway_method_response" "support_tickets" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["support_tickets"].id
  http_method = aws_api_gateway_method.support_tickets.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "support_chat" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["support_chat"].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "support_chat" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["support_chat"].id
  http_method = aws_api_gateway_method.support_chat.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["support_handler"]
}

resource "aws_api_gateway_method_response" "support_chat" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["support_chat"].id
  http_method = aws_api_gateway_method.support_chat.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "support_ai" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["support_ai"].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "support_ai" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["support_ai"].id
  http_method = aws_api_gateway_method.support_ai.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["support_handler"]
}

resource "aws_api_gateway_method_response" "support_ai" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["support_ai"].id
  http_method = aws_api_gateway_method.support_ai.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Analytics endpoints
resource "aws_api_gateway_method" "analytics_users" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["analytics_users"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "analytics_users" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["analytics_users"].id
  http_method = aws_api_gateway_method.analytics_users.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["analytics_handler"]
}

resource "aws_api_gateway_method_response" "analytics_users" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["analytics_users"].id
  http_method = aws_api_gateway_method.analytics_users.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "analytics_streams" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["analytics_streams"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "analytics_streams" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["analytics_streams"].id
  http_method = aws_api_gateway_method.analytics_streams.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["analytics_handler"]
}

resource "aws_api_gateway_method_response" "analytics_streams" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["analytics_streams"].id
  http_method = aws_api_gateway_method.analytics_streams.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "analytics_revenue" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["analytics_revenue"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "analytics_revenue" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["analytics_revenue"].id
  http_method = aws_api_gateway_method.analytics_revenue.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["analytics_handler"]
}

resource "aws_api_gateway_method_response" "analytics_revenue" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["analytics_revenue"].id
  http_method = aws_api_gateway_method.analytics_revenue.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "analytics_reports" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["analytics_reports"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "analytics_reports" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["analytics_reports"].id
  http_method = aws_api_gateway_method.analytics_reports.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["analytics_handler"]
}

resource "aws_api_gateway_method_response" "analytics_reports" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["analytics_reports"].id
  http_method = aws_api_gateway_method.analytics_reports.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Media endpoints
resource "aws_api_gateway_method" "media_upload" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["media_upload"].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "media_upload" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["media_upload"].id
  http_method = aws_api_gateway_method.media_upload.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["streaming_handler"]
}

resource "aws_api_gateway_method_response" "media_upload" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["media_upload"].id
  http_method = aws_api_gateway_method.media_upload.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "media_transcode" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["media_transcode"].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "media_transcode" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["media_transcode"].id
  http_method = aws_api_gateway_method.media_transcode.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["streaming_handler"]
}

resource "aws_api_gateway_method_response" "media_transcode" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["media_transcode"].id
  http_method = aws_api_gateway_method.media_transcode.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "media_cdn" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["media_cdn"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "media_cdn" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["media_cdn"].id
  http_method = aws_api_gateway_method.media_cdn.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["streaming_handler"]
}

resource "aws_api_gateway_method_response" "media_cdn" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["media_cdn"].id
  http_method = aws_api_gateway_method.media_cdn.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Additional Lambda permissions for all handlers
resource "aws_lambda_permission" "support_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arns["support_handler"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "analytics_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arns["analytics_handler"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "moderation_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arns["moderation_handler"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Parent resource methods and integrations

# Auth parent resource
resource "aws_api_gateway_method" "auth" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.parent["auth"].id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["auth"].id
  http_method = aws_api_gateway_method.auth.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["auth_handler"]
}

resource "aws_api_gateway_method_response" "auth" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["auth"].id
  http_method = aws_api_gateway_method.auth.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Users parent resource
resource "aws_api_gateway_method" "users" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.parent["users"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "users" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["users"].id
  http_method = aws_api_gateway_method.users.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["auth_handler"]
}

resource "aws_api_gateway_method_response" "users" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["users"].id
  http_method = aws_api_gateway_method.users.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Support parent resource
resource "aws_api_gateway_method" "support" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.parent["support"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "support" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["support"].id
  http_method = aws_api_gateway_method.support.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["support_handler"]
}

resource "aws_api_gateway_method_response" "support" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["support"].id
  http_method = aws_api_gateway_method.support.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Analytics parent resource
resource "aws_api_gateway_method" "analytics" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.parent["analytics"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "analytics" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["analytics"].id
  http_method = aws_api_gateway_method.analytics.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["analytics_handler"]
}

resource "aws_api_gateway_method_response" "analytics" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["analytics"].id
  http_method = aws_api_gateway_method.analytics.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Media parent resource
resource "aws_api_gateway_method" "media" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.parent["media"].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "media" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["media"].id
  http_method = aws_api_gateway_method.media.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["streaming_handler"]
}

resource "aws_api_gateway_method_response" "media" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.parent["media"].id
  http_method = aws_api_gateway_method.media.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# JWT middleware permission (disabled for now)
# resource "aws_lambda_permission" "jwt_middleware" {
#   count = var.jwt_authorizer_function_arn != "" ? 1 : 0
#
#   statement_id  = "AllowExecutionFromAPIGateway"
#   action        = "lambda:InvokeFunction"
#   function_name = var.jwt_authorizer_function_arn
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
# } # Met
# Method settings for API Gateway stage
resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
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
  }
} # 
# Frontend proxy integration through API Gateway for SSL termination
# This allows frontend apps to be accessed via HTTPS through API Gateway

# Frontend proxy resource
resource "aws_api_gateway_resource" "frontend_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "{proxy+}"
}

# Frontend proxy method
resource "aws_api_gateway_method" "frontend_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.frontend_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Frontend proxy integration to ALB
resource "aws_api_gateway_integration" "frontend_proxy" {
  count = var.alb_dns_name != "" ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.frontend_proxy.id
  http_method = aws_api_gateway_method.frontend_proxy.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${var.alb_dns_name}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# Root method for frontend
resource "aws_api_gateway_method" "frontend_root" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_rest_api.main.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

# Root integration to ALB
resource "aws_api_gateway_integration" "frontend_root" {
  count = var.alb_dns_name != "" ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_rest_api.main.root_resource_id
  http_method = aws_api_gateway_method.frontend_root.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${var.alb_dns_name}/"
}