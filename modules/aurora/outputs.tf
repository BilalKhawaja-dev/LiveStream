# Aurora Serverless v2 Module Outputs

# Cluster information
output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.aurora.id
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.aurora.arn
}

output "cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "cluster_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.aurora.port
}

output "cluster_database_name" {
  description = "Aurora cluster database name"
  value       = aws_rds_cluster.aurora.database_name
}

output "cluster_master_username" {
  description = "Aurora cluster master username"
  value       = aws_rds_cluster.aurora.master_username
  sensitive   = true
}

# Instance information
output "instance_ids" {
  description = "Aurora instance identifiers"
  value       = aws_rds_cluster_instance.aurora_instances[*].id
}

output "instance_endpoints" {
  description = "Aurora instance endpoints"
  value       = aws_rds_cluster_instance.aurora_instances[*].endpoint
}

# Security and encryption
output "kms_key_id" {
  description = "KMS key ID used for Aurora encryption"
  value       = aws_kms_key.aurora.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for Aurora encryption"
  value       = aws_kms_key.aurora.arn
}

output "secrets_manager_secret_arn" {
  description = "Secrets Manager secret ARN for Aurora master password"
  value       = aws_secretsmanager_secret.aurora_master.arn
}

# Monitoring and logging
output "cloudwatch_log_groups" {
  description = "CloudWatch log group names for Aurora logs"
  value       = { for k, v in aws_cloudwatch_log_group.aurora_logs : k => v.name }
}

output "enhanced_monitoring_role_arn" {
  description = "Enhanced monitoring IAM role ARN"
  value       = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
}

# Backup configuration
output "backup_retention_period" {
  description = "Backup retention period in days"
  value       = aws_rds_cluster.aurora.backup_retention_period
}

output "backup_window" {
  description = "Backup window"
  value       = aws_rds_cluster.aurora.preferred_backup_window
}

output "maintenance_window" {
  description = "Maintenance window"
  value       = aws_rds_cluster.aurora.preferred_maintenance_window
}

# Serverless v2 configuration
output "serverless_min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity"
  value       = var.min_capacity
}

output "serverless_max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity"
  value       = var.max_capacity
}

# Connection information for applications
output "connection_info" {
  description = "Aurora connection information"
  value = {
    endpoint   = aws_rds_cluster.aurora.endpoint
    port       = aws_rds_cluster.aurora.port
    database   = aws_rds_cluster.aurora.database_name
    username   = aws_rds_cluster.aurora.master_username
    secret_arn = aws_secretsmanager_secret.aurora_master.arn
  }
  sensitive = true
}

# Database initialization Lambda function
output "db_init_lambda_function_name" {
  description = "Name of the database initialization Lambda function"
  value       = aws_lambda_function.db_init.function_name
}

output "db_init_lambda_function_arn" {
  description = "ARN of the database initialization Lambda function"
  value       = aws_lambda_function.db_init.arn
}

output "db_init_lambda_invoke_command" {
  description = "AWS CLI command to invoke the database initialization function"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.db_init.function_name} --region ${data.aws_region.current.name} response.json"
}