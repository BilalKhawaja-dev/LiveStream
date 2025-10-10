# Athena Module - Workgroup and query optimization configuration
# This module creates Athena workgroups with cost controls and query optimization

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for resource naming and configuration
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Naming convention: {project}-{component}-{environment}
  workgroup_name = "${var.project_name}-${var.environment}"
  
  # Development environment optimizations
  dev_optimizations = var.environment == "dev" ? {
    bytes_scanned_cutoff_per_query = 1073741824  # 1GB limit for dev
    enforce_workgroup_configuration = true
    publish_cloudwatch_metrics     = false       # Disabled for cost optimization
    result_configuration_encryption_option = "SSE_S3"  # Standard encryption for dev
  } : {
    bytes_scanned_cutoff_per_query = 10737418240 # 10GB limit for prod
    enforce_workgroup_configuration = true
    publish_cloudwatch_metrics     = true
    result_configuration_encryption_option = "SSE_KMS"
  }
}

# IAM role for Athena workgroup
resource "aws_iam_role" "athena_workgroup_role" {
  name = "${local.workgroup_name}-athena-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for Athena workgroup
resource "aws_iam_role_policy" "athena_workgroup_policy" {
  name = "${local.workgroup_name}-athena-policy"
  role = aws_iam_role.athena_workgroup_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          var.athena_results_bucket_arn,
          "${var.athena_results_bucket_arn}/*",
          var.s3_logs_bucket_arn,
          "${var.s3_logs_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:BatchUpdatePartition"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:catalog",
          "arn:aws:glue:${local.region}:${local.account_id}:database/${var.glue_database_name}",
          "arn:aws:glue:${local.region}:${local.account_id}:table/${var.glue_database_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          var.kms_key_arn
        ]
      }
    ]
  })
}

# Athena workgroup with development-optimized settings
resource "aws_athena_workgroup" "streaming_logs" {
  name = local.workgroup_name

  configuration {
    # Query result location
    result_configuration {
      output_location = "s3://${var.athena_results_bucket_name}/workgroup-results/"
      
      # Encryption configuration - S3 encryption for all environments
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    # Cost controls and query limits
    bytes_scanned_cutoff_per_query  = local.dev_optimizations.bytes_scanned_cutoff_per_query
    enforce_workgroup_configuration = local.dev_optimizations.enforce_workgroup_configuration
  }

  description = "Athena workgroup for ${var.project_name} ${var.environment} environment with cost controls"
  state       = "ENABLED"

  tags = merge(var.tags, {
    Name        = local.workgroup_name
    Component   = "athena"
    CostControl = "enabled"
  })
}

# Athena database (references existing Glue database)
resource "aws_athena_database" "streaming_logs" {
  name   = var.glue_database_name
  bucket = var.athena_results_bucket_name

  # Force creation to ensure database exists in Athena context
  force_destroy = var.environment == "dev" ? true : false

  # Encryption configuration for query results - S3 encryption for compatibility
  encryption_configuration {
    encryption_option = "SSE_S3"
  }
}

# CloudWatch Log Group for Athena query logs (development environment)
resource "aws_cloudwatch_log_group" "athena_query_logs" {
  count = var.environment == "dev" && var.enable_query_logging ? 1 : 0
  
  name              = "/aws/athena/${local.workgroup_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name      = "${local.workgroup_name}-query-logs"
    Component = "athena"
  })
}

# S3 bucket lifecycle policy for Athena query results
resource "aws_s3_bucket_lifecycle_configuration" "athena_results_lifecycle" {
  bucket = var.athena_results_bucket_name

  rule {
    id     = "athena-query-results-lifecycle"
    status = "Enabled"

    # Apply to workgroup results
    filter {
      prefix = "workgroup-results/"
    }

    # Development environment: shorter retention for cost optimization
    expiration {
      days = var.athena_results_retention_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }

    # Non-current version expiration (if versioning is enabled)
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  # Rule for general query results cleanup
  rule {
    id     = "general-query-results-cleanup"
    status = "Enabled"

    filter {
      prefix = "query-results/"
    }

    expiration {
      days = var.athena_results_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_athena_workgroup.streaming_logs]
}

# CloudWatch alarm for query cost monitoring (development environment)
resource "aws_cloudwatch_metric_alarm" "athena_data_scanned" {
  count = var.environment == "dev" && var.enable_cost_monitoring ? 1 : 0

  alarm_name          = "${local.workgroup_name}-data-scanned-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DataScannedInBytes"
  namespace           = "AWS/Athena"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.data_scanned_alarm_threshold
  alarm_description   = "This metric monitors Athena data scanned for cost control"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    WorkGroup = aws_athena_workgroup.streaming_logs.name
  }

  tags = var.tags
}

# CloudWatch alarm for query execution time monitoring
resource "aws_cloudwatch_metric_alarm" "athena_query_execution_time" {
  count = var.environment == "dev" && var.enable_performance_monitoring ? 1 : 0

  alarm_name          = "${local.workgroup_name}-query-execution-time-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "QueryExecutionTime"
  namespace           = "AWS/Athena"
  period              = "300"
  statistic           = "Average"
  threshold           = var.query_execution_time_threshold
  alarm_description   = "This metric monitors Athena query execution time for performance optimization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    WorkGroup = aws_athena_workgroup.streaming_logs.name
  }

  tags = var.tags
}