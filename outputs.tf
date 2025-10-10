# Outputs for centralized logging and DR infrastructure

# General Information
output "account_id" {
  description = "AWS Account ID"
  value       = local.account_id
}

output "region" {
  description = "AWS Region"
  value       = local.region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# S3 Bucket Outputs (will be populated by modules)
output "s3_logs_bucket_name" {
  description = "Name of the S3 bucket for logs"
  value       = "" # Will be updated when S3 module is implemented
}

output "s3_logs_bucket_arn" {
  description = "ARN of the S3 bucket for logs"
  value       = "" # Will be updated when S3 module is implemented
}

# CloudWatch Outputs (will be populated by modules)
output "cloudwatch_log_groups" {
  description = "Map of CloudWatch log group names"
  value       = {} # Will be updated when CloudWatch module is implemented
}

# Kinesis Firehose Outputs (will be populated by modules)
output "kinesis_firehose_delivery_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  value       = "" # Will be updated when Kinesis module is implemented
}

# Aurora Module Outputs
output "aurora_cluster_id" {
  description = "Aurora cluster identifier"
  value       = var.enable_aurora ? module.aurora[0].cluster_id : null
}

output "aurora_cluster_arn" {
  description = "Aurora cluster ARN"
  value       = var.enable_aurora ? module.aurora[0].cluster_arn : null
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = var.enable_aurora ? module.aurora[0].cluster_endpoint : null
  sensitive   = true
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = var.enable_aurora ? module.aurora[0].cluster_reader_endpoint : null
  sensitive   = true
}

output "aurora_cluster_port" {
  description = "Aurora cluster port"
  value       = var.enable_aurora ? module.aurora[0].cluster_port : null
}

output "aurora_cluster_database_name" {
  description = "Aurora cluster database name"
  value       = var.enable_aurora ? module.aurora[0].cluster_database_name : null
}

output "aurora_instance_ids" {
  description = "Aurora instance identifiers"
  value       = var.enable_aurora ? module.aurora[0].instance_ids : []
}

output "aurora_kms_key_arn" {
  description = "KMS key ARN used for Aurora encryption"
  value       = var.enable_aurora ? module.aurora[0].kms_key_arn : null
}

output "aurora_secrets_manager_secret_arn" {
  description = "Secrets Manager secret ARN for Aurora master password"
  value       = var.enable_aurora ? module.aurora[0].secrets_manager_secret_arn : null
  sensitive   = true
}

output "aurora_cloudwatch_log_groups" {
  description = "CloudWatch log group names for Aurora logs"
  value       = var.enable_aurora ? module.aurora[0].cloudwatch_log_groups : {}
}

output "aurora_backup_retention_period" {
  description = "Aurora backup retention period in days"
  value       = var.enable_aurora ? module.aurora[0].backup_retention_period : null
}

output "aurora_connection_info" {
  description = "Aurora connection information for applications"
  value       = var.enable_aurora ? module.aurora[0].connection_info : null
  sensitive   = true
}

# DynamoDB Module Outputs
output "dynamodb_table_names" {
  description = "Map of DynamoDB table names"
  value       = module.dynamodb.table_names
}

output "dynamodb_table_arns" {
  description = "Map of DynamoDB table ARNs"
  value       = module.dynamodb.table_arns
}

output "dynamodb_kms_key_arn" {
  description = "KMS key ARN used for DynamoDB encryption"
  value       = module.dynamodb.kms_key_arn
}

output "dynamodb_table_configurations" {
  description = "Summary of DynamoDB table configurations"
  value       = module.dynamodb.table_configurations
}

output "dynamodb_backup_configuration" {
  description = "Summary of DynamoDB backup configuration"
  value       = module.dynamodb.backup_configuration
}

output "dynamodb_endpoints" {
  description = "DynamoDB connection information for applications"
  value       = module.dynamodb.dynamodb_endpoints
  sensitive   = true
}

# Athena Module Outputs
output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = module.athena.athena_workgroup_name
}

output "athena_workgroup_arn" {
  description = "ARN of the Athena workgroup"
  value       = module.athena.athena_workgroup_arn
}

output "athena_database_name" {
  description = "Name of the Athena database"
  value       = module.athena.athena_database_name
}

output "athena_workgroup_role_arn" {
  description = "ARN of the IAM role used by the Athena workgroup"
  value       = module.athena.athena_workgroup_role_arn
}

output "athena_query_result_location" {
  description = "S3 location for Athena query results"
  value       = module.athena.query_result_location
}

output "athena_workgroup_configuration" {
  description = "Summary of Athena workgroup configuration"
  value       = module.athena.workgroup_configuration
}

# VPC Outputs (will be populated by modules)
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.vpc.database_subnet_ids
}

# Storage Module Outputs

output "storage_kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = module.storage.kms_key_arn
}

output "storage_bucket_names" {
  description = "Map of all S3 bucket names"
  value       = module.storage.bucket_names
}

output "streaming_logs_bucket_arn" {
  description = "ARN of the streaming logs S3 bucket"
  value       = module.storage.streaming_logs_bucket_arn
}

output "error_logs_bucket_arn" {
  description = "ARN of the error logs S3 bucket"
  value       = module.storage.error_logs_bucket_arn
}

output "backups_bucket_arn" {
  description = "ARN of the backups S3 bucket"
  value       = module.storage.backups_bucket_arn
}

output "athena_results_bucket_arn" {
  description = "ARN of the Athena results S3 bucket"
  value       = module.storage.athena_results_bucket_arn
}

# CloudWatch Logs Module Outputs
output "log_group_names" {
  description = "Map of all CloudWatch log group names"
  value       = module.cloudwatch_logs.log_group_names
}

output "log_group_arns" {
  description = "Map of all CloudWatch log group ARNs"
  value       = module.cloudwatch_logs.log_group_arns
}

output "cloudwatch_logs_role_arn" {
  description = "ARN of the CloudWatch Logs IAM role"
  value       = module.cloudwatch_logs.cloudwatch_logs_role_arn
}

output "service_logs_role_arn" {
  description = "ARN of the Service Logs IAM role"
  value       = module.cloudwatch_logs.service_logs_role_arn
}

# Kinesis Firehose Module Outputs
output "firehose_delivery_stream_names" {
  description = "Map of all Firehose delivery stream names"
  value       = module.kinesis_firehose.delivery_stream_names
}

output "firehose_delivery_stream_arns" {
  description = "Map of all Firehose delivery stream ARNs"
  value       = module.kinesis_firehose.delivery_stream_arns
}

output "firehose_delivery_role_arn" {
  description = "ARN of the Firehose delivery IAM role"
  value       = module.kinesis_firehose.firehose_delivery_role_arn
}

# Glue Data Catalog Module Outputs
output "glue_database_name" {
  description = "Name of the Glue database for log analytics"
  value       = module.glue_catalog.glue_database_name
}

output "glue_crawler_name" {
  description = "Name of the Glue Crawler"
  value       = module.glue_catalog.glue_crawler_name
}

output "glue_table_names" {
  description = "Map of Glue table names by log category"
  value       = module.glue_catalog.glue_table_names
}

output "glue_crawler_role_arn" {
  description = "ARN of the IAM role used by the Glue Crawler"
  value       = module.glue_catalog.glue_crawler_role_arn
}

output "athena_database_name_actual" {
  description = "Actual Athena database name for queries"
  value       = module.glue_catalog.athena_database_name
}

output "glue_catalog_summary" {
  description = "Summary of Glue Data Catalog configuration"
  value       = module.glue_catalog.glue_catalog_summary
}

# IAM Module Outputs
output "iam_service_role_arns" {
  description = "Map of service role ARNs"
  value       = module.iam.service_role_arns
}

output "iam_user_policy_arns" {
  description = "Map of user and application policy ARNs"
  value       = module.iam.user_policy_arns
}

output "iam_user_group_names" {
  description = "Map of IAM group names"
  value       = module.iam.user_group_names
}

output "iam_configuration_summary" {
  description = "Summary of IAM configuration"
  value       = module.iam.iam_configuration_summary
}

# Monitoring Module Outputs
output "monitoring_dashboard_urls" {
  description = "Map of CloudWatch dashboard URLs"
  value       = module.monitoring.dashboard_urls
}

output "monitoring_cost_alert_topic_arn" {
  description = "SNS topic ARN for cost alerts"
  value       = module.monitoring.cost_alert_topic_arn
}

output "monitoring_budget_names" {
  description = "Map of budget names"
  value       = module.monitoring.budget_names
}

output "monitoring_cleanup_function_arns" {
  description = "Map of cleanup Lambda function ARNs"
  value       = module.monitoring.cleanup_function_arns
}

output "monitoring_configuration_summary" {
  description = "Summary of monitoring configuration"
  value       = module.monitoring.monitoring_configuration
}