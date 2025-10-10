# Main Terraform configuration for centralized logging and DR infrastructure
# This file orchestrates all modules for the streaming application

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" {
  #   bucket         = "terraform-state-centralized-logging-dr"
  #   key            = "dev/terraform.tfstate"
  #   region         = "eu-west-2"
  #   dynamodb_table = "terraform-state-lock-centralized-logging-dr"
  #   encrypt        = true
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "centralized-logging-dr"
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
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Naming convention: {project}-{component}-{environment}-{account_id}
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Region      = local.region
  }
}
# Storage Module - S3 buckets for logs, backups, and query results
module "storage" {
  source = "./modules/storage"

  project_name                       = var.project_name
  environment                        = var.environment
  hot_tier_days                      = var.s3_lifecycle_hot_days
  warm_tier_days                     = var.s3_lifecycle_warm_days
  cold_tier_days                     = var.s3_lifecycle_cold_days
  athena_results_retention_days      = 30
  noncurrent_version_expiration_days = 30
  kms_deletion_window                = var.kms_key_deletion_window

  tags = local.common_tags
}

# CloudWatch Logs Module - Log groups for all streaming services
module "cloudwatch_logs" {
  source = "./modules/cloudwatch_logs"

  project_name                  = var.project_name
  environment                   = var.environment
  log_retention_days           = var.log_retention_days
  kms_key_arn                  = module.storage.kms_key_arn
  enable_subscription_filters  = true
  firehose_delivery_stream_arn = module.kinesis_firehose.application_logs_delivery_stream_arn
  alarm_evaluation_periods     = var.cloudwatch_alarm_evaluation_periods
  error_rate_threshold         = var.cloudwatch_alarm_threshold_error_rate

  tags = local.common_tags
}

# Kinesis Firehose Module - Delivery streams for log processing
module "kinesis_firehose" {
  source = "./modules/kinesis_firehose"

  project_name         = var.project_name
  environment          = var.environment
  s3_bucket_arn       = module.storage.streaming_logs_bucket_arn
  s3_error_bucket_arn = module.storage.error_logs_bucket_arn
  kms_key_arn         = module.storage.kms_key_arn
  log_retention_days  = var.log_retention_days
  buffer_size         = var.firehose_buffer_size
  buffer_interval     = var.firehose_buffer_interval

  tags = local.common_tags
}

# Glue Data Catalog Module - Database and tables for log analytics
module "glue_catalog" {
  source = "./modules/glue_catalog"

  project_name        = var.project_name
  environment         = var.environment
  s3_logs_bucket_name = module.storage.streaming_logs_bucket_id
  s3_logs_bucket_arn  = module.storage.streaming_logs_bucket_arn
  kms_key_arn         = module.storage.kms_key_arn
  crawler_schedule    = var.glue_crawler_schedule

  tags = local.common_tags

  depends_on = [
    module.storage,
    module.kinesis_firehose
  ]
}

# Athena Module - Workgroup and query optimization
module "athena" {
  source = "./modules/athena"

  project_name                = var.project_name
  environment                 = var.environment
  athena_results_bucket_name  = module.storage.athena_results_bucket_id
  athena_results_bucket_arn   = module.storage.athena_results_bucket_arn
  s3_logs_bucket_arn          = module.storage.streaming_logs_bucket_arn
  glue_database_name          = module.glue_catalog.glue_database_name
  kms_key_arn                 = module.storage.kms_key_arn
  log_retention_days          = var.log_retention_days
  athena_results_retention_days = var.athena_results_retention_days
  enable_query_logging        = var.enable_athena_query_logging
  enable_cost_monitoring      = var.enable_athena_cost_monitoring
  enable_performance_monitoring = var.enable_athena_performance_monitoring
  data_scanned_alarm_threshold = var.athena_bytes_scanned_cutoff_gb * 1073741824 # Convert GB to bytes
  query_execution_time_threshold = var.athena_query_execution_time_threshold_minutes * 60000 # Convert minutes to milliseconds

  tags = local.common_tags

  depends_on = [
    module.storage,
    module.glue_catalog
  ]
}

# Aurora Module - Serverless v2 database for log storage and analytics
module "aurora" {
  source = "./modules/aurora"

  project_name = var.project_name
  environment  = var.environment

  # Serverless v2 scaling configuration
  min_capacity   = var.aurora_min_capacity
  max_capacity   = var.aurora_max_capacity
  instance_count = var.aurora_instance_count

  # Database configuration
  engine_version  = var.aurora_engine_version
  database_name   = var.aurora_database_name
  master_username = var.aurora_master_username
  port           = var.aurora_port

  # Backup and maintenance
  backup_retention_period = var.aurora_backup_retention_period
  backup_window          = var.aurora_backup_window
  maintenance_window     = var.aurora_maintenance_window
  deletion_protection    = var.aurora_deletion_protection

  # Monitoring and logging
  enabled_cloudwatch_logs_exports        = var.aurora_enabled_cloudwatch_logs_exports
  monitoring_interval                    = var.aurora_monitoring_interval
  performance_insights_enabled           = var.aurora_performance_insights_enabled
  performance_insights_retention_period  = var.aurora_performance_insights_retention_period
  log_retention_days                     = var.log_retention_days

  # Security
  availability_zones         = var.availability_zones
  auto_minor_version_upgrade = var.aurora_auto_minor_version_upgrade
  kms_deletion_window       = var.kms_key_deletion_window

  # CloudWatch alarms
  enable_cloudwatch_alarms           = var.aurora_enable_cloudwatch_alarms
  alarm_cpu_threshold               = var.aurora_alarm_cpu_threshold
  alarm_connection_threshold        = var.aurora_alarm_connection_threshold
  alarm_freeable_memory_threshold   = var.aurora_alarm_freeable_memory_threshold
  backup_alarm_enabled              = var.aurora_backup_alarm_enabled
  backup_window_hours               = var.aurora_backup_window_hours

  tags = local.common_tags
}

# DynamoDB Module - NoSQL database for metadata and session management
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment

  # Billing configuration
  billing_mode    = var.dynamodb_billing_mode
  read_capacity   = var.dynamodb_read_capacity
  write_capacity  = var.dynamodb_write_capacity

  # Backup and recovery
  enable_point_in_time_recovery = var.dynamodb_enable_point_in_time_recovery
  backup_retention_days         = var.dynamodb_backup_retention_days

  # Streaming configuration
  enable_streams     = var.dynamodb_enable_streams
  stream_view_type   = var.dynamodb_stream_view_type

  # TTL configuration
  enable_ttl = var.dynamodb_enable_ttl

  # Security
  kms_deletion_window = var.kms_key_deletion_window

  # Monitoring
  enable_cloudwatch_alarms              = var.dynamodb_enable_cloudwatch_alarms
  read_throttle_threshold              = var.dynamodb_read_throttle_threshold
  write_throttle_threshold             = var.dynamodb_write_throttle_threshold
  consumed_read_capacity_threshold     = var.dynamodb_consumed_read_capacity_threshold
  consumed_write_capacity_threshold    = var.dynamodb_consumed_write_capacity_threshold

  # Auto-scaling (for provisioned mode)
  enable_autoscaling                   = var.dynamodb_enable_autoscaling
  autoscaling_read_target             = var.dynamodb_autoscaling_read_target
  autoscaling_write_target            = var.dynamodb_autoscaling_write_target
  autoscaling_min_read_capacity       = var.dynamodb_autoscaling_min_read_capacity
  autoscaling_max_read_capacity       = var.dynamodb_autoscaling_max_read_capacity
  autoscaling_min_write_capacity      = var.dynamodb_autoscaling_min_write_capacity
  autoscaling_max_write_capacity      = var.dynamodb_autoscaling_max_write_capacity

  # Backup monitoring
  backup_storage_threshold_bytes       = var.dynamodb_backup_storage_threshold_bytes
  enable_backup_validation            = var.dynamodb_enable_backup_validation
  backup_validation_schedule          = var.dynamodb_backup_validation_schedule
  log_retention_days                  = var.log_retention_days

  tags = local.common_tags
}

# IAM Module - Service-specific roles and user policies
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment

  # Resource ARNs for cross-service permissions
  s3_bucket_arns        = [
    module.storage.streaming_logs_bucket_arn,
    module.storage.error_logs_bucket_arn,
    module.storage.backups_bucket_arn,
    module.storage.athena_results_bucket_arn
  ]
  s3_bucket_names       = [
    module.storage.streaming_logs_bucket_id,
    module.storage.error_logs_bucket_id,
    module.storage.backups_bucket_id,
    module.storage.athena_results_bucket_id
  ]
  kms_key_arns          = [
    module.storage.kms_key_arn,
    module.aurora.kms_key_arn,
    module.dynamodb.kms_key_arn
  ]
  kms_key_ids           = [
    module.storage.kms_key_id,
    module.aurora.kms_key_id,
    module.dynamodb.kms_key_id
  ]
  kinesis_firehose_arns = values(module.kinesis_firehose.delivery_stream_arns)
  dynamodb_table_arns   = values(module.dynamodb.table_arns)
  aurora_cluster_arns   = [module.aurora.cluster_arn]
  glue_catalog_arns     = [
    module.glue_catalog.glue_database_arn,
    "${module.glue_catalog.glue_database_arn}/*"
  ]

  # User and application policy settings
  create_user_groups           = var.iam_create_user_groups
  enable_developer_access      = var.iam_enable_developer_access
  enable_cross_service_access  = var.iam_enable_cross_service_access

  # Security settings
  require_mfa              = var.iam_require_mfa
  max_session_duration     = var.iam_max_session_duration
  enable_cross_account_access = var.iam_enable_cross_account_access

  tags = local.common_tags

  depends_on = [
    module.storage,
    module.aurora,
    module.dynamodb,
    module.kinesis_firehose,
    module.glue_catalog
  ]
}

# Monitoring Module - CloudWatch dashboards, cost alerts, and cleanup
module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment

  # Resource identifiers for dashboard metrics
  s3_logs_bucket_name              = module.storage.streaming_logs_bucket_id
  s3_error_logs_bucket_name        = module.storage.error_logs_bucket_id
  s3_backups_bucket_name           = module.storage.backups_bucket_id
  s3_athena_results_bucket_name    = module.storage.athena_results_bucket_id
  aurora_cluster_id                = module.aurora.cluster_id
  dynamodb_log_metadata_table_name = module.dynamodb.log_metadata_table_name
  athena_workgroup_name            = module.athena.athena_workgroup_name
  glue_crawler_name                = module.glue_catalog.glue_crawler_name

  # Dashboard configuration
  enable_security_dashboard    = var.monitoring_enable_security_dashboard
  enable_cost_dashboard       = var.monitoring_enable_cost_dashboard
  enable_performance_dashboard = var.monitoring_enable_performance_dashboard
  dashboard_refresh_interval  = var.monitoring_dashboard_refresh_interval

  # Cost monitoring and budget configuration
  monthly_budget_limit              = var.monitoring_monthly_budget_limit
  budget_notification_emails        = var.monitoring_budget_notification_emails
  enable_service_budgets           = var.monitoring_enable_service_budgets
  s3_budget_limit                  = var.monitoring_s3_budget_limit
  rds_budget_limit                 = var.monitoring_rds_budget_limit
  billing_alarm_threshold          = var.monitoring_billing_alarm_threshold
  enable_service_cost_alarms       = var.monitoring_enable_service_cost_alarms
  s3_cost_alarm_threshold          = var.monitoring_s3_cost_alarm_threshold
  athena_cost_alarm_threshold      = var.monitoring_athena_cost_alarm_threshold
  data_transfer_cost_alarm_threshold = var.monitoring_data_transfer_cost_alarm_threshold
  enable_anomaly_detection         = var.monitoring_enable_anomaly_detection
  anomaly_detection_email          = var.monitoring_anomaly_detection_email
  anomaly_threshold_amount         = var.monitoring_anomaly_threshold_amount
  enable_cost_optimization_lambda  = var.monitoring_enable_cost_optimization_lambda
  cost_optimization_schedule       = var.monitoring_cost_optimization_schedule

  # Automated cleanup configuration
  enable_automated_cleanup         = var.monitoring_enable_automated_cleanup
  athena_results_retention_days    = var.monitoring_athena_results_retention_days
  query_results_retention_days     = var.monitoring_query_results_retention_days
  log_cleanup_retention_days       = var.monitoring_log_cleanup_retention_days
  s3_cleanup_schedule              = var.monitoring_s3_cleanup_schedule
  logs_cleanup_schedule            = var.monitoring_logs_cleanup_schedule

  tags = local.common_tags

  depends_on = [
    module.storage,
    module.aurora,
    module.dynamodb,
    module.athena,
    module.glue_catalog
  ]
}