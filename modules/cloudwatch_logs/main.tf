# CloudWatch Logs Module for Centralized Logging Infrastructure

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Data source for current AWS region
data "aws_region" "current" {}

# CloudWatch Log Group for MediaLive Service
resource "aws_cloudwatch_log_group" "medialive" {
  name              = "/aws/medialive/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name    = "${var.project_name}-medialive-logs-${var.environment}"
    Service = "MediaLive"
    Purpose = "Live streaming service logs"
  })
}

# CloudWatch Log Group for MediaStore Service
resource "aws_cloudwatch_log_group" "mediastore" {
  name              = "/aws/mediastore/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name    = "${var.project_name}-mediastore-logs-${var.environment}"
    Service = "MediaStore"
    Purpose = "Media storage service logs"
  })
}

# CloudWatch Log Group for ECS Service
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name    = "${var.project_name}-ecs-logs-${var.environment}"
    Service = "ECS"
    Purpose = "Container service logs"
  })
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name    = "${var.project_name}-apigateway-logs-${var.environment}"
    Service = "APIGateway"
    Purpose = "API Gateway access and execution logs"
  })
}

# CloudWatch Log Group for Cognito Service
resource "aws_cloudwatch_log_group" "cognito" {
  name              = "/aws/cognito/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name    = "${var.project_name}-cognito-logs-${var.environment}"
    Service = "Cognito"
    Purpose = "User authentication and authorization logs"
  })
}

# CloudWatch Log Group for Payment Service
resource "aws_cloudwatch_log_group" "payment" {
  name              = "/aws/lambda/${var.project_name}-payment-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name    = "${var.project_name}-payment-logs-${var.environment}"
    Service = "Payment"
    Purpose = "Payment processing service logs"
  })
}

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/application/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name    = "${var.project_name}-application-logs-${var.environment}"
    Service = "Application"
    Purpose = "General application logs"
  })
}

# CloudWatch Log Group for Infrastructure Logs
resource "aws_cloudwatch_log_group" "infrastructure" {
  name              = "/aws/infrastructure/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name    = "${var.project_name}-infrastructure-logs-${var.environment}"
    Service = "Infrastructure"
    Purpose = "Infrastructure and system logs"
  })
}

# IAM Role for CloudWatch Logs
resource "aws_iam_role" "cloudwatch_logs_role" {
  name = "${var.project_name}-cloudwatch-logs-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "logs.amazonaws.com",
            "firehose.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-cloudwatch-logs-role-${var.environment}"
  })
}

# IAM Policy for CloudWatch Logs
resource "aws_iam_role_policy" "cloudwatch_logs_policy" {
  name = "${var.project_name}-cloudwatch-logs-policy-${var.environment}"
  role = aws_iam_role.cloudwatch_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [
          var.kms_key_arn
        ]
      }
    ]
  })
}

# IAM Role for Services to Write to CloudWatch Logs
resource "aws_iam_role" "service_logs_role" {
  name = "${var.project_name}-service-logs-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "medialive.amazonaws.com",
            "mediastore.amazonaws.com",
            "ecs-tasks.amazonaws.com",
            "apigateway.amazonaws.com",
            "cognito-idp.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-service-logs-role-${var.environment}"
  })
}

# IAM Policy for Services to Write Logs
resource "aws_iam_role_policy" "service_logs_policy" {
  name = "${var.project_name}-service-logs-policy-${var.environment}"
  role = aws_iam_role.service_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.medialive.arn,
          aws_cloudwatch_log_group.mediastore.arn,
          aws_cloudwatch_log_group.ecs.arn,
          aws_cloudwatch_log_group.api_gateway.arn,
          aws_cloudwatch_log_group.cognito.arn,
          aws_cloudwatch_log_group.payment.arn,
          aws_cloudwatch_log_group.application.arn,
          aws_cloudwatch_log_group.infrastructure.arn,
          "${aws_cloudwatch_log_group.medialive.arn}:*",
          "${aws_cloudwatch_log_group.mediastore.arn}:*",
          "${aws_cloudwatch_log_group.ecs.arn}:*",
          "${aws_cloudwatch_log_group.api_gateway.arn}:*",
          "${aws_cloudwatch_log_group.cognito.arn}:*",
          "${aws_cloudwatch_log_group.payment.arn}:*",
          "${aws_cloudwatch_log_group.application.arn}:*",
          "${aws_cloudwatch_log_group.infrastructure.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [
          var.kms_key_arn
        ]
      }
    ]
  })
}

# CloudWatch Logs Subscription Filters

# Subscription Filter for MediaLive Logs
resource "aws_cloudwatch_log_subscription_filter" "medialive_filter" {
  count           = var.enable_subscription_filters ? 1 : 0
  name            = "${var.project_name}-medialive-filter-${var.environment}"
  log_group_name  = aws_cloudwatch_log_group.medialive.name
  filter_pattern  = var.medialive_filter_pattern
  destination_arn = var.firehose_delivery_stream_arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn

  depends_on = [aws_iam_role_policy.cloudwatch_logs_policy]
}

# Subscription Filter for MediaStore Logs
resource "aws_cloudwatch_log_subscription_filter" "mediastore_filter" {
  count           = var.enable_subscription_filters ? 1 : 0
  name            = "${var.project_name}-mediastore-filter-${var.environment}"
  log_group_name  = aws_cloudwatch_log_group.mediastore.name
  filter_pattern  = var.mediastore_filter_pattern
  destination_arn = var.firehose_delivery_stream_arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn

  depends_on = [aws_iam_role_policy.cloudwatch_logs_policy]
}

# Subscription Filter for ECS Logs
resource "aws_cloudwatch_log_subscription_filter" "ecs_filter" {
  count           = var.enable_subscription_filters ? 1 : 0
  name            = "${var.project_name}-ecs-filter-${var.environment}"
  log_group_name  = aws_cloudwatch_log_group.ecs.name
  filter_pattern  = var.ecs_filter_pattern
  destination_arn = var.firehose_delivery_stream_arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn

  depends_on = [aws_iam_role_policy.cloudwatch_logs_policy]
}

# Subscription Filter for API Gateway Logs
resource "aws_cloudwatch_log_subscription_filter" "api_gateway_filter" {
  count           = var.enable_subscription_filters ? 1 : 0
  name            = "${var.project_name}-apigateway-filter-${var.environment}"
  log_group_name  = aws_cloudwatch_log_group.api_gateway.name
  filter_pattern  = var.api_gateway_filter_pattern
  destination_arn = var.firehose_delivery_stream_arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn

  depends_on = [aws_iam_role_policy.cloudwatch_logs_policy]
}

# Subscription Filter for Cognito Logs
resource "aws_cloudwatch_log_subscription_filter" "cognito_filter" {
  count           = var.enable_subscription_filters ? 1 : 0
  name            = "${var.project_name}-cognito-filter-${var.environment}"
  log_group_name  = aws_cloudwatch_log_group.cognito.name
  filter_pattern  = var.cognito_filter_pattern
  destination_arn = var.firehose_delivery_stream_arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn

  depends_on = [aws_iam_role_policy.cloudwatch_logs_policy]
}

# Subscription Filter for Payment Logs
resource "aws_cloudwatch_log_subscription_filter" "payment_filter" {
  count           = var.enable_subscription_filters ? 1 : 0
  name            = "${var.project_name}-payment-filter-${var.environment}"
  log_group_name  = aws_cloudwatch_log_group.payment.name
  filter_pattern  = var.payment_filter_pattern
  destination_arn = var.firehose_delivery_stream_arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn

  depends_on = [aws_iam_role_policy.cloudwatch_logs_policy]
}

# Subscription Filter for Application Logs
resource "aws_cloudwatch_log_subscription_filter" "application_filter" {
  count           = var.enable_subscription_filters ? 1 : 0
  name            = "${var.project_name}-application-filter-${var.environment}"
  log_group_name  = aws_cloudwatch_log_group.application.name
  filter_pattern  = var.application_filter_pattern
  destination_arn = var.firehose_delivery_stream_arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn

  depends_on = [aws_iam_role_policy.cloudwatch_logs_policy]
}

# Subscription Filter for Infrastructure Logs
resource "aws_cloudwatch_log_subscription_filter" "infrastructure_filter" {
  count           = var.enable_subscription_filters ? 1 : 0
  name            = "${var.project_name}-infrastructure-filter-${var.environment}"
  log_group_name  = aws_cloudwatch_log_group.infrastructure.name
  filter_pattern  = var.infrastructure_filter_pattern
  destination_arn = var.firehose_delivery_stream_arn
  role_arn        = aws_iam_role.cloudwatch_logs_role.arn

  depends_on = [aws_iam_role_policy.cloudwatch_logs_policy]
}

# Enhanced IAM Policy for Firehose Integration
resource "aws_iam_role_policy" "firehose_integration_policy" {
  name = "${var.project_name}-firehose-integration-policy-${var.environment}"
  role = aws_iam_role.cloudwatch_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = [
          var.firehose_delivery_stream_arn
        ]
      }
    ]
  })
}

# CloudWatch Alarms for Log Monitoring

# SNS Topic for Log Alerts
resource "aws_sns_topic" "log_alerts" {
  name         = "${var.project_name}-log-alerts-${var.environment}"
  display_name = "Log Monitoring Alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-log-alerts-${var.environment}"
  })
}

# CloudWatch Alarm for High Error Rate
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-high-error-rate-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ErrorCount"
  namespace           = "AWS/Logs"
  period              = 300
  statistic           = "Sum"
  threshold           = var.error_rate_threshold
  alarm_description   = "This metric monitors error rate in logs"
  alarm_actions       = [aws_sns_topic.log_alerts.arn]
  ok_actions          = [aws_sns_topic.log_alerts.arn]

  dimensions = {
    LogGroupName = aws_cloudwatch_log_group.application.name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-high-error-rate-alarm-${var.environment}"
  })
}

# CloudWatch Alarm for Log Volume Spike
resource "aws_cloudwatch_metric_alarm" "log_volume_spike" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-log-volume-spike-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "IncomingLogEvents"
  namespace           = "AWS/Logs"
  period              = 300
  statistic           = "Sum"
  threshold           = var.log_volume_threshold
  alarm_description   = "This metric monitors log volume spikes"
  alarm_actions       = [aws_sns_topic.log_alerts.arn]
  ok_actions          = [aws_sns_topic.log_alerts.arn]

  dimensions = {
    LogGroupName = aws_cloudwatch_log_group.application.name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-log-volume-spike-alarm-${var.environment}"
  })
}

# CloudWatch Alarm for Payment Service Errors
resource "aws_cloudwatch_metric_alarm" "payment_errors" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-payment-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ErrorCount"
  namespace           = "AWS/Logs"
  period              = 300
  statistic           = "Sum"
  threshold           = var.payment_error_threshold
  alarm_description   = "This metric monitors payment service errors"
  alarm_actions       = [aws_sns_topic.log_alerts.arn]
  ok_actions          = [aws_sns_topic.log_alerts.arn]

  dimensions = {
    LogGroupName = aws_cloudwatch_log_group.payment.name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-payment-errors-alarm-${var.environment}"
  })
}

# CloudWatch Alarm for API Gateway 4xx Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-api-gateway-4xx-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = var.api_4xx_threshold
  alarm_description   = "This metric monitors API Gateway 4xx errors"
  alarm_actions       = [aws_sns_topic.log_alerts.arn]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-gateway-4xx-alarm-${var.environment}"
  })
}

# CloudWatch Alarm for API Gateway 5xx Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-api-gateway-5xx-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = var.api_5xx_threshold
  alarm_description   = "This metric monitors API Gateway 5xx errors"
  alarm_actions       = [aws_sns_topic.log_alerts.arn]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-gateway-5xx-alarm-${var.environment}"
  })
}

# CloudWatch Alarm for MediaLive Channel Errors
resource "aws_cloudwatch_metric_alarm" "medialive_errors" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-medialive-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ErrorCount"
  namespace           = "AWS/Logs"
  period              = 300
  statistic           = "Sum"
  threshold           = var.medialive_error_threshold
  alarm_description   = "This metric monitors MediaLive service errors"
  alarm_actions       = [aws_sns_topic.log_alerts.arn]

  dimensions = {
    LogGroupName = aws_cloudwatch_log_group.medialive.name
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-medialive-errors-alarm-${var.environment}"
  })
}