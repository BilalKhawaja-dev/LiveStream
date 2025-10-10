# API Gateway Module for Frontend Applications
# Requirements: 7.1, 7.2, 10.2

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "frontend_api" {
  name        = "${var.project_name}-${var.environment}-frontend-api"
  description = "API Gateway for streaming platform frontend applications"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-frontend-api"
    Service = "api-gateway"
    Purpose = "frontend-routing"
  })
}

# API Gateway Domain Name with AWS-managed certificate
resource "aws_api_gateway_domain_name" "frontend_domain" {
  domain_name              = var.domain_name
  regional_certificate_arn = aws_acm_certificate_validation.frontend_cert.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-domain"
  })

  depends_on = [aws_acm_certificate_validation.frontend_cert]
}

# ACM Certificate for the domain
resource "aws_acm_certificate" "frontend_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-cert"
  })
}

# Route53 records for certificate validation
resource "aws_route53_record" "frontend_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "frontend_cert" {
  certificate_arn         = aws_acm_certificate.frontend_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.frontend_cert_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# API Gateway Resources for each frontend application
resource "aws_api_gateway_resource" "viewer" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_rest_api.frontend_api.root_resource_id
  path_part   = "viewer"
}

resource "aws_api_gateway_resource" "viewer_proxy" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_resource.viewer.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_resource" "creator" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_rest_api.frontend_api.root_resource_id
  path_part   = "creator"
}

resource "aws_api_gateway_resource" "creator_proxy" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_resource.creator.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_resource" "admin" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_rest_api.frontend_api.root_resource_id
  path_part   = "admin"
}

resource "aws_api_gateway_resource" "admin_proxy" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_resource.admin.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_resource" "support" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_rest_api.frontend_api.root_resource_id
  path_part   = "support"
}

resource "aws_api_gateway_resource" "support_proxy" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_resource.support.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_resource" "analytics" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_rest_api.frontend_api.root_resource_id
  path_part   = "analytics"
}

resource "aws_api_gateway_resource" "analytics_proxy" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_resource.analytics.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_resource" "dev" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_rest_api.frontend_api.root_resource_id
  path_part   = "dev"
}

resource "aws_api_gateway_resource" "dev_proxy" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  parent_id   = aws_api_gateway_resource.dev.id
  path_part   = "{proxy+}"
}

# API Gateway Methods for ALB integration
locals {
  app_resources = {
    viewer = {
      resource = aws_api_gateway_resource.viewer
      proxy_resource = aws_api_gateway_resource.viewer_proxy
      alb_dns = var.alb_dns_name
    }
    creator = {
      resource = aws_api_gateway_resource.creator
      proxy_resource = aws_api_gateway_resource.creator_proxy
      alb_dns = var.alb_dns_name
    }
    admin = {
      resource = aws_api_gateway_resource.admin
      proxy_resource = aws_api_gateway_resource.admin_proxy
      alb_dns = var.alb_dns_name
    }
    support = {
      resource = aws_api_gateway_resource.support
      proxy_resource = aws_api_gateway_resource.support_proxy
      alb_dns = var.alb_dns_name
    }
    analytics = {
      resource = aws_api_gateway_resource.analytics
      proxy_resource = aws_api_gateway_resource.analytics_proxy
      alb_dns = var.alb_dns_name
    }
    dev = {
      resource = aws_api_gateway_resource.dev
      proxy_resource = aws_api_gateway_resource.dev_proxy
      alb_dns = var.alb_dns_name
    }
  }
}

# HTTP Integration for each app (root path)
resource "aws_api_gateway_method" "app_root_method" {
  for_each = local.app_resources

  rest_api_id   = aws_api_gateway_rest_api.frontend_api.id
  resource_id   = each.value.resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "app_root_integration" {
  for_each = local.app_resources

  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  resource_id = each.value.resource.id
  http_method = aws_api_gateway_method.app_root_method[each.key].http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${each.value.alb_dns}/${each.key}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# HTTP Integration for each app (proxy paths)
resource "aws_api_gateway_method" "app_proxy_method" {
  for_each = local.app_resources

  rest_api_id   = aws_api_gateway_rest_api.frontend_api.id
  resource_id   = each.value.proxy_resource.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "app_proxy_integration" {
  for_each = local.app_resources

  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  resource_id = each.value.proxy_resource.id
  http_method = aws_api_gateway_method.app_proxy_method[each.key].http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${each.value.alb_dns}/${each.key}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# CORS Configuration
resource "aws_api_gateway_method" "cors_method" {
  for_each = merge(
    { for k, v in local.app_resources : "${k}_root" => v.resource },
    { for k, v in local.app_resources : "${k}_proxy" => v.proxy_resource }
  )

  rest_api_id   = aws_api_gateway_rest_api.frontend_api.id
  resource_id   = each.value.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_integration" {
  for_each = aws_api_gateway_method.cors_method

  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "cors_method_response" {
  for_each = aws_api_gateway_method.cors_method

  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "cors_integration_response" {
  for_each = aws_api_gateway_integration.cors_integration

  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = aws_api_gateway_method_response.cors_method_response[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_method_response.cors_method_response]
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "frontend_deployment" {
  depends_on = [
    aws_api_gateway_integration.app_root_integration,
    aws_api_gateway_integration.app_proxy_integration,
    aws_api_gateway_integration_response.cors_integration_response,
  ]

  rest_api_id = aws_api_gateway_rest_api.frontend_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.viewer.id,
      aws_api_gateway_resource.creator.id,
      aws_api_gateway_resource.admin.id,
      aws_api_gateway_resource.support.id,
      aws_api_gateway_resource.analytics.id,
      aws_api_gateway_resource.dev.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "frontend_stage" {
  deployment_id = aws_api_gateway_deployment.frontend_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.frontend_api.id
  stage_name    = var.environment

  # Enable logging
  access_log_destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
  access_log_format = jsonencode({
    requestId      = "$requestId"
    ip             = "$sourceIp"
    caller         = "$caller"
    user           = "$user"
    requestTime    = "$requestTime"
    httpMethod     = "$httpMethod"
    resourcePath   = "$resourcePath"
    status         = "$status"
    protocol       = "$protocol"
    responseLength = "$responseLength"
    responseTime   = "$responseTime"
    error          = "$error.message"
    integrationError = "$integrationError"
  })

  # Enable X-Ray tracing
  xray_tracing_enabled = var.enable_xray_tracing

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-stage"
  })
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-frontend"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-api-gateway-logs"
  })
}

# Base Path Mapping
resource "aws_api_gateway_base_path_mapping" "frontend_mapping" {
  api_id      = aws_api_gateway_rest_api.frontend_api.id
  stage_name  = aws_api_gateway_stage.frontend_stage.stage_name
  domain_name = aws_api_gateway_domain_name.frontend_domain.domain_name
}

# Route53 Record for API Gateway
resource "aws_route53_record" "frontend_api" {
  name    = aws_api_gateway_domain_name.frontend_domain.domain_name
  type    = "A"
  zone_id = var.route53_zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.frontend_domain.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.frontend_domain.regional_zone_id
  }
}

# API Gateway Method Settings for throttling and caching
resource "aws_api_gateway_method_settings" "frontend_settings" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api.id
  stage_name  = aws_api_gateway_stage.frontend_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level     = var.api_gateway_logging_level
    data_trace_enabled = var.enable_data_trace
    
    # Throttling settings
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
    
    # Caching settings
    caching_enabled      = var.enable_caching
    cache_ttl_in_seconds = var.cache_ttl_seconds
    cache_key_parameters = []
  }
}

# CloudWatch Alarms for API Gateway
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-api-gateway-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_4xx_threshold
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.frontend_api.name
    Stage     = aws_api_gateway_stage.frontend_stage.stage_name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-api-gateway-4xx-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_5xx_threshold
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.frontend_api.name
    Stage     = aws_api_gateway_stage.frontend_stage.stage_name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-api-gateway-5xx-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-api-gateway-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = var.latency_threshold_ms
  alarm_description   = "This metric monitors API Gateway latency"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.frontend_api.name
    Stage     = aws_api_gateway_stage.frontend_stage.stage_name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-api-gateway-latency-alarm"
  })
}