# API Gateway Module Outputs
# Requirements: 7.1, 7.2, 10.2

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.frontend_api.id
}

output "api_gateway_arn" {
  description = "ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.frontend_api.arn
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.frontend_api.execution_arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "https://${aws_api_gateway_domain_name.frontend_domain.domain_name}"
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.frontend_stage.stage_name
}

output "domain_name" {
  description = "Domain name for the API Gateway"
  value       = aws_api_gateway_domain_name.frontend_domain.domain_name
}

output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = aws_acm_certificate.frontend_cert.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway_logs.arn
}

output "route53_record_name" {
  description = "Name of the Route53 record"
  value       = aws_route53_record.frontend_api.name
}

output "api_gateway_resources" {
  description = "Map of API Gateway resources for each frontend application"
  value = {
    viewer = {
      id   = aws_api_gateway_resource.viewer.id
      path = aws_api_gateway_resource.viewer.path_part
    }
    creator = {
      id   = aws_api_gateway_resource.creator.id
      path = aws_api_gateway_resource.creator.path_part
    }
    admin = {
      id   = aws_api_gateway_resource.admin.id
      path = aws_api_gateway_resource.admin.path_part
    }
    support = {
      id   = aws_api_gateway_resource.support.id
      path = aws_api_gateway_resource.support.path_part
    }
    analytics = {
      id   = aws_api_gateway_resource.analytics.id
      path = aws_api_gateway_resource.analytics.path_part
    }
    dev = {
      id   = aws_api_gateway_resource.dev.id
      path = aws_api_gateway_resource.dev.path_part
    }
  }
}

output "regional_domain_name" {
  description = "Regional domain name for the API Gateway"
  value       = aws_api_gateway_domain_name.frontend_domain.regional_domain_name
}

output "regional_zone_id" {
  description = "Regional zone ID for the API Gateway"
  value       = aws_api_gateway_domain_name.frontend_domain.regional_zone_id
}