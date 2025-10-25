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
  
  # Enhanced JWT token validation
  authorizer_result_ttl_in_seconds = var.jwt_authorizer_cache_ttl
}

# Lambda JWT Authorizer for enhanced token validation
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
  
  # Enhanced validation settings
  identity_validation_expression = "^Bearer [-0-9A-Za-z\\.]+$"
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

# Enhanced request validators with comprehensive validation
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

# Enhanced request validator for strict validation
resource "aws_api_gateway_request_validator" "strict_validator" {
  name                        = "${var.project_name}-${var.environment}-strict-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = var.enable_request_validation
  validate_request_parameters = var.enable_request_validation
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

  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = contains(keys(local.api_resources), each.key) ? aws_api_gateway_resource.parent[each.key].id : aws_api_gateway_resource.child[each.key].id
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
    aws_api_gateway_method.support_tickets_post,
    aws_api_gateway_integration.support_tickets_post,
    aws_api_gateway_method_response.support_tickets_post,
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

# Enhanced Usage Plans for comprehensive rate limiting
resource "aws_api_gateway_usage_plan" "basic" {
  name        = "${var.project_name}-${var.environment}-basic-plan"
  description = "Basic usage plan for authenticated users with enhanced rate limiting"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
    
    # Per-method throttling for sensitive endpoints
    throttle {
      path        = "/auth/login"
      rate_limit  = var.basic_plan_rate_limit * 0.1  # 10% of total for login
      burst_limit = var.basic_plan_burst_limit * 0.1
    }
    
    throttle {
      path        = "/auth/register"
      rate_limit  = var.basic_plan_rate_limit * 0.05  # 5% of total for registration
      burst_limit = var.basic_plan_burst_limit * 0.05
    }
    
    throttle {
      path        = "/support/tickets"
      rate_limit  = var.basic_plan_rate_limit * 0.2  # 20% for support tickets
      burst_limit = var.basic_plan_burst_limit * 0.2
    }
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
  description = "Premium usage plan for creators and premium users with enhanced limits"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
    
    # Enhanced throttling for premium users
    throttle {
      path        = "/streams/*"
      rate_limit  = var.premium_plan_rate_limit * 0.4  # 40% for streaming operations
      burst_limit = var.premium_plan_burst_limit * 0.4
    }
    
    throttle {
      path        = "/analytics/*"
      rate_limit  = var.premium_plan_rate_limit * 0.3  # 30% for analytics
      burst_limit = var.premium_plan_burst_limit * 0.3
    }
    
    throttle {
      path        = "/media/*"
      rate_limit  = var.premium_plan_rate_limit * 0.2  # 20% for media operations
      burst_limit = var.premium_plan_burst_limit * 0.2
    }
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

# Support tickets POST method for creating tickets
resource "aws_api_gateway_method" "support_tickets_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.child["support_tickets"].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_validator_id = aws_api_gateway_request_validator.body_validator.id
}

resource "aws_api_gateway_integration" "support_tickets_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["support_tickets"].id
  http_method = aws_api_gateway_method.support_tickets_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arns["support_handler"]
}

resource "aws_api_gateway_method_response" "support_tickets_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.child["support_tickets"].id
  http_method = aws_api_gateway_method.support_tickets_post.http_method
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

# JWT middleware permission for enhanced token validation
resource "aws_lambda_permission" "jwt_middleware" {
  count = var.jwt_authorizer_function_arn != "" ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.jwt_authorizer_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Enhanced IAM role for API Gateway with additional permissions
resource "aws_iam_role_policy" "api_gateway_enhanced" {
  name = "${var.project_name}-${var.environment}-api-gateway-enhanced-policy"
  role = aws_iam_role.api_gateway_authorizer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "cognito-idp:GetUser",
          "cognito-idp:AdminGetUser",
          "cognito-idp:ListUsers"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
} # Met
# Enhanced method settings for API Gateway stage
resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    # Enhanced logging settings
    logging_level      = var.api_logging_level
    data_trace_enabled = var.environment != "prod"
    metrics_enabled    = true

    # Enhanced throttling settings
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit

    # Enhanced caching settings
    caching_enabled                = var.enable_caching
    cache_ttl_in_seconds          = var.cache_ttl_seconds
    cache_data_encrypted          = var.enable_api_cache_encryption
    cache_key_parameters          = ["method.request.header.Authorization"]
    require_authorization_for_cache_control = true
    unauthorized_cache_control_header_strategy = "SUCCEED_WITH_RESPONSE_HEADER"
  }
}

# CloudWatch Alarms for API Gateway monitoring
resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  count = var.alarm_topic_arn != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.api_4xx_error_threshold
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = [var.alarm_topic_arn]

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.main.name
    Stage     = aws_api_gateway_stage.main.stage_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  count = var.alarm_topic_arn != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.api_5xx_error_threshold
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  alarm_actions       = [var.alarm_topic_arn]

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.main.name
    Stage     = aws_api_gateway_stage.main.stage_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  count = var.alarm_topic_arn != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = var.api_latency_threshold
  alarm_description   = "This metric monitors API Gateway latency"
  alarm_actions       = [var.alarm_topic_arn]

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.main.name
    Stage     = aws_api_gateway_stage.main.stage_name
  }

  tags = var.tags
}

# CloudWatch Dashboard for API Gateway
resource "aws_cloudwatch_dashboard" "api_gateway" {
  count = var.enable_api_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-api-gateway"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.main.name, "Stage", aws_api_gateway_stage.main.stage_name],
            [".", "4XXError", ".", ".", ".", "."],
            [".", "5XXError", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Gateway Requests and Errors"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.main.name, "Stage", aws_api_gateway_stage.main.stage_name],
            [".", "IntegrationLatency", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Gateway Latency"
          period  = 300
        }
      }
    ]
  })
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

# Advanced Rate Limiting and Monitoring Features

# WAF Web ACL for API Gateway (if enabled)
resource "aws_wafv2_web_acl" "api_gateway" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.project_name}-${var.environment}-api-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = var.waf_rate_limit
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # Geographic restriction rule (if enabled)
  dynamic "rule" {
    for_each = var.enable_geo_blocking ? [1] : []
    content {
      name     = "GeoBlockRule"
      priority = 2

      override_action {
        none {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockRule"
        sampled_requests_enabled   = true
      }

      action {
        block {}
      }
    }
  }

  # IP reputation rule
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # Known bad inputs rule
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  tags = var.tags

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-api-waf"
    sampled_requests_enabled   = true
  }
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "api_gateway" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway[0].arn
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf_logs" {
  count = var.enable_waf ? 1 : 0

  name              = "/aws/wafv2/${var.project_name}-${var.environment}-api-waf"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "api_gateway" {
  count = var.enable_waf ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.api_gateway[0].arn
  log_destination_configs = ["${aws_cloudwatch_log_group.waf_logs[0].arn}:*"]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

# API Gateway Custom Domain (if certificate ARN provided)
resource "aws_api_gateway_domain_name" "main" {
  count = var.certificate_arn != "" && var.custom_domain_name != "" ? 1 : 0

  domain_name              = var.custom_domain_name
  regional_certificate_arn = var.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  security_policy = "TLS_1_2"

  tags = var.tags
}

# Base path mapping for custom domain
resource "aws_api_gateway_base_path_mapping" "main" {
  count = var.certificate_arn != "" && var.custom_domain_name != "" ? 1 : 0

  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.main[0].domain_name
}

# Client certificate for backend authentication
resource "aws_api_gateway_client_certificate" "main" {
  count = var.enable_client_certificate ? 1 : 0

  description = var.client_certificate_description
  tags        = var.tags
}

# Canary deployment settings
resource "aws_api_gateway_stage" "canary" {
  count = var.enable_canary_deployment ? 1 : 0

  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "${var.environment}-canary"

  # Canary settings
  canary_settings {
    percent_traffic          = var.canary_traffic_percentage
    deployment_id           = aws_api_gateway_deployment.main.id
    stage_variable_overrides = {
      "canary" = "true"
    }
    use_stage_cache = var.enable_caching
  }

  # Enable X-Ray tracing
  xray_tracing_enabled = var.enable_xray_tracing

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
      canary         = "$context.stage"
    })
  }

  tags = var.tags
}_api_gateway_domain_name" "main" {
  count = var.certificate_arn != "" ? 1 : 0

  domain_name              = var.custom_domain_name
  regional_certificate_arn = var.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# Base path mapping for custom domain
resource "aws_api_gateway_base_path_mapping" "main" {
  count = var.certificate_arn != "" ? 1 : 0

  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.main[0].domain_name
  base_path   = "api"
}

# CloudWatch Alarms for API Gateway Monitoring
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.api_4xx_error_threshold
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.api_5xx_error_threshold
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  alarm_actions       = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = var.api_latency_threshold
  alarm_description   = "This metric monitors API Gateway latency"
  alarm_actions       = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = var.tags
}

# API Gateway Dashboard
resource "aws_cloudwatch_dashboard" "api_gateway" {
  count = var.enable_api_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-api-gateway"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.main.name, "Stage", aws_api_gateway_stage.main.stage_name],
            [".", "4XXError", ".", ".", ".", "."],
            [".", "5XXError", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Gateway Requests and Errors"
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.main.name, "Stage", aws_api_gateway_stage.main.stage_name],
            [".", "IntegrationLatency", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Gateway Latency"
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "CacheHitCount", "ApiName", aws_api_gateway_rest_api.main.name, "Stage", aws_api_gateway_stage.main.stage_name],
            [".", "CacheMissCount", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Gateway Cache Performance"
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "log"
        x      = 8
        y      = 6
        width  = 16
        height = 6

        properties = {
          query  = "SOURCE '/aws/apigateway/${var.project_name}-${var.environment}'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 100"
          region = data.aws_region.current.name
          title  = "Recent API Gateway Errors"
          view   = "table"
        }
      }
    ]
  })
}

# Usage Analytics Lambda Function for detailed API monitoring
resource "aws_iam_role" "usage_analytics_role" {
  count = var.enable_usage_analytics ? 1 : 0

  name = "${var.project_name}-${var.environment}-usage-analytics-role"

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

resource "aws_iam_role_policy" "usage_analytics_policy" {
  count = var.enable_usage_analytics ? 1 : 0

  name = "${var.project_name}-${var.environment}-usage-analytics-policy"
  role = aws_iam_role.usage_analytics_role[0].id

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
          "apigateway:GET",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project_name}-${var.environment}-api-usage"
      }
    ]
  })
}

# DynamoDB table for API usage tracking
resource "aws_dynamodb_table" "api_usage" {
  count = var.enable_usage_analytics ? 1 : 0

  name         = "${var.project_name}-${var.environment}-api-usage"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "api_key"
  range_key    = "timestamp"

  attribute {
    name = "api_key"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "endpoint"
    type = "S"
  }

  global_secondary_index {
    name            = "endpoint-timestamp-index"
    hash_key        = "endpoint"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = var.tags
}

# Lambda function for usage analytics
resource "aws_lambda_function" "usage_analytics" {
  count = var.enable_usage_analytics ? 1 : 0

  filename         = data.archive_file.usage_analytics_zip[0].output_path
  function_name    = "${var.project_name}-${var.environment}-usage-analytics"
  role             = aws_iam_role.usage_analytics_role[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.usage_analytics_zip[0].output_base64sha256
  runtime          = "python3.9"
  timeout          = 300

  environment {
    variables = {
      DYNAMODB_TABLE = var.enable_usage_analytics ? aws_dynamodb_table.api_usage[0].name : ""
      PROJECT_NAME   = var.project_name
      ENVIRONMENT    = var.environment
    }
  }

  tags = var.tags
}

# Usage analytics Lambda source code
resource "local_file" "usage_analytics_source" {
  count = var.enable_usage_analytics ? 1 : 0

  filename = "${path.module}/usage_analytics.py"
  content  = <<EOF
import json
import boto3
import os
from datetime import datetime, timedelta
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')
apigateway = boto3.client('apigateway')

def handler(event, context):
    """
    Analyze API usage patterns and store in DynamoDB
    """
    table_name = os.environ['DYNAMODB_TABLE']
    project_name = os.environ['PROJECT_NAME']
    environment = os.environ['ENVIRONMENT']
    
    table = dynamodb.Table(table_name)
    
    try:
        # Get API usage metrics from CloudWatch
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=1)
        
        # Get API Gateway metrics
        response = cloudwatch.get_metric_statistics(
            Namespace='AWS/ApiGateway',
            MetricName='Count',
            Dimensions=[
                {
                    'Name': 'ApiName',
                    'Value': f'{project_name}-{environment}-api'
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Sum']
        )
        
        # Store usage data
        for datapoint in response['Datapoints']:
            timestamp = datapoint['Timestamp'].isoformat()
            count = datapoint['Sum']
            
            table.put_item(
                Item={
                    'api_key': 'aggregate',
                    'timestamp': timestamp,
                    'endpoint': 'all',
                    'request_count': int(count),
                    'ttl': int((end_time + timedelta(days=30)).timestamp())
                }
            )
        
        logger.info(f"Processed {len(response['Datapoints'])} usage datapoints")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed_datapoints': len(response['Datapoints'])
            })
        }
        
    except Exception as e:
        logger.error(f"Error in usage analytics: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
EOF
}

# Create ZIP file for usage analytics Lambda
data "archive_file" "usage_analytics_zip" {
  count = var.enable_usage_analytics ? 1 : 0

  type        = "zip"
  source_file = local_file.usage_analytics_source[0].filename
  output_path = "${path.module}/usage_analytics.zip"

  depends_on = [local_file.usage_analytics_source]
}

# CloudWatch Event Rule for usage analytics
resource "aws_cloudwatch_event_rule" "usage_analytics_schedule" {
  count = var.enable_usage_analytics ? 1 : 0

  name                = "${var.project_name}-${var.environment}-usage-analytics"
  description         = "Trigger usage analytics collection"
  schedule_expression = "rate(1 hour)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "usage_analytics_target" {
  count = var.enable_usage_analytics ? 1 : 0

  rule      = aws_cloudwatch_event_rule.usage_analytics_schedule[0].name
  target_id = "UsageAnalyticsTarget"
  arn       = aws_lambda_function.usage_analytics[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_usage_analytics" {
  count = var.enable_usage_analytics ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.usage_analytics[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.usage_analytics_schedule[0].arn
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}