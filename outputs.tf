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
  value = var.enable_ecs ? (
    var.domain_name != "" ?
    "https://${var.domain_name}" :
    "http://${module.alb[0].alb_dns_name}"
  ) : null
}

# Database Information
output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = module.aurora.cluster_endpoint
  sensitive   = true
}

output "aurora_cluster_id" {
  description = "Aurora cluster identifier"
  value       = module.aurora.cluster_id
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