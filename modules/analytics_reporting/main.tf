# Analytics and Reporting Module - Comprehensive analytics and business intelligence

# S3 bucket for analytics data storage
resource "aws_s3_bucket" "analytics_data" {
  bucket = "${var.project_name}-${var.environment}-analytics-data"
  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "s3-bucket"
  })
}

resource "aws_s3_bucket_versioning" "analytics_data_versioning" {
  bucket = aws_s3_bucket.analytics_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analytics_data_encryption" {
  bucket = aws_s3_bucket.analytics_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "analytics_data_lifecycle" {
  bucket = aws_s3_bucket.analytics_data.id

  rule {
    id     = "analytics_data_lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555 # 7 years retention
    }
  }
}

# Athena workgroup for analytics queries
resource "aws_athena_workgroup" "analytics_workgroup" {
  name = "${var.project_name}-${var.environment}-analytics"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.analytics_data.bucket}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "athena-workgroup"
  })
}

# Athena database for analytics
resource "aws_athena_database" "analytics_database" {
  name   = "${var.project_name}_${var.environment}_analytics"
  bucket = aws_s3_bucket.analytics_data.bucket
}

# Lambda function for analytics data processing
resource "aws_lambda_function" "analytics_processor" {
  filename         = data.archive_file.analytics_processor.output_path
  function_name    = "${var.project_name}-${var.environment}-analytics-processor"
  role             = aws_iam_role.analytics_processor_role.arn
  handler          = "analytics_processor.lambda_handler"
  runtime          = "python3.9"
  timeout          = 900
  memory_size      = 1024
  source_code_hash = data.archive_file.analytics_processor.output_base64sha256

  environment {
    variables = {
      ANALYTICS_BUCKET   = aws_s3_bucket.analytics_data.bucket
      ATHENA_WORKGROUP   = aws_athena_workgroup.analytics_workgroup.name
      ATHENA_DATABASE    = aws_athena_database.analytics_database.name
      AURORA_CLUSTER_ARN = var.aurora_cluster_arn
      AURORA_SECRET_ARN  = var.aurora_secret_arn
    }
  }

  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "lambda-function"
  })
}

# Lambda function for report generation
resource "aws_lambda_function" "report_generator" {
  filename         = data.archive_file.report_generator.output_path
  function_name    = "${var.project_name}-${var.environment}-report-generator"
  role             = aws_iam_role.report_generator_role.arn
  handler          = "report_generator.lambda_handler"
  runtime          = "python3.9"
  timeout          = 900
  memory_size      = 1024
  source_code_hash = data.archive_file.report_generator.output_base64sha256

  environment {
    variables = {
      ANALYTICS_BUCKET   = aws_s3_bucket.analytics_data.bucket
      ATHENA_WORKGROUP   = aws_athena_workgroup.analytics_workgroup.name
      ATHENA_DATABASE    = aws_athena_database.analytics_database.name
      AURORA_CLUSTER_ARN = var.aurora_cluster_arn
      AURORA_SECRET_ARN  = var.aurora_secret_arn
      REPORTS_BUCKET     = aws_s3_bucket.analytics_data.bucket
    }
  }

  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "lambda-function"
  })
}

# Lambda function for real-time analytics API
resource "aws_lambda_function" "analytics_api" {
  filename         = data.archive_file.analytics_api.output_path
  function_name    = "${var.project_name}-${var.environment}-analytics-api"
  role             = aws_iam_role.analytics_api_role.arn
  handler          = "analytics_api.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 512
  source_code_hash = data.archive_file.analytics_api.output_base64sha256

  environment {
    variables = {
      ANALYTICS_BUCKET   = aws_s3_bucket.analytics_data.bucket
      ATHENA_WORKGROUP   = aws_athena_workgroup.analytics_workgroup.name
      ATHENA_DATABASE    = aws_athena_database.analytics_database.name
      AURORA_CLUSTER_ARN = var.aurora_cluster_arn
      AURORA_SECRET_ARN  = var.aurora_secret_arn
    }
  }

  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "lambda-function"
  })
}

# EventBridge rules for scheduled analytics processing
resource "aws_cloudwatch_event_rule" "hourly_analytics" {
  name                = "${var.project_name}-${var.environment}-hourly-analytics"
  description         = "Trigger hourly analytics processing"
  schedule_expression = "rate(1 hour)"
  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "eventbridge-rule"
  })
}

resource "aws_cloudwatch_event_target" "hourly_analytics_target" {
  rule      = aws_cloudwatch_event_rule.hourly_analytics.name
  target_id = "HourlyAnalyticsTarget"
  arn       = aws_lambda_function.analytics_processor.arn
  input = jsonencode({
    "action" = "hourly_processing"
  })
}

resource "aws_lambda_permission" "allow_eventbridge_hourly_analytics" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly_analytics.arn
}

resource "aws_cloudwatch_event_rule" "daily_reports" {
  name                = "${var.project_name}-${var.environment}-daily-reports"
  description         = "Trigger daily report generation"
  schedule_expression = "cron(0 6 * * ? *)" # 6 AM UTC daily
  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "eventbridge-rule"
  })
}

resource "aws_cloudwatch_event_target" "daily_reports_target" {
  rule      = aws_cloudwatch_event_rule.daily_reports.name
  target_id = "DailyReportsTarget"
  arn       = aws_lambda_function.report_generator.arn
  input = jsonencode({
    "action" = "daily_report"
  })
}

resource "aws_lambda_permission" "allow_eventbridge_daily_reports" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_reports.arn
}

# IAM roles and policies
resource "aws_iam_role" "analytics_processor_role" {
  name = "${var.project_name}-${var.environment}-analytics-processor-role"

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

  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "iam-role"
  })
}

resource "aws_iam_role_policy" "analytics_processor_policy" {
  name = "${var.project_name}-${var.environment}-analytics-processor-policy"
  role = aws_iam_role.analytics_processor_role.id

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
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.analytics_data.arn,
          "${aws_s3_bucket.analytics_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:UpdateTable"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.aurora_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "report_generator_role" {
  name = "${var.project_name}-${var.environment}-report-generator-role"

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

  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "iam-role"
  })
}

resource "aws_iam_role_policy" "report_generator_policy" {
  name = "${var.project_name}-${var.environment}-report-generator-policy"
  role = aws_iam_role.report_generator_role.id

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
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.analytics_data.arn,
          "${aws_s3_bucket.analytics_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.aurora_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "analytics_api_role" {
  name = "${var.project_name}-${var.environment}-analytics-api-role"

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

  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "iam-role"
  })
}

resource "aws_iam_role_policy" "analytics_api_policy" {
  name = "${var.project_name}-${var.environment}-analytics-api-policy"
  role = aws_iam_role.analytics_api_role.id

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
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.analytics_data.arn,
          "${aws_s3_bucket.analytics_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.aurora_secret_arn
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "analytics_processor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.analytics_processor.function_name}"
  retention_in_days = 7
  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "log-group"
  })
}

resource "aws_cloudwatch_log_group" "report_generator_logs" {
  name              = "/aws/lambda/${aws_lambda_function.report_generator.function_name}"
  retention_in_days = 7
  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "log-group"
  })
}

resource "aws_cloudwatch_log_group" "analytics_api_logs" {
  name              = "/aws/lambda/${aws_lambda_function.analytics_api.function_name}"
  retention_in_days = 7
  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "log-group"
  })
}

# CloudWatch custom metrics and alarms
resource "aws_cloudwatch_metric_alarm" "analytics_processing_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-analytics-processing-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors analytics processing errors"
  alarm_actions       = var.alarm_topic_arn != "" ? [var.alarm_topic_arn] : []

  dimensions = {
    FunctionName = aws_lambda_function.analytics_processor.function_name
  }

  tags = merge(var.tags, {
    Service = "analytics-reporting"
    Type    = "cloudwatch-alarm"
  })
}

# Data sources for Lambda deployment packages
data "archive_file" "analytics_processor" {
  type        = "zip"
  output_path = "${path.module}/analytics_processor.zip"
  source_file = "${path.module}/functions/analytics_processor.py"
}

data "archive_file" "report_generator" {
  type        = "zip"
  output_path = "${path.module}/report_generator.zip"
  source_file = "${path.module}/functions/report_generator.py"
}

data "archive_file" "analytics_api" {
  type        = "zip"
  output_path = "${path.module}/analytics_api.zip"
  source_file = "${path.module}/functions/analytics_api.py"
}