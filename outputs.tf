# Root Module Outputs
# These outputs provide key information about the deployed infrastructure

# Network Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# Application Load Balancer
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = var.enable_ecs ? module.alb[0].alb_dns_name : null
}

output "application_url" {
  description = "URL to access the application"
  value = var.enable_ecs && length(module.alb) > 0 && module.alb[0].alb_dns_name != null ? (
    var.domain_name != "" ?
    "https://${var.domain_name}" :
    "http://${module.alb[0].alb_dns_name}"
  ) : "ALB not yet created - run terraform apply to create infrastructure"
}

# Database Information
output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = var.enable_aurora ? module.aurora[0].cluster_endpoint : null
  sensitive   = true
}

output "aurora_cluster_id" {
  description = "Aurora cluster identifier"
  value       = var.enable_aurora ? module.aurora[0].cluster_id : null
}

# Authentication
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.auth.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.auth.user_pool_client_id
}

# Media Services
output "media_bucket_name" {
  description = "S3 media bucket name"
  value       = var.enable_media_services ? module.media_services[0].media_content_bucket_id : null
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.enable_media_services && var.enable_cloudfront ? module.media_services[0].cloudfront_domain_name : null
}

# SSL Certificate
output "ssl_certificate_arn" {
  description = "SSL certificate ARN"
  value       = var.domain_name != "" ? module.acm.certificate_arn : null
}

# Security
output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = var.enable_waf ? module.waf[0].web_acl_arn : null
}

# Storage
output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = module.storage.kms_key_arn
}

# Deployment Information
output "deployment_info" {
  description = "Deployment information and next steps"
  value = {
    environment  = var.environment
    region       = var.aws_region
    project_name = var.project_name

    features_enabled = {
      ecs_containers   = var.enable_ecs
      media_services   = var.enable_media_services
      waf_protection   = var.enable_waf
      ssl_certificates = var.domain_name != ""
    }

    next_steps = [
      "1. Configure terraform.tfvars with your settings",
      "2. Run terraform plan to review changes",
      "3. Run terraform apply to deploy infrastructure",
      "4. Build and deploy container images if using ECS",
      "5. Configure DNS if using custom domain"
    ]
  }
}

# ECR Repository URL
output "ecr_repository_url" {
  description = "URL of the ECR repository for container images"
  value       = var.enable_ecs ? module.ecr[0].repository_url : null
}

# ECS Cluster Information
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = var.enable_ecs ? module.ecs[0].cluster_name : null
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = var.enable_ecs ? module.ecs[0].cluster_arn : null
}

output "ecs_service_names" {
  description = "List of ECS service names"
  value       = var.enable_ecs ? module.ecs[0].ecs_service_names : []
} # A
# API Gateway Outputs
output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.api_gateway_invoke_url
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_gateway_id
}

output "api_gateway_stage" {
  description = "API Gateway stage name"
  value       = module.api_gateway.api_gateway_stage_name
}

# Lambda Function Information
output "lambda_functions" {
  description = "Lambda function information"
  value = {
    auth_handler      = module.lambda.auth_handler_arn
    streaming_handler = module.lambda.streaming_handler_arn
    jwt_middleware    = module.lambda.jwt_authorizer_function_arn
  }
}

# Authentication Information
output "cognito_config" {
  description = "Cognito configuration for frontend applications"
  value = {
    user_pool_id        = module.auth.user_pool_id
    user_pool_client_id = module.auth.user_pool_client_id
    region              = var.aws_region
  }
}

# Frontend Environment Variables
output "frontend_env_vars" {
  description = "Environment variables for frontend applications"
  value = {
    REACT_APP_API_BASE_URL                = module.api_gateway.api_gateway_invoke_url
    REACT_APP_COGNITO_USER_POOL_ID        = module.auth.user_pool_id
    REACT_APP_COGNITO_USER_POOL_CLIENT_ID = module.auth.user_pool_client_id
    REACT_APP_AWS_REGION                  = var.aws_region
    REACT_APP_ENVIRONMENT                 = var.environment
  }
}

# Application Access URLs
output "application_urls" {
  description = "URLs to access the applications"
  value = {
    # Frontend applications (via HTTPS through API Gateway)
    frontend_https_url = "${module.api_gateway.api_gateway_invoke_url}/"

    # Backend API endpoints
    api_base_url = "${module.api_gateway.api_gateway_invoke_url}/api"
    auth_endpoints = {
      login    = "${module.api_gateway.api_gateway_invoke_url}/auth/login"
      register = "${module.api_gateway.api_gateway_invoke_url}/auth/register"
      refresh  = "${module.api_gateway.api_gateway_invoke_url}/auth/refresh"
    }

    # Direct ALB access (HTTP only, for development)
    alb_http_url = var.enable_ecs ? "http://${module.alb[0].alb_dns_name}/" : "Not deployed"
  }
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of what has been deployed"
  value = {
    infrastructure_status = "✅ Complete"
    frontend_status       = var.enable_ecs ? "✅ Deployed" : "❌ Disabled"
    backend_api_status    = "✅ Deployed"
    database_status       = var.enable_aurora ? "✅ Deployed" : "❌ Disabled"
    ssl_solution          = "✅ API Gateway provides HTTPS"

    next_steps = [
      "1. Update frontend AuthProvider to use real Cognito (remove mock data)",
      "2. Test authentication: ${module.api_gateway.api_gateway_invoke_url}/auth/login",
      "3. Access frontend via HTTPS: ${module.api_gateway.api_gateway_invoke_url}/",
      "4. Check CloudWatch logs for any issues",
      var.enable_aurora ? "5. Database is ready with schema" : "5. Enable Aurora in terraform.tfvars for full functionality"
    ]
  }
}