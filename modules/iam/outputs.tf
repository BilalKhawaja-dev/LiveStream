# IAM Module Outputs

# Service Role ARNs
output "service_role_arns" {
  description = "Map of service role ARNs"
  value = {
    cloudwatch_logs = aws_iam_role.cloudwatch_logs_role.arn
    kinesis_firehose = aws_iam_role.kinesis_firehose_role.arn
    s3_service      = aws_iam_role.s3_service_role.arn
    aurora_service  = aws_iam_role.aurora_service_role.arn
    dynamodb_service = aws_iam_role.dynamodb_service_role.arn
    glue_service    = aws_iam_role.glue_service_role.arn
    athena_service  = aws_iam_role.athena_service_role.arn
    lambda_execution = aws_iam_role.lambda_execution_role.arn
  }
}

# Individual Service Role ARNs
output "cloudwatch_logs_role_arn" {
  description = "CloudWatch Logs service role ARN"
  value       = aws_iam_role.cloudwatch_logs_role.arn
}

output "cloudwatch_logs_role_name" {
  description = "CloudWatch Logs service role name"
  value       = aws_iam_role.cloudwatch_logs_role.name
}

output "kinesis_firehose_role_arn" {
  description = "Kinesis Firehose service role ARN"
  value       = aws_iam_role.kinesis_firehose_role.arn
}

output "kinesis_firehose_role_name" {
  description = "Kinesis Firehose service role name"
  value       = aws_iam_role.kinesis_firehose_role.name
}

output "s3_service_role_arn" {
  description = "S3 service role ARN"
  value       = aws_iam_role.s3_service_role.arn
}

output "s3_service_role_name" {
  description = "S3 service role name"
  value       = aws_iam_role.s3_service_role.name
}

output "aurora_service_role_arn" {
  description = "Aurora service role ARN"
  value       = aws_iam_role.aurora_service_role.arn
}

output "aurora_service_role_name" {
  description = "Aurora service role name"
  value       = aws_iam_role.aurora_service_role.name
}

output "dynamodb_service_role_arn" {
  description = "DynamoDB service role ARN"
  value       = aws_iam_role.dynamodb_service_role.arn
}

output "dynamodb_service_role_name" {
  description = "DynamoDB service role name"
  value       = aws_iam_role.dynamodb_service_role.name
}

output "glue_service_role_arn" {
  description = "Glue service role ARN"
  value       = aws_iam_role.glue_service_role.arn
}

output "glue_service_role_name" {
  description = "Glue service role name"
  value       = aws_iam_role.glue_service_role.name
}

output "athena_service_role_arn" {
  description = "Athena service role ARN"
  value       = aws_iam_role.athena_service_role.arn
}

output "athena_service_role_name" {
  description = "Athena service role name"
  value       = aws_iam_role.athena_service_role.name
}

output "lambda_execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_execution_role_name" {
  description = "Lambda execution role name"
  value       = aws_iam_role.lambda_execution_role.name
}

# Service Role Names (for reference in other modules)
output "service_role_names" {
  description = "Map of service role names"
  value = {
    cloudwatch_logs = aws_iam_role.cloudwatch_logs_role.name
    kinesis_firehose = aws_iam_role.kinesis_firehose_role.name
    s3_service      = aws_iam_role.s3_service_role.name
    aurora_service  = aws_iam_role.aurora_service_role.name
    dynamodb_service = aws_iam_role.dynamodb_service_role.name
    glue_service    = aws_iam_role.glue_service_role.name
    athena_service  = aws_iam_role.athena_service_role.name
    lambda_execution = aws_iam_role.lambda_execution_role.name
  }
}

# Policy ARNs
output "service_policy_arns" {
  description = "Map of service policy ARNs"
  value = {
    cloudwatch_logs = aws_iam_role_policy.cloudwatch_logs_policy.arn
    kinesis_firehose = aws_iam_role_policy.kinesis_firehose_policy.arn
    s3_service      = aws_iam_role_policy.s3_service_policy.arn
    aurora_service  = aws_iam_role_policy.aurora_service_policy.arn
    dynamodb_service = aws_iam_role_policy.dynamodb_service_policy.arn
    glue_service    = aws_iam_role_policy.glue_service_policy.arn
    athena_service  = aws_iam_role_policy.athena_service_policy.arn
    lambda_execution = aws_iam_role_policy.lambda_execution_policy.arn
  }
}

# Role configuration summary
output "iam_configuration_summary" {
  description = "Summary of IAM configuration"
  value = {
    total_service_roles = 8
    cross_account_access_enabled = var.enable_cross_account_access
    mfa_required = var.require_mfa
    max_session_duration = var.max_session_duration
    environment = var.environment
    project_name = var.project_name
  }
}# User
 and Application Policy Outputs
output "user_policy_arns" {
  description = "Map of user and application policy ARNs"
  value = {
    log_access           = aws_iam_policy.log_access_policy.arn
    backup_management    = aws_iam_policy.backup_management_policy.arn
    query_execution      = aws_iam_policy.query_execution_policy.arn
    monitoring          = aws_iam_policy.monitoring_policy.arn
    developer_access    = aws_iam_policy.developer_access_policy.arn
    application_service = aws_iam_policy.application_service_policy.arn
  }
}

output "user_group_names" {
  description = "Map of IAM group names"
  value = var.create_user_groups ? {
    log_analysts     = var.create_user_groups ? aws_iam_group.log_analysts[0].name : null
    backup_operators = var.create_user_groups ? aws_iam_group.backup_operators[0].name : null
    developers       = var.create_user_groups && var.environment == "dev" ? aws_iam_group.developers[0].name : null
    monitoring_team  = var.create_user_groups ? aws_iam_group.monitoring_team[0].name : null
  } : {}
}

output "user_group_arns" {
  description = "Map of IAM group ARNs"
  value = var.create_user_groups ? {
    log_analysts     = var.create_user_groups ? aws_iam_group.log_analysts[0].arn : null
    backup_operators = var.create_user_groups ? aws_iam_group.backup_operators[0].arn : null
    developers       = var.create_user_groups && var.environment == "dev" ? aws_iam_group.developers[0].arn : null
    monitoring_team  = var.create_user_groups ? aws_iam_group.monitoring_team[0].arn : null
  } : {}
}

# Policy configuration summary
output "policy_configuration_summary" {
  description = "Summary of policy configuration"
  value = {
    total_user_policies = 6
    total_service_roles = 8
    user_groups_created = var.create_user_groups
    developer_access_enabled = var.enable_developer_access && var.environment == "dev"
    cross_service_access_enabled = var.enable_cross_service_access
    environment = var.environment
  }
}