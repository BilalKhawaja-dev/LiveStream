# DynamoDB Module Outputs

# Table information
output "table_names" {
  description = "Map of DynamoDB table names"
  value = {
    log_metadata  = aws_dynamodb_table.log_metadata.name
    user_sessions = aws_dynamodb_table.user_sessions.name
    system_config = aws_dynamodb_table.system_config.name
    audit_trail   = aws_dynamodb_table.audit_trail.name
  }
}

output "table_arns" {
  description = "Map of DynamoDB table ARNs"
  value = {
    log_metadata  = aws_dynamodb_table.log_metadata.arn
    user_sessions = aws_dynamodb_table.user_sessions.arn
    system_config = aws_dynamodb_table.system_config.arn
    audit_trail   = aws_dynamodb_table.audit_trail.arn
  }
}

output "table_ids" {
  description = "Map of DynamoDB table IDs"
  value = {
    log_metadata  = aws_dynamodb_table.log_metadata.id
    user_sessions = aws_dynamodb_table.user_sessions.id
    system_config = aws_dynamodb_table.system_config.id
    audit_trail   = aws_dynamodb_table.audit_trail.id
  }
}

# Individual table outputs
output "log_metadata_table_name" {
  description = "Name of the log metadata DynamoDB table"
  value       = aws_dynamodb_table.log_metadata.name
}

output "log_metadata_table_arn" {
  description = "ARN of the log metadata DynamoDB table"
  value       = aws_dynamodb_table.log_metadata.arn
}

output "user_sessions_table_name" {
  description = "Name of the user sessions DynamoDB table"
  value       = aws_dynamodb_table.user_sessions.name
}

output "user_sessions_table_arn" {
  description = "ARN of the user sessions DynamoDB table"
  value       = aws_dynamodb_table.user_sessions.arn
}

output "system_config_table_name" {
  description = "Name of the system config DynamoDB table"
  value       = aws_dynamodb_table.system_config.name
}

output "system_config_table_arn" {
  description = "ARN of the system config DynamoDB table"
  value       = aws_dynamodb_table.system_config.arn
}

output "audit_trail_table_name" {
  description = "Name of the audit trail DynamoDB table"
  value       = aws_dynamodb_table.audit_trail.name
}

output "audit_trail_table_arn" {
  description = "ARN of the audit trail DynamoDB table"
  value       = aws_dynamodb_table.audit_trail.arn
}

# Stream information
output "table_stream_arns" {
  description = "Map of DynamoDB table stream ARNs"
  value = {
    log_metadata  = aws_dynamodb_table.log_metadata.stream_arn
    user_sessions = aws_dynamodb_table.user_sessions.stream_arn
    system_config = aws_dynamodb_table.system_config.stream_arn
    audit_trail   = aws_dynamodb_table.audit_trail.stream_arn
  }
}

# Security information
output "kms_key_id" {
  description = "KMS key ID used for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.arn
}

output "kms_alias_name" {
  description = "KMS key alias name"
  value       = aws_kms_alias.dynamodb.name
}

# Configuration summary
output "billing_mode" {
  description = "DynamoDB billing mode used"
  value       = var.billing_mode
}

output "point_in_time_recovery_enabled" {
  description = "Whether point-in-time recovery is enabled"
  value       = var.enable_point_in_time_recovery
}

output "streams_enabled" {
  description = "Whether DynamoDB Streams are enabled"
  value       = var.enable_streams
}

# Table configuration summary
output "table_configurations" {
  description = "Summary of table configurations"
  value = {
    log_metadata = {
      name                          = aws_dynamodb_table.log_metadata.name
      billing_mode                  = aws_dynamodb_table.log_metadata.billing_mode
      point_in_time_recovery        = aws_dynamodb_table.log_metadata.point_in_time_recovery[0].enabled
      stream_enabled                = aws_dynamodb_table.log_metadata.stream_enabled
      ttl_enabled                   = aws_dynamodb_table.log_metadata.ttl[0].enabled
      global_secondary_indexes      = length(aws_dynamodb_table.log_metadata.global_secondary_index)
    }
    user_sessions = {
      name                          = aws_dynamodb_table.user_sessions.name
      billing_mode                  = aws_dynamodb_table.user_sessions.billing_mode
      point_in_time_recovery        = aws_dynamodb_table.user_sessions.point_in_time_recovery[0].enabled
      stream_enabled                = aws_dynamodb_table.user_sessions.stream_enabled
      ttl_enabled                   = aws_dynamodb_table.user_sessions.ttl[0].enabled
      global_secondary_indexes      = length(aws_dynamodb_table.user_sessions.global_secondary_index)
    }
    system_config = {
      name                          = aws_dynamodb_table.system_config.name
      billing_mode                  = aws_dynamodb_table.system_config.billing_mode
      point_in_time_recovery        = aws_dynamodb_table.system_config.point_in_time_recovery[0].enabled
      stream_enabled                = aws_dynamodb_table.system_config.stream_enabled
      global_secondary_indexes      = length(aws_dynamodb_table.system_config.global_secondary_index)
    }
    audit_trail = {
      name                          = aws_dynamodb_table.audit_trail.name
      billing_mode                  = aws_dynamodb_table.audit_trail.billing_mode
      point_in_time_recovery        = aws_dynamodb_table.audit_trail.point_in_time_recovery[0].enabled
      stream_enabled                = aws_dynamodb_table.audit_trail.stream_enabled
      ttl_enabled                   = aws_dynamodb_table.audit_trail.ttl[0].enabled
      global_secondary_indexes      = length(aws_dynamodb_table.audit_trail.global_secondary_index)
    }
  }
}

# Connection information for applications
output "dynamodb_endpoints" {
  description = "DynamoDB table endpoints for application connections"
  value = {
    log_metadata = {
      table_name = aws_dynamodb_table.log_metadata.name
      region     = data.aws_region.current.name
      kms_key_id = aws_kms_key.dynamodb.key_id
    }
    user_sessions = {
      table_name = aws_dynamodb_table.user_sessions.name
      region     = data.aws_region.current.name
      kms_key_id = aws_kms_key.dynamodb.key_id
    }
    system_config = {
      table_name = aws_dynamodb_table.system_config.name
      region     = data.aws_region.current.name
      kms_key_id = aws_kms_key.dynamodb.key_id
    }
    audit_trail = {
      table_name = aws_dynamodb_table.audit_trail.name
      region     = data.aws_region.current.name
      kms_key_id = aws_kms_key.dynamodb.key_id
    }
  }
}

# Data source for current region
data "aws_region" "current" {}#
 Backup monitoring outputs
output "backup_validation_function_arn" {
  description = "ARN of the backup validation Lambda function"
  value       = var.enable_backup_validation ? aws_lambda_function.backup_validator[0].arn : null
}

output "backup_validation_schedule" {
  description = "Schedule for backup validation"
  value       = var.backup_validation_schedule
}

output "backup_monitoring_alarms" {
  description = "Map of backup monitoring alarm names"
  value = var.enable_cloudwatch_alarms && var.enable_point_in_time_recovery ? {
    backup_lag_alarms = { for k, v in aws_cloudwatch_metric_alarm.backup_lag : k => v.alarm_name }
    backup_storage_alarms = { for k, v in aws_cloudwatch_metric_alarm.backup_storage_usage : k => v.alarm_name }
  } : {}
}

# Backup configuration summary
output "backup_configuration" {
  description = "Summary of backup configuration for all tables"
  value = {
    point_in_time_recovery_enabled = var.enable_point_in_time_recovery
    backup_retention_days         = var.backup_retention_days
    backup_validation_enabled     = var.enable_backup_validation
    backup_validation_schedule    = var.backup_validation_schedule
    backup_storage_threshold_gb   = var.backup_storage_threshold_bytes / 1073741824
  }
}