# Streaming Quality Management Module
# This module manages subscription-based quality tiers and adaptive streaming

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Lambda function for quality tier enforcement
resource "aws_lambda_function" "quality_manager" {
  filename      = "${path.module}/functions/quality_manager.zip"
  function_name = "${var.project_name}-${var.environment}-quality-manager"
  role          = aws_iam_role.quality_manager.arn
  handler       = "quality_manager.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      AURORA_CLUSTER_ARN         = var.aurora_cluster_arn
      AURORA_SECRET_ARN          = var.aurora_secret_arn
      DYNAMODB_ANALYTICS_TABLE   = var.dynamodb_analytics_table
      CLOUDFRONT_DISTRIBUTION_ID = var.cloudfront_distribution_id
      ENVIRONMENT                = var.environment
      LOG_LEVEL                  = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.quality_manager_basic,
    aws_cloudwatch_log_group.quality_manager,
    data.archive_file.quality_manager
  ]

  tags = var.tags
}

# Archive file for quality manager
data "archive_file" "quality_manager" {
  type        = "zip"
  source_file = "${path.module}/functions/quality_manager.py"
  output_path = "${path.module}/functions/quality_manager.zip"
}

# IAM role for quality manager Lambda
resource "aws_iam_role" "quality_manager" {
  name = "${var.project_name}-${var.environment}-quality-manager-role"

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "quality_manager_basic" {
  role       = aws_iam_role.quality_manager.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissions for quality manager
resource "aws_iam_role_policy" "quality_manager_policy" {
  name = "${var.project_name}-${var.environment}-quality-manager-policy"
  role = aws_iam_role.quality_manager.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:ExecuteStatement",
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
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_analytics_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution",
          "cloudfront:CreateInvalidation"
        ]
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${var.cloudfront_distribution_id}"
      }
    ]
  })
}

# CloudWatch log group for quality manager
resource "aws_cloudwatch_log_group" "quality_manager" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-quality-manager"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Lambda function for adaptive bitrate logic
resource "aws_lambda_function" "adaptive_bitrate" {
  filename      = "${path.module}/functions/adaptive_bitrate.zip"
  function_name = "${var.project_name}-${var.environment}-adaptive-bitrate"
  role          = aws_iam_role.adaptive_bitrate.arn
  handler       = "adaptive_bitrate.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      DYNAMODB_ANALYTICS_TABLE = var.dynamodb_analytics_table
      QUALITY_TIERS            = jsonencode(var.quality_tiers)
      ENVIRONMENT              = var.environment
      LOG_LEVEL                = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.adaptive_bitrate_basic,
    aws_cloudwatch_log_group.adaptive_bitrate,
    data.archive_file.adaptive_bitrate
  ]

  tags = var.tags
}

# Archive file for adaptive bitrate
data "archive_file" "adaptive_bitrate" {
  type        = "zip"
  source_file = "${path.module}/functions/adaptive_bitrate.py"
  output_path = "${path.module}/functions/adaptive_bitrate.zip"
}

# IAM role for adaptive bitrate Lambda
resource "aws_iam_role" "adaptive_bitrate" {
  name = "${var.project_name}-${var.environment}-adaptive-bitrate-role"

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "adaptive_bitrate_basic" {
  role       = aws_iam_role.adaptive_bitrate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissions for adaptive bitrate
resource "aws_iam_role_policy" "adaptive_bitrate_policy" {
  name = "${var.project_name}-${var.environment}-adaptive-bitrate-policy"
  role = aws_iam_role.adaptive_bitrate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_analytics_table}"
      }
    ]
  })
}

# CloudWatch log group for adaptive bitrate
resource "aws_cloudwatch_log_group" "adaptive_bitrate" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-adaptive-bitrate"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Lambda function for viewer experience optimization
resource "aws_lambda_function" "viewer_optimizer" {
  filename      = "${path.module}/functions/viewer_optimizer.zip"
  function_name = "${var.project_name}-${var.environment}-viewer-optimizer"
  role          = aws_iam_role.viewer_optimizer.arn
  handler       = "viewer_optimizer.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  memory_size   = 512

  environment {
    variables = {
      DYNAMODB_ANALYTICS_TABLE   = var.dynamodb_analytics_table
      CLOUDFRONT_DISTRIBUTION_ID = var.cloudfront_distribution_id
      OPTIMIZATION_RULES         = jsonencode(var.optimization_rules)
      ENVIRONMENT                = var.environment
      LOG_LEVEL                  = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.viewer_optimizer_basic,
    aws_cloudwatch_log_group.viewer_optimizer,
    data.archive_file.viewer_optimizer
  ]

  tags = var.tags
}

# Archive file for viewer optimizer
data "archive_file" "viewer_optimizer" {
  type        = "zip"
  source_file = "${path.module}/functions/viewer_optimizer.py"
  output_path = "${path.module}/functions/viewer_optimizer.zip"
}

# IAM role for viewer optimizer Lambda
resource "aws_iam_role" "viewer_optimizer" {
  name = "${var.project_name}-${var.environment}-viewer-optimizer-role"

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "viewer_optimizer_basic" {
  role       = aws_iam_role.viewer_optimizer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissions for viewer optimizer
resource "aws_iam_role_policy" "viewer_optimizer_policy" {
  name = "${var.project_name}-${var.environment}-viewer-optimizer-policy"
  role = aws_iam_role.viewer_optimizer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_analytics_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetDistributionConfig"
        ]
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${var.cloudfront_distribution_id}"
      }
    ]
  })
}

# CloudWatch log group for viewer optimizer
resource "aws_cloudwatch_log_group" "viewer_optimizer" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-viewer-optimizer"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# EventBridge rule for periodic optimization
resource "aws_cloudwatch_event_rule" "optimization_schedule" {
  count = var.enable_periodic_optimization ? 1 : 0

  name                = "${var.project_name}-${var.environment}-quality-optimization"
  description         = "Periodic quality optimization based on viewer analytics"
  schedule_expression = var.optimization_schedule

  tags = var.tags
}

# EventBridge target for optimization
resource "aws_cloudwatch_event_target" "optimization_target" {
  count = var.enable_periodic_optimization ? 1 : 0

  rule      = aws_cloudwatch_event_rule.optimization_schedule[0].name
  target_id = "ViewerOptimizerTarget"
  arn       = aws_lambda_function.viewer_optimizer.arn

  input = jsonencode({
    action = "optimize_quality"
    source = "scheduled"
  })
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "viewer_optimizer_eventbridge" {
  count = var.enable_periodic_optimization ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.viewer_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.optimization_schedule[0].arn
}

# CloudWatch Dashboard for quality metrics
resource "aws_cloudwatch_dashboard" "quality_metrics" {
  count = var.enable_quality_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-streaming-quality"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["Custom/StreamingQuality", "BufferRatio", "SubscriptionTier", "bronze"],
            [".", ".", ".", "silver"],
            [".", ".", ".", "gold"],
            [".", ".", ".", "platinum"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Buffer Ratio by Subscription Tier"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["Custom/StreamingQuality", "BitrateUtilization", "QualityLevel", "1080p"],
            [".", ".", ".", "720p"],
            [".", ".", ".", "480p"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Bitrate Utilization by Quality Level"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["Custom/StreamingQuality", "ViewerExperience", "Metric", "StartupTime"],
            [".", ".", ".", "RebufferCount"],
            [".", ".", ".", "QualitySwitches"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Viewer Experience Metrics"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms for quality monitoring
resource "aws_cloudwatch_metric_alarm" "high_buffer_ratio" {
  count = var.enable_quality_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-high-buffer-ratio"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BufferRatio"
  namespace           = "Custom/StreamingQuality"
  period              = "300"
  statistic           = "Average"
  threshold           = var.buffer_ratio_threshold
  alarm_description   = "High buffer ratio detected across viewers"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "poor_viewer_experience" {
  count = var.enable_quality_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-poor-viewer-experience"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "RebufferCount"
  namespace           = "Custom/StreamingQuality"
  period              = "300"
  statistic           = "Average"
  threshold           = var.rebuffer_threshold
  alarm_description   = "Poor viewer experience detected (high rebuffer count)"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  tags = var.tags
}