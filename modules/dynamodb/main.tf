# DynamoDB Module for Centralized Logging
# Requirements: 3.2, 4.1, 4.7, 5.5

# KMS key for DynamoDB encryption
resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for DynamoDB table encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-dynamodb-key"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
  }
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${var.project_name}-${var.environment}-dynamodb"
  target_key_id = aws_kms_key.dynamodb.key_id
}

# DynamoDB table for log metadata and indexing
resource "aws_dynamodb_table" "log_metadata" {
  name             = "${var.project_name}-${var.environment}-log-metadata"
  billing_mode     = var.billing_mode
  hash_key         = "log_id"
  range_key        = "timestamp"
  stream_enabled   = var.enable_streams
  stream_view_type = var.enable_streams ? "NEW_AND_OLD_IMAGES" : null

  # Provisioned throughput (only when billing_mode is PROVISIONED)
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Attributes
  attribute {
    name = "log_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "service_name"
    type = "S"
  }

  attribute {
    name = "log_level"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  # Global Secondary Index for service-based queries
  global_secondary_index {
    name            = "ServiceIndex"
    hash_key        = "service_name"
    range_key       = "timestamp"
    projection_type = "ALL"
    read_capacity   = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity  = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }

  # Global Secondary Index for log level queries
  global_secondary_index {
    name               = "LogLevelIndex"
    hash_key           = "log_level"
    range_key          = "timestamp"
    projection_type    = "INCLUDE"
    non_key_attributes = ["log_id", "service_name", "message"]
    read_capacity      = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity     = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }

  # Global Secondary Index for user-based queries
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user_id"
    range_key       = "timestamp"
    projection_type = "KEYS_ONLY"
    read_capacity   = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity  = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # TTL configuration for automatic data cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = var.enable_ttl
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-log-metadata"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Purpose     = "log-metadata"
  }
}

# DynamoDB table for user session tracking
resource "aws_dynamodb_table" "user_sessions" {
  name             = "${var.project_name}-${var.environment}-user-sessions"
  billing_mode     = var.billing_mode
  hash_key         = "session_id"
  range_key        = "user_id"
  stream_enabled   = var.enable_streams
  stream_view_type = var.enable_streams ? "NEW_AND_OLD_IMAGES" : null

  # Provisioned throughput (only when billing_mode is PROVISIONED)
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Attributes
  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  # Global Secondary Index for user-based session queries
  global_secondary_index {
    name            = "UserSessionIndex"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
    read_capacity   = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity  = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # TTL configuration for session cleanup
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-user-sessions"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Purpose     = "user-sessions"
  }
}

# DynamoDB table for system configuration and feature flags
resource "aws_dynamodb_table" "system_config" {
  name             = "${var.project_name}-${var.environment}-system-config"
  billing_mode     = var.billing_mode
  hash_key         = "config_key"
  stream_enabled   = var.enable_streams
  stream_view_type = var.enable_streams ? "NEW_AND_OLD_IMAGES" : null

  # Provisioned throughput (only when billing_mode is PROVISIONED)
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Attributes
  attribute {
    name = "config_key"
    type = "S"
  }

  attribute {
    name = "environment"
    type = "S"
  }

  # Global Secondary Index for environment-based config queries
  global_secondary_index {
    name            = "EnvironmentIndex"
    hash_key        = "environment"
    projection_type = "ALL"
    read_capacity   = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity  = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-system-config"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Purpose     = "system-config"
  }
}

# DynamoDB table for audit trail and compliance
resource "aws_dynamodb_table" "audit_trail" {
  name             = "${var.project_name}-${var.environment}-audit-trail"
  billing_mode     = var.billing_mode
  hash_key         = "audit_id"
  range_key        = "timestamp"
  stream_enabled   = var.enable_streams
  stream_view_type = var.enable_streams ? "NEW_AND_OLD_IMAGES" : null

  # Provisioned throughput (only when billing_mode is PROVISIONED)
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Attributes
  attribute {
    name = "audit_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "action_type"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  # Global Secondary Index for action type queries
  global_secondary_index {
    name               = "ActionTypeIndex"
    hash_key           = "action_type"
    range_key          = "timestamp"
    projection_type    = "INCLUDE"
    non_key_attributes = ["audit_id", "user_id", "resource_id"]
    read_capacity      = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity     = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }

  # Global Secondary Index for user audit queries
  global_secondary_index {
    name            = "UserAuditIndex"
    hash_key        = "user_id"
    range_key       = "timestamp"
    projection_type = "ALL"
    read_capacity   = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity  = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # TTL configuration for audit data retention
  ttl {
    attribute_name = "retention_date"
    enabled        = var.enable_ttl
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-audit-trail"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Purpose     = "audit-trail"
  }
}

# CloudWatch Alarms for DynamoDB Monitoring
# Requirements: 4.8, 5.6

# Data source for current region
data "aws_region" "current" {}

# SNS topic for DynamoDB alarms (if not provided)
resource "aws_sns_topic" "dynamodb_alarms" {
  count = var.enable_cloudwatch_alarms && var.sns_topic_arn == "" ? 1 : 0

  name              = "${var.project_name}-${var.environment}-dynamodb-alarms"
  display_name      = "DynamoDB Table Alarms"
  kms_master_key_id = aws_kms_key.dynamodb.arn

  tags = {
    Name        = "${var.project_name}-${var.environment}-dynamodb-alarms"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
  }
}

locals {
  sns_topic_arn = var.sns_topic_arn != "" ? var.sns_topic_arn : (var.enable_cloudwatch_alarms ? aws_sns_topic.dynamodb_alarms[0].arn : "")

  # List of all tables for monitoring
  tables = {
    log_metadata  = aws_dynamodb_table.log_metadata
    user_sessions = aws_dynamodb_table.user_sessions
    system_config = aws_dynamodb_table.system_config
    audit_trail   = aws_dynamodb_table.audit_trail
  }
}

# Read Throttle Alarms
resource "aws_cloudwatch_metric_alarm" "read_throttle" {
  for_each = var.enable_cloudwatch_alarms ? local.tables : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-read-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadThrottledEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.read_throttle_threshold
  alarm_description   = "This metric monitors DynamoDB read throttle events for ${each.key}"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-read-throttle-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
  }
}

# Write Throttle Alarms
resource "aws_cloudwatch_metric_alarm" "write_throttle" {
  for_each = var.enable_cloudwatch_alarms ? local.tables : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-write-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteThrottledEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.write_throttle_threshold
  alarm_description   = "This metric monitors DynamoDB write throttle events for ${each.key}"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-write-throttle-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
  }
}

# Consumed Read Capacity Alarms (for provisioned tables)
resource "aws_cloudwatch_metric_alarm" "consumed_read_capacity" {
  for_each = var.enable_cloudwatch_alarms && var.billing_mode == "PROVISIONED" ? local.tables : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-consumed-read-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConsumedReadCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.read_capacity * (var.consumed_read_capacity_threshold / 100)
  alarm_description   = "This metric monitors DynamoDB consumed read capacity for ${each.key}"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-read-capacity-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
  }
}

# Consumed Write Capacity Alarms (for provisioned tables)
resource "aws_cloudwatch_metric_alarm" "consumed_write_capacity" {
  for_each = var.enable_cloudwatch_alarms && var.billing_mode == "PROVISIONED" ? local.tables : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-consumed-write-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConsumedWriteCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.write_capacity * (var.consumed_write_capacity_threshold / 100)
  alarm_description   = "This metric monitors DynamoDB consumed write capacity for ${each.key}"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-write-capacity-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
  }
}

# System Error Alarms
resource "aws_cloudwatch_metric_alarm" "system_errors" {
  for_each = var.enable_cloudwatch_alarms ? local.tables : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-system-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This metric monitors DynamoDB system errors for ${each.key}"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-system-errors-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
  }
}

# User Error Alarms
resource "aws_cloudwatch_metric_alarm" "user_errors" {
  for_each = var.enable_cloudwatch_alarms ? local.tables : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-user-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors DynamoDB user errors for ${each.key}"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-user-errors-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
  }
}

# Auto-scaling configuration (for provisioned billing mode)
resource "aws_appautoscaling_target" "read_target" {
  for_each = var.enable_autoscaling && var.billing_mode == "PROVISIONED" ? local.tables : {}

  max_capacity       = var.autoscaling_max_read_capacity
  min_capacity       = var.autoscaling_min_read_capacity
  resource_id        = "table/${each.value.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-read-autoscaling"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
  }
}

resource "aws_appautoscaling_policy" "read_policy" {
  for_each = var.enable_autoscaling && var.billing_mode == "PROVISIONED" ? local.tables : {}

  name               = "${var.project_name}-${var.environment}-${each.key}-read-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.read_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = var.autoscaling_read_target
  }
}

resource "aws_appautoscaling_target" "write_target" {
  for_each = var.enable_autoscaling && var.billing_mode == "PROVISIONED" ? local.tables : {}

  max_capacity       = var.autoscaling_max_write_capacity
  min_capacity       = var.autoscaling_min_write_capacity
  resource_id        = "table/${each.value.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-write-autoscaling"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
  }
}

resource "aws_appautoscaling_policy" "write_policy" {
  for_each = var.enable_autoscaling && var.billing_mode == "PROVISIONED" ? local.tables : {}

  name               = "${var.project_name}-${var.environment}-${each.key}-write-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.write_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = var.autoscaling_write_target
  }
}

# DynamoDB Backup Monitoring and Alerting
# Requirements: 3.2, 3.5, 5.1

# CloudWatch Alarms for Point-in-Time Recovery Monitoring
resource "aws_cloudwatch_metric_alarm" "backup_lag" {
  for_each = var.enable_cloudwatch_alarms && var.enable_point_in_time_recovery ? local.tables : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-backup-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "PointInTimeRecoveryLag"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Maximum"
  threshold           = 300 # 5 minutes lag threshold
  alarm_description   = "This metric monitors DynamoDB point-in-time recovery lag for ${each.key}"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    TableName = each.value.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-backup-lag-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
    Type        = "backup-monitoring"
  }
}

# CloudWatch Alarms for Backup Storage Usage
resource "aws_cloudwatch_metric_alarm" "backup_storage_usage" {
  for_each = var.enable_cloudwatch_alarms && var.enable_point_in_time_recovery ? local.tables : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-backup-storage-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BackupSizeBytes"
  namespace           = "AWS/DynamoDB"
  period              = "86400" # Daily check
  statistic           = "Maximum"
  threshold           = var.backup_storage_threshold_bytes
  alarm_description   = "This metric monitors DynamoDB backup storage usage for ${each.key}"
  alarm_actions       = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-backup-storage-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Table       = each.key
    Type        = "backup-monitoring"
  }
}

# Lambda function for backup validation and reporting
resource "aws_iam_role" "backup_validator_role" {
  count = var.enable_backup_validation ? 1 : 0

  name = "${var.project_name}-${var.environment}-dynamodb-backup-validator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-dynamodb-backup-validator-role"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Type        = "backup-validation"
  }
}

resource "aws_iam_role_policy" "backup_validator_policy" {
  count = var.enable_backup_validation ? 1 : 0

  name = "${var.project_name}-${var.environment}-dynamodb-backup-validator-policy"
  role = aws_iam_role.backup_validator_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeBackup",
          "dynamodb:ListBackups"
        ]
        Resource = [
          for table in local.tables : table.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = local.sns_topic_arn
      }
    ]
  })
}

# Lambda function for backup validation
resource "aws_lambda_function" "backup_validator" {
  count = var.enable_backup_validation ? 1 : 0

  filename         = data.archive_file.backup_validator_zip[0].output_path
  function_name    = "${var.project_name}-${var.environment}-dynamodb-backup-validator"
  role             = aws_iam_role.backup_validator_role[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.backup_validator_zip[0].output_base64sha256
  runtime          = "python3.9"
  timeout          = 300

  environment {
    variables = {
      TABLE_NAMES   = jsonencode([for k, v in local.tables : v.name])
      SNS_TOPIC_ARN = local.sns_topic_arn
      ENVIRONMENT   = var.environment
      PROJECT_NAME  = var.project_name
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-dynamodb-backup-validator"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Type        = "backup-validation"
  }
}

# Create ZIP file for Lambda deployment using inline source
data "archive_file" "backup_validator_zip" {
  count = var.enable_backup_validation ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/backup_validator.zip"

  source {
    content  = <<EOF
import json
import boto3
import os
from datetime import datetime, timedelta
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.client('dynamodb')
cloudwatch = boto3.client('cloudwatch')
sns = boto3.client('sns')

def handler(event, context):
    table_names = json.loads(os.environ['TABLE_NAMES'])
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    environment = os.environ['ENVIRONMENT']
    project_name = os.environ['PROJECT_NAME']
    
    backup_issues = []
    
    for table_name in table_names:
        try:
            response = dynamodb.describe_continuous_backups(TableName=table_name)
            pitr_status = response['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus']
            
            if pitr_status != 'ENABLED':
                backup_issues.append(f"Point-in-time recovery is {pitr_status} for table {table_name}")
                continue
            
            earliest_restorable_time = response['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['EarliestRestorableDateTime']
            latest_restorable_time = response['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['LatestRestorableDateTime']
            
            current_time = datetime.now(latest_restorable_time.tzinfo)
            backup_lag = (current_time - latest_restorable_time).total_seconds()
            
            cloudwatch.put_metric_data(
                Namespace='DynamoDB/BackupMonitoring',
                MetricData=[{
                    'MetricName': 'BackupLagSeconds',
                    'Dimensions': [
                        {'Name': 'TableName', 'Value': table_name},
                        {'Name': 'Environment', 'Value': environment}
                    ],
                    'Value': backup_lag,
                    'Unit': 'Seconds',
                    'Timestamp': current_time
                }]
            )
            
            if backup_lag > 300:
                backup_issues.append(f"High backup lag ({backup_lag:.0f} seconds) for table {table_name}")
            
            logger.info(f"Backup validation successful for table {table_name}")
            
        except Exception as e:
            backup_issues.append(f"Error validating backups for table {table_name}: {str(e)}")
            logger.error(f"Error validating backups for table {table_name}: {str(e)}")
    
    if backup_issues:
        message = f"DynamoDB Backup Issues Detected in {environment} environment:\n\n"
        message += "\n".join(f"- {issue}" for issue in backup_issues)
        
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject=f"DynamoDB Backup Issues - {project_name} {environment}",
            Message=message
        )
        
        return {'statusCode': 200, 'body': json.dumps({'status': 'issues_found', 'issues': backup_issues})}
    
    return {'statusCode': 200, 'body': json.dumps({'status': 'success', 'message': 'All backup validations passed'})}
EOF
    filename = "index.py"
  }
}

# CloudWatch Event Rule for scheduled backup validation
resource "aws_cloudwatch_event_rule" "backup_validation_schedule" {
  count = var.enable_backup_validation ? 1 : 0

  name                = "${var.project_name}-${var.environment}-dynamodb-backup-validation"
  description         = "Trigger DynamoDB backup validation"
  schedule_expression = var.backup_validation_schedule

  tags = {
    Name        = "${var.project_name}-${var.environment}-dynamodb-backup-validation"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Type        = "backup-validation"
  }
}

resource "aws_cloudwatch_event_target" "backup_validation_target" {
  count = var.enable_backup_validation ? 1 : 0

  rule      = aws_cloudwatch_event_rule.backup_validation_schedule[0].name
  target_id = "DynamoDBBackupValidationTarget"
  arn       = aws_lambda_function.backup_validator[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_backup_validation" {
  count = var.enable_backup_validation ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_validator[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_validation_schedule[0].arn
}

# CloudWatch Log Group for backup validator Lambda
resource "aws_cloudwatch_log_group" "backup_validator_logs" {
  count = var.enable_backup_validation ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.backup_validator[0].function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-dynamodb-backup-validator-logs"
    Environment = var.environment
    Project     = var.project_name
    Service     = "dynamodb"
    Type        = "backup-validation"
  }
}

# Additional tables for streaming platform
resource "aws_dynamodb_table" "connections" {
  name         = "${var.project_name}-${var.environment}-connections"
  billing_mode = var.billing_mode
  hash_key     = "connection_id"

  attribute {
    name = "connection_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-connections"
  }
}

resource "aws_dynamodb_table" "messages" {
  name         = "${var.project_name}-${var.environment}-messages"
  billing_mode = var.billing_mode
  hash_key     = "stream_id"
  range_key    = "timestamp"

  attribute {
    name = "stream_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-messages"
  }
}

resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-${var.environment}-users"
  billing_mode = var.billing_mode
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-users"
  }
}

resource "aws_dynamodb_table" "streams" {
  name         = "${var.project_name}-${var.environment}-streams"
  billing_mode = var.billing_mode
  hash_key     = "stream_id"

  attribute {
    name = "stream_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    projection_type = "ALL"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-streams"
  }
}