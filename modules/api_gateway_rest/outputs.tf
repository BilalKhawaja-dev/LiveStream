# API Gateway basic outputs
output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_arn" {
  description = "API Gateway REST API ARN"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_gateway_execution_arn" {
  description = "API Gateway execution ARN"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}"
}

output "api_gateway_stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.main.stage_name
}

# Authorizer outputs
output "cognito_authorizer_id" {
  description = "Cognito authorizer ID"
  value       = aws_api_gateway_authorizer.cognito.id
}

# Resource outputs
output "api_resources" {
  description = "Map of API Gateway resource IDs"
  value = merge(
    { for k, v in aws_api_gateway_resource.parent : k => v.id },
    { for k, v in aws_api_gateway_resource.child : k => v.id }
  )
}

output "parent_resource_ids" {
  description = "Map of parent resource IDs"
  value       = { for k, v in aws_api_gateway_resource.parent : k => v.id }
}

output "child_resource_ids" {
  description = "Map of child resource IDs"
  value       = { for k, v in aws_api_gateway_resource.child : k => v.id }
}

# Usage plan outputs
output "usage_plan_ids" {
  description = "Map of usage plan IDs"
  value = {
    basic   = aws_api_gateway_usage_plan.basic.id
    premium = aws_api_gateway_usage_plan.premium.id
    admin   = aws_api_gateway_usage_plan.admin.id
  }
}

output "api_key_ids" {
  description = "Map of API key IDs (if created)"
  value = var.create_api_keys ? {
    basic   = aws_api_gateway_api_key.basic[0].id
    premium = aws_api_gateway_api_key.premium[0].id
    admin   = aws_api_gateway_api_key.admin[0].id
  } : {}
}

output "api_key_values" {
  description = "Map of API key values (if created)"
  value = var.create_api_keys ? {
    basic   = aws_api_gateway_api_key.basic[0].value
    premium = aws_api_gateway_api_key.premium[0].value
    admin   = aws_api_gateway_api_key.admin[0].value
  } : {}
  sensitive = true
}

# Request validator outputs
output "request_validator_ids" {
  description = "Map of request validator IDs"
  value = {
    body_validator   = aws_api_gateway_request_validator.body_validator.id
    params_validator = aws_api_gateway_request_validator.params_validator.id
    full_validator   = aws_api_gateway_request_validator.full_validator.id
  }
}

# CloudWatch Log Group
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

# Configuration summary
output "api_gateway_configuration" {
  description = "Summary of API Gateway configuration"
  value = {
    api_id           = aws_api_gateway_rest_api.main.id
    stage_name       = aws_api_gateway_stage.main.stage_name
    invoke_url       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}"
    authorizer_type  = "COGNITO_USER_POOLS"
    cors_enabled     = true
    caching_enabled  = var.enable_caching
    xray_enabled     = var.enable_xray_tracing
    logging_level    = var.api_logging_level
    usage_plans      = ["basic", "premium", "admin"]
    api_keys_created = var.create_api_keys
  }
}

data "aws_region" "current" {}