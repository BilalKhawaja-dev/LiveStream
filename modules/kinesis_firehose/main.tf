# Kinesis Data Firehose Module for Centralized Logging Infrastructure

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Data source for current AWS region
data "aws_region" "current" {}

# IAM Role for Kinesis Firehose
resource "aws_iam_role" "firehose_delivery_role" {
  name = "${var.project_name}-firehose-delivery-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-firehose-delivery-role-${var.environment}"
  })
}

# IAM Policy for Firehose S3 Delivery
resource "aws_iam_role_policy" "firehose_delivery_policy" {
  name = "${var.project_name}-firehose-delivery-policy-${var.environment}"
  role = aws_iam_role.firehose_delivery_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*",
          var.s3_error_bucket_arn,
          "${var.s3_error_bucket_arn}/*"
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
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/*"
        ]
      }
    ]
  })
}

# Kinesis Firehose Delivery Stream for Streaming Logs
resource "aws_kinesis_firehose_delivery_stream" "streaming_logs" {
  name        = "${var.project_name}-streaming-logs-${var.environment}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_delivery_role.arn
    bucket_arn         = var.s3_bucket_arn
    buffering_size     = var.buffer_size
    buffering_interval = var.buffer_interval
    compression_format = var.compression_format

    # Partitioning by service and date for efficient querying
    prefix              = "logs/service=streaming/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/streaming/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.project_name}-streaming-logs-${var.environment}"
      log_stream_name = "S3Delivery"
    }
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-streaming-logs-firehose-${var.environment}"
    Service = "Firehose"
    Purpose = "Streaming logs delivery to S3"
  })
}

# Kinesis Firehose Delivery Stream for Application Logs
resource "aws_kinesis_firehose_delivery_stream" "application_logs" {
  name        = "${var.project_name}-application-logs-${var.environment}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_delivery_role.arn
    bucket_arn         = var.s3_bucket_arn
    buffering_size     = var.buffer_size
    buffering_interval = var.buffer_interval
    compression_format = var.compression_format

    # Partitioning by service and date
    prefix              = "logs/service=application/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/application/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.project_name}-application-logs-${var.environment}"
      log_stream_name = "S3Delivery"
    }
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-application-logs-firehose-${var.environment}"
    Service = "Firehose"
    Purpose = "Application logs delivery to S3"
  })
}

# Kinesis Firehose Delivery Stream for Infrastructure Logs
resource "aws_kinesis_firehose_delivery_stream" "infrastructure_logs" {
  name        = "${var.project_name}-infrastructure-logs-${var.environment}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_delivery_role.arn
    bucket_arn         = var.s3_bucket_arn
    buffering_size     = var.buffer_size
    buffering_interval = var.buffer_interval
    compression_format = var.compression_format

    # Partitioning by service and date
    prefix              = "logs/service=infrastructure/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/infrastructure/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.project_name}-infrastructure-logs-${var.environment}"
      log_stream_name = "S3Delivery"
    }
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-infrastructure-logs-firehose-${var.environment}"
    Service = "Firehose"
    Purpose = "Infrastructure logs delivery to S3"
  })
}

# CloudWatch Log Groups for Firehose
resource "aws_cloudwatch_log_group" "firehose_streaming_logs" {
  name              = "/aws/kinesisfirehose/${var.project_name}-streaming-logs-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-firehose-streaming-logs-${var.environment}"
  })
}

resource "aws_cloudwatch_log_group" "firehose_application_logs" {
  name              = "/aws/kinesisfirehose/${var.project_name}-application-logs-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-firehose-application-logs-${var.environment}"
  })
}

resource "aws_cloudwatch_log_group" "firehose_infrastructure_logs" {
  name              = "/aws/kinesisfirehose/${var.project_name}-infrastructure-logs-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-firehose-infrastructure-logs-${var.environment}"
  })
}

# Enhanced Firehose Delivery Stream with Data Transformation
resource "aws_kinesis_firehose_delivery_stream" "enhanced_streaming_logs" {
  name        = "${var.project_name}-enhanced-streaming-logs-${var.environment}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_delivery_role.arn
    bucket_arn         = var.s3_bucket_arn
    buffering_size     = var.buffer_size
    buffering_interval = var.buffer_interval
    compression_format = var.compression_format

    # Enhanced partitioning for Athena optimization
    prefix              = "enhanced-logs/service=streaming/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/enhanced-streaming/"

    # Data format conversion for Athena
    data_format_conversion_configuration {
      enabled = var.enable_data_format_conversion

      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {}
        }
      }

      schema_configuration {
        database_name = var.glue_database_name
        table_name    = var.glue_table_name
        role_arn      = aws_iam_role.firehose_delivery_role.arn
      }
    }

    # Processing configuration for data transformation
    processing_configuration {
      enabled = var.enable_data_processing

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = var.data_transformation_lambda_arn
        }
      }
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.project_name}-enhanced-streaming-logs-${var.environment}"
      log_stream_name = "S3Delivery"
    }

    # S3 backup configuration for failed records
    s3_backup_mode = "Enabled"

    s3_backup_configuration {
      role_arn           = aws_iam_role.firehose_delivery_role.arn
      bucket_arn         = var.s3_error_bucket_arn
      buffering_size     = 5
      buffering_interval = 300
      compression_format = "GZIP"
      prefix             = "backup/streaming/"

      cloudwatch_logging_options {
        enabled         = true
        log_group_name  = "/aws/kinesisfirehose/${var.project_name}-enhanced-streaming-logs-${var.environment}"
        log_stream_name = "S3BackupDelivery"
      }
    }
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-enhanced-streaming-logs-firehose-${var.environment}"
    Service = "Firehose"
    Purpose = "Enhanced streaming logs delivery with transformation"
  })
}

# Enhanced IAM Policy for Glue and Lambda Integration
resource "aws_iam_role_policy" "firehose_enhanced_policy" {
  name = "${var.project_name}-firehose-enhanced-policy-${var.environment}"
  role = aws_iam_role.firehose_delivery_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetTableVersion",
          "glue:GetTableVersions"
        ]
        Resource = [
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${var.glue_database_name}",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/${var.glue_table_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = [
          var.data_transformation_lambda_arn
        ]
      }
    ]
  })
}

# CloudWatch Log Group for Enhanced Firehose
resource "aws_cloudwatch_log_group" "firehose_enhanced_streaming_logs" {
  name              = "/aws/kinesisfirehose/${var.project_name}-enhanced-streaming-logs-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-firehose-enhanced-streaming-logs-${var.environment}"
  })
}

# CloudWatch Alarms for Firehose Monitoring
resource "aws_cloudwatch_metric_alarm" "firehose_delivery_errors" {
  count               = var.enable_firehose_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-firehose-delivery-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DeliveryToS3.Records"
  namespace           = "AWS/KinesisFirehose"
  period              = 300
  statistic           = "Sum"
  threshold           = var.firehose_error_threshold
  alarm_description   = "This metric monitors Firehose delivery errors"

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.streaming_logs.name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-firehose-delivery-errors-alarm-${var.environment}"
  })
}

resource "aws_cloudwatch_metric_alarm" "firehose_delivery_success" {
  count               = var.enable_firehose_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-firehose-delivery-success-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DeliveryToS3.Success"
  namespace           = "AWS/KinesisFirehose"
  period              = 300
  statistic           = "Average"
  threshold           = 0.95
  alarm_description   = "This metric monitors Firehose delivery success rate"

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.streaming_logs.name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-firehose-delivery-success-alarm-${var.environment}"
  })
}