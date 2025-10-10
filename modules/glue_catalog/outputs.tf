# Outputs for Glue Data Catalog Module

# Database Outputs
output "glue_database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.streaming_logs.id
}

output "glue_database_arn" {
  description = "ARN of the Glue database"
  value       = aws_glue_catalog_database.streaming_logs.arn
}

# Crawler Outputs
output "glue_crawler_name" {
  description = "Name of the Glue Crawler"
  value       = aws_glue_crawler.streaming_logs_crawler.id
}

output "glue_crawler_arn" {
  description = "ARN of the Glue Crawler"
  value       = aws_glue_crawler.streaming_logs_crawler.arn
}

output "glue_crawler_role_arn" {
  description = "ARN of the IAM role used by the Glue Crawler"
  value       = aws_iam_role.glue_crawler_role.arn
}

# Table Outputs
output "glue_table_names" {
  description = "Map of Glue table names by category"
  value = {
    application_logs     = aws_glue_catalog_table.application_logs.id
    security_events      = aws_glue_catalog_table.security_events.id
    performance_metrics  = aws_glue_catalog_table.performance_metrics.id
    user_activity        = aws_glue_catalog_table.user_activity.id
    system_changes       = aws_glue_catalog_table.system_changes.id
  }
}

output "glue_table_arns" {
  description = "Map of Glue table ARNs by category"
  value = {
    application_logs     = "arn:aws:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.streaming_logs.id}/${aws_glue_catalog_table.application_logs.id}"
    security_events      = "arn:aws:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.streaming_logs.id}/${aws_glue_catalog_table.security_events.id}"
    performance_metrics  = "arn:aws:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.streaming_logs.id}/${aws_glue_catalog_table.performance_metrics.id}"
    user_activity        = "arn:aws:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.streaming_logs.id}/${aws_glue_catalog_table.user_activity.id}"
    system_changes       = "arn:aws:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.streaming_logs.id}/${aws_glue_catalog_table.system_changes.id}"
  }
}

# Configuration Outputs for Athena Integration
output "athena_database_name" {
  description = "Database name for Athena queries"
  value       = aws_glue_catalog_database.streaming_logs.id
}

output "partition_projection_enabled" {
  description = "Whether partition projection is enabled for cost optimization"
  value       = var.enable_partition_projection
}

# IAM Outputs for Cross-Service Integration
output "glue_crawler_policy_arn" {
  description = "ARN of the IAM policy for Glue Crawler S3 access"
  value       = aws_iam_policy.glue_crawler_s3_policy.arn
}

# Summary Output for Easy Reference
output "glue_catalog_summary" {
  description = "Summary of Glue Data Catalog resources"
  value = {
    database_name           = aws_glue_catalog_database.streaming_logs.id
    crawler_name           = aws_glue_crawler.streaming_logs_crawler.id
    crawler_schedule       = var.crawler_schedule
    partition_projection   = var.enable_partition_projection
    table_count           = 5
    log_categories        = var.log_categories
  }
}