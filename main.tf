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

  # Lifecycle configuration
  hot_tier_days                      = var.s3_lifecycle_hot_days
  warm_tier_days                     = var.s3_lifecycle_warm_days
  cold_tier_days                     = var.s3_lifecycle_cold_days
  athena_results_retention_days      = var.athena_results_retention_days
  noncurrent_version_expiration_days = 90

  tags = local.common_tags
}

# Aurora Module - Database
module "aurora" {
  count  = var.enable_aurora ? 1 : 0
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

# ECR Module - Container registry
module "ecr" {
  count  = var.enable_ecs ? 1 : 0
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  # Repository configuration
  image_tag_mutability = var.ecr_image_tag_mutability
  scan_on_push         = var.ecr_scan_on_push
  encryption_type      = var.ecr_encryption_type
  kms_key_arn          = var.ecr_encryption_type == "KMS" ? module.storage.kms_key_arn : null

  # Lifecycle configuration
  max_image_count     = var.ecr_max_image_count
  untagged_image_days = var.ecr_untagged_image_days

  # Cross-account access
  allowed_account_ids = var.ecr_allowed_account_ids

  tags = local.common_tags

  depends_on = [module.storage]
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
  certificate_arn   = var.ssl_certificate_arn != "" ? var.ssl_certificate_arn : (var.domain_name != "" ? module.acm.certificate_arn : null)

  # Frontend applications configuration matching ECS services
  frontend_applications = {
    viewer-portal = {
      port              = 3000
      priority          = 10
      health_check_path = "/health"
    }
    creator-dashboard = {
      port              = 3001
      priority          = 20
      health_check_path = "/health"
    }
    admin-portal = {
      port              = 3002
      priority          = 30
      health_check_path = "/health"
    }
    support-system = {
      port              = 3003
      priority          = 40
      health_check_path = "/health"
    }
    analytics-dashboard = {
      port              = 3004
      priority          = 50
      health_check_path = "/health"
    }
    developer-console = {
      port              = 3005
      priority          = 60
      health_check_path = "/health"
    }
  }

  # ALB Configuration
  enable_deletion_protection = var.environment == "prod" ? true : false
  idle_timeout               = 60

  # Access Logs (disabled temporarily to avoid S3 permission issues)
  enable_access_logs = false
  access_logs_bucket = null

  # CloudWatch Logs
  enable_cloudwatch_logs = var.enable_enhanced_monitoring
  log_retention_days     = var.log_retention_days
  kms_key_arn            = module.storage.kms_key_arn

  # Health Check Configuration
  health_check_healthy_threshold   = 2
  health_check_unhealthy_threshold = 3
  health_check_timeout             = 5
  health_check_interval            = 30

  # Target Group Configuration
  enable_stickiness        = false
  deregistration_delay     = 300
  slow_start_duration      = 0
  load_balancing_algorithm = "round_robin"

  # Monitoring Configuration
  enable_cloudwatch_alarms = var.enable_enhanced_monitoring
  sns_topic_arns           = [] # Will be configured later with SNS module
  response_time_threshold  = 2.0
  unhealthy_host_threshold = 1
  http_5xx_threshold       = 10

  # Security configuration
  waf_web_acl_arn = var.enable_waf ? module.waf[0].web_acl_arn : null

  tags = local.common_tags

  depends_on = [module.vpc, module.waf, module.storage]
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
# ECS Module - Container orchestration
module "ecs" {
  count  = var.enable_ecs ? 1 : 0
  source = "./modules/ecs"

  project_name = var.project_name
  environment  = var.environment

  # VPC Configuration
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = var.vpc_cidr
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = var.enable_ecs ? module.alb[0].alb_security_group_id : ""

  # ECR Configuration
  ecr_repository_url = var.enable_ecs ? module.ecr[0].repository_url : ""
  image_tag          = var.ecs_image_tag

  # Target Groups from ALB
  target_group_arns = var.enable_ecs ? module.alb[0].target_group_arns : {}

  # Service Configuration
  min_capacity = var.ecs_min_capacity
  max_capacity = var.ecs_max_capacity

  # Auto Scaling Configuration
  cpu_target_value    = var.ecs_cpu_target_value
  memory_target_value = var.ecs_memory_target_value
  scale_in_cooldown   = var.ecs_scale_in_cooldown
  scale_out_cooldown  = var.ecs_scale_out_cooldown

  # Fargate Configuration
  fargate_base_capacity      = var.ecs_fargate_base_capacity
  fargate_weight             = var.ecs_fargate_weight
  fargate_spot_base_capacity = var.ecs_fargate_spot_base_capacity
  fargate_spot_weight        = var.ecs_fargate_spot_weight

  # Application Configuration
  api_base_url                = var.api_base_url
  cognito_user_pool_id        = module.auth.user_pool_id
  cognito_user_pool_client_id = module.auth.user_pool_client_id

  # Security and Monitoring
  kms_key_arn               = module.storage.kms_key_arn
  enable_container_insights = var.ecs_enable_container_insights
  enable_ecs_exec           = var.ecs_enable_exec
  log_retention_days        = var.log_retention_days

  tags = local.common_tags

  depends_on = [module.vpc, module.alb, module.ecr, module.auth, module.storage]
}

# Lambda Functions Module - Business logic
module "lambda" {
  source = "./modules/lambda"

  project_name = var.project_name
  environment  = var.environment

  # Network Configuration
  private_subnet_ids       = module.vpc.private_subnet_ids
  lambda_security_group_id = module.vpc.lambda_security_group_id

  # Authentication Configuration
  cognito_user_pool_id = module.auth.user_pool_id
  cognito_client_id    = module.auth.user_pool_client_id
  jwt_secret_arn       = module.auth.jwt_secret_arn

  # Database Configuration
  aurora_cluster_arn = var.enable_aurora ? module.aurora[0].cluster_arn : ""
  aurora_secret_arn  = var.enable_aurora ? module.aurora[0].secrets_manager_secret_arn : ""

  # DynamoDB Configuration
  dynamodb_streams_table   = module.dynamodb.streams_table_name
  dynamodb_tickets_table   = module.dynamodb.user_sessions_table_name # Using user_sessions for tickets temporarily
  dynamodb_analytics_table = module.dynamodb.log_metadata_table_name  # Using log_metadata for analytics temporarily

  # S3 Configuration
  s3_media_bucket = var.enable_media_services ? module.media_services[0].media_content_bucket_id : ""
  kms_key_arn     = module.storage.kms_key_arn

  # MediaLive Configuration (optional)
  medialive_role_arn = var.enable_medialive ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/MediaLiveAccessRole" : ""

  # Payment Configuration - DISABLED FOR DEVELOPMENT
  # Payment processing removed to simplify development workflow

  # Support Configuration (placeholder - will be implemented later)
  support_notifications_topic_arn = ""

  # Analytics Configuration (placeholder - will be implemented later)
  athena_database_name  = "streaming_platform"
  athena_workgroup_name = "${var.project_name}-${var.environment}-workgroup"
  athena_results_bucket = module.storage.athena_results_bucket_id

  # Moderation Configuration (placeholder - will be implemented later)
  moderation_notifications_topic_arn = ""

  # Monitoring Configuration
  log_retention_days = var.log_retention_days

  tags = local.common_tags

  depends_on = [module.vpc, module.auth, module.storage, module.dynamodb]
}

# API Gateway REST Module - Backend API
module "api_gateway" {
  source = "./modules/api_gateway_rest"

  project_name = var.project_name
  environment  = var.environment

  # Lambda Function Configuration
  lambda_function_arns        = module.lambda.function_arns
  lambda_function_invoke_arns = module.lambda.function_invoke_arns

  # Authentication Configuration
  cognito_user_pool_arn              = module.auth.user_pool_arn
  jwt_authorizer_function_arn        = module.lambda.jwt_authorizer_function_arn
  jwt_authorizer_function_invoke_arn = module.lambda.jwt_authorizer_function_invoke_arn

  # Security Configuration
  allowed_ip_ranges = var.api_allowed_ip_ranges
  cors_allow_origin = var.cors_allow_origin

  # Rate Limiting Configuration
  throttling_rate_limit  = var.api_throttling_rate_limit
  throttling_burst_limit = var.api_throttling_burst_limit

  # Usage Plans Configuration
  basic_plan_quota_limit   = var.api_basic_plan_quota_limit
  basic_plan_rate_limit    = var.api_basic_plan_rate_limit
  premium_plan_quota_limit = var.api_premium_plan_quota_limit
  premium_plan_rate_limit  = var.api_premium_plan_rate_limit

  # Frontend Proxy Configuration (for SSL through API Gateway)
  alb_dns_name = var.enable_ecs ? module.alb[0].alb_dns_name : ""

  # Monitoring Configuration
  log_retention_days  = var.log_retention_days
  enable_xray_tracing = var.enable_enhanced_monitoring
  kms_key_arn         = module.storage.kms_key_arn

  tags = local.common_tags

  depends_on = [module.lambda, module.auth, module.alb]
}

