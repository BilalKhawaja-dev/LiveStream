# Outputs for Athena Module

# Workgroup Outputs
output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.streaming_logs.name
}

output "athena_workgroup_arn" {
  description = "ARN of the Athena workgroup"
  value       = aws_athena_workgroup.streaming_logs.arn
}

output "athena_workgroup_state" {
  description = "State of the Athena workgroup"
  value       = aws_athena_workgroup.streaming_logs.state
}

# Database Outputs
output "athena_database_name" {
  description = "Name of the Athena database"
  value       = aws_athena_database.streaming_logs.name
}

# IAM Role Outputs
output "athena_workgroup_role_arn" {
  description = "ARN of the IAM role used by the Athena workgroup"
  value       = aws_iam_role.athena_workgroup_role.arn
}

output "athena_workgroup_role_name" {
  description = "Name of the IAM role used by the Athena workgroup"
  value       = aws_iam_role.athena_workgroup_role.name
}

# Configuration Outputs
output "query_result_location" {
  description = "S3 location for Athena query results"
  value       = "s3://${var.athena_results_bucket_name}/workgroup-results/"
}

output "bytes_scanned_cutoff" {
  description = "Bytes scanned cutoff per query for cost control"
  value       = aws_athena_workgroup.streaming_logs.configuration[0].bytes_scanned_cutoff_per_query
}

output "workgroup_configuration" {
  description = "Summary of Athena workgroup configuration"
  value = {
    name                            = aws_athena_workgroup.streaming_logs.name
    state                          = aws_athena_workgroup.streaming_logs.state
    result_location                = "s3://${var.athena_results_bucket_name}/workgroup-results/"
    bytes_scanned_cutoff_per_query = aws_athena_workgroup.streaming_logs.configuration[0].bytes_scanned_cutoff_per_query
    enforce_workgroup_configuration = aws_athena_workgroup.streaming_logs.configuration[0].enforce_workgroup_configuration
    encryption_option              = aws_athena_workgroup.streaming_logs.configuration[0].result_configuration[0].encryption_configuration[0].encryption_option
  }
}

# CloudWatch Outputs
output "athena_query_log_group_name" {
  description = "Name of the CloudWatch log group for Athena queries"
  value       = var.environment == "dev" && var.enable_query_logging ? aws_cloudwatch_log_group.athena_query_logs[0].name : null
}

output "athena_query_log_group_arn" {
  description = "ARN of the CloudWatch log group for Athena queries"
  value       = var.environment == "dev" && var.enable_query_logging ? aws_cloudwatch_log_group.athena_query_logs[0].arn : null
}

# Alarm Outputs
output "data_scanned_alarm_name" {
  description = "Name of the CloudWatch alarm for data scanned monitoring"
  value       = var.environment == "dev" && var.enable_cost_monitoring ? aws_cloudwatch_metric_alarm.athena_data_scanned[0].alarm_name : null
}

output "query_execution_time_alarm_name" {
  description = "Name of the CloudWatch alarm for query execution time monitoring"
  value       = var.environment == "dev" && var.enable_performance_monitoring ? aws_cloudwatch_metric_alarm.athena_query_execution_time[0].alarm_name : null
}

# Lifecycle Policy Output
output "athena_results_lifecycle_policy_id" {
  description = "ID of the S3 lifecycle policy for Athena results"
  value       = aws_s3_bucket_lifecycle_configuration.athena_results_lifecycle.bucket
}