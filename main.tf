# Main Terraform configuration for streaming platform infrastructure

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for resource naming
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# VPC Module - Network infrastructure
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  tags = local.common_tags
}

# Storage Module - S3 buckets and KMS keys
module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = var.environment

  tags = local.common_tags
}

# Aurora Module - Database
module "aurora" {
  source = "./modules/aurora"

  project_name = var.project_name
  environment  = var.environment

  # VPC Configuration
  vpc_id                   = module.vpc.vpc_id
  database_subnet_ids      = module.vpc.database_subnet_ids
  aurora_security_group_id = module.vpc.aurora_security_group_id
  aurora_subnet_group_name = module.vpc.aurora_subnet_group_name
  availability_zones       = var.availability_zones

  # Serverless v2 scaling configuration
  min_capacity = var.aurora_min_capacity
  max_capacity = var.aurora_max_capacity

  # Backup and maintenance
  backup_retention_period = var.aurora_backup_retention_period
  backup_window           = var.aurora_preferred_backup_window
  maintenance_window      = var.aurora_preferred_maintenance_window

  depends_on = [module.vpc]
}

# DynamoDB Module - NoSQL database
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment
}

# Authentication Module - Cognito user management
module "auth" {
  source = "./modules/auth"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name

  tags = local.common_tags
}

# WAF Module - Web Application Firewall
module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "./modules/waf"

  project_name = var.project_name
  environment  = var.environment

  # Rate limiting configuration
  rate_limit_per_5min = var.waf_rate_limit_per_5min

  # Geographic blocking
  enable_geo_blocking = var.waf_enable_geo_blocking
  blocked_countries   = var.waf_blocked_countries

  # IP access control
  allowed_ip_ranges = var.waf_allowed_ip_ranges
  admin_ip_ranges   = var.waf_admin_ip_ranges

  # Request size limits
  max_request_body_size = var.waf_max_request_body_size

  # Rule exclusions
  excluded_common_rules = var.waf_excluded_common_rules

  # Security features
  enable_sql_injection_protection = var.waf_enable_sql_injection_protection
  enable_xss_protection           = var.waf_enable_xss_protection
  enable_size_restrictions        = var.waf_enable_size_restrictions
  enable_admin_path_protection    = var.waf_enable_admin_path_protection

  # Monitoring
  blocked_requests_threshold = var.waf_blocked_requests_threshold
  rate_limit_alarm_threshold = var.waf_rate_limit_alarm_threshold

  # Logging
  log_retention_days = var.log_retention_days

  tags = local.common_tags
}

# ACM Certificate Module - SSL/TLS certificates
module "acm" {
  source = "./modules/acm"

  project_name = var.project_name
  environment  = var.environment

  # Domain configuration
  domain_name                 = var.domain_name
  subject_alternative_names   = var.subject_alternative_names
  enable_wildcard_certificate = var.enable_wildcard_certificate

  tags = local.common_tags
}

# ALB Module - Application Load Balancer
module "alb" {
  count  = var.enable_ecs ? 1 : 0
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = var.vpc_cidr
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = var.ssl_certificate_arn != "" ? var.ssl_certificate_arn : (var.domain_name != "" ? module.acm.certificate_arn : "")

  # Security configuration
  waf_web_acl_arn = var.enable_waf ? module.waf[0].web_acl_arn : null

  tags = local.common_tags

  depends_on = [module.vpc, module.waf]
}

# Media Services Module - S3 storage and CloudFront CDN
module "media_services" {
  count  = var.enable_media_services ? 1 : 0
  source = "./modules/media_services"

  project_name = var.project_name
  environment  = var.environment

  # S3 Configuration
  enable_versioning = var.media_enable_versioning
  kms_key_arn       = module.storage.kms_key_arn

  # S3 Lifecycle Configuration
  ia_transition_days                 = var.media_ia_transition_days
  glacier_transition_days            = var.media_glacier_transition_days
  deep_archive_transition_days       = var.media_deep_archive_transition_days
  noncurrent_version_expiration_days = var.media_noncurrent_version_expiration_days

  # CloudFront Configuration
  enable_cloudfront   = var.enable_cloudfront
  custom_domain       = var.media_custom_domain
  ssl_certificate_arn = var.media_custom_domain != "" ? module.acm.certificate_arn : ""

  # Cache Configuration
  default_cache_ttl      = var.cloudfront_default_cache_ttl
  max_cache_ttl          = var.cloudfront_max_cache_ttl
  cloudfront_price_class = var.cloudfront_price_class

  # Geographic Restrictions
  geo_restriction_type      = var.cloudfront_geo_restriction_type
  geo_restriction_locations = var.cloudfront_geo_restriction_locations

  # CORS Configuration
  cors_allowed_origins = var.media_cors_allowed_origins

  # Security
  waf_web_acl_arn = var.enable_waf ? module.waf[0].web_acl_arn : ""

  # Monitoring
  enable_monitoring          = var.enable_media_monitoring
  s3_size_alarm_threshold_gb = var.media_s3_size_alarm_threshold_gb
  cloudfront_4xx_threshold   = var.media_cloudfront_4xx_threshold

  # Cost Optimization
  enable_intelligent_tiering   = var.media_enable_intelligent_tiering
  enable_transfer_acceleration = var.media_enable_transfer_acceleration

  tags = local.common_tags

  depends_on = [module.waf, module.acm, module.storage]
}