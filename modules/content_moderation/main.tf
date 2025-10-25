# Content Moderation Module - AI-powered content analysis and moderation

# S3 bucket for flagged content storage
resource "aws_s3_bucket" "flagged_content" {
  bucket = "${var.project_name}-${var.environment}-flagged-content"
  tags = merge(var.tags, {
    Service = "content-moderation"
    Type    = "s3-bucket"
  })
}

resource "aws_s3_bucket_versioning" "flagged_content_versioning" {
  bucket = aws_s3_bucket.flagged_content.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flagged_content_encryption" {
  bucket = aws_s3_bucket.flagged_content.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lambda function for content analysis
resource "aws_lambda_function" "content_analyzer" {
  filename         = data.archive_file.content_analyzer.output_path
  function_name    = "${var.project_name}-${var.environment}-content-analyzer"
  role             = aws_iam_role.content_analyzer_role.arn
  handler          = "content_analyzer.lambda_handler"
  runtime          = "python3.9"
  timeout          = 300
  memory_size      = 1024
  source_code_hash = data.archive_file.content_analyzer.output_base64sha256

  environment {
    variables = {
      MODERATION_TABLE       = var.moderation_table_name
      FLAGGED_CONTENT_BUCKET = aws_s3_bucket.flagged_content.bucket
      NOTIFICATION_TOPIC     = aws_sns_topic.moderation_alerts.arn
    }
  }

  tags = merge(var.tags, {
    Service = "content-moderation"
    Type    = "lambda-function"
  })
}

# Lambda function for manual review interface
resource "aws_lambda_function" "moderation_api" {
  filename         = data.archive_file.moderation_api.output_path
  function_name    = "${var.project_name}-${var.environment}-moderation-api"
  role             = aws_iam_role.moderation_api_role.arn
  handler          = "moderation_api.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 512
  source_code_hash = data.archive_file.moderation_api.output_base64sha256

  environment {
    variables = {
      MODERATION_TABLE       = var.moderation_table_name
      FLAGGED_CONTENT_BUCKET = aws_s3_bucket.flagged_content.bucket
      VIDEOS_TABLE           = var.videos_table_name
      MESSAGES_TABLE         = var.messages_table_name
    }
  }

  tags = merge(var.tags, {
    Service = "content-moderation"
    Type    = "lambda-function"
  })
}

# SNS topic for moderation alerts
resource "aws_sns_topic" "moderation_alerts" {
  name = "${var.project_name}-${var.environment}-moderation-alerts"
  tags = merge(var.tags, {
    Service = "content-moderation"
    Type    = "sns-topic"
  })
}

# SNS subscription for email notifications
resource "aws_sns_topic_subscription" "moderation_email" {
  topic_arn = aws_sns_topic.moderation_alerts.arn
  protocol  = "email"
  endpoint  = var.moderation_email
}

# EventBridge rule for scheduled content review
resource "aws_cloudwatch_event_rule" "content_review_schedule" {
  name                = "${var.project_name}-${var.environment}-content-review"
  description         = "Trigger periodic content review"
  schedule_expression = "rate(1 hour)"
  tags = merge(var.tags, {
    Service = "content-moderation"
    Type    = "eventbridge-rule"
  })
}

resource "aws_cloudwatch_event_target" "content_review_target" {
  rule      = aws_cloudwatch_event_rule.content_review_schedule.name
  target_id = "ContentReviewTarget"
  arn       = aws_lambda_function.content_analyzer.arn
  input = jsonencode({
    "action" = "scheduled_review"
  })
}

resource "aws_lambda_permission" "allow_eventbridge_content_review" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.content_analyzer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.content_review_schedule.arn
}

# IAM role for content analyzer Lambda
resource "aws_iam_role" "content_analyzer_role" {
  name = "${var.project_name}-${var.environment}-content-analyzer-role"

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
    Service = "content-moderation"
    Type    = "iam-role"
  })
}

resource "aws_iam_role_policy" "content_analyzer_policy" {
  name = "${var.project_name}-${var.environment}-content-analyzer-policy"
  role = aws_iam_role.content_analyzer_role.id

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
          "rekognition:DetectModerationLabels",
          "rekognition:DetectText",
          "rekognition:DetectFaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectSentiment",
          "comprehend:DetectToxicContent",
          "comprehend:DetectPiiEntities"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.moderation_table_arn,
          var.videos_table_arn,
          var.messages_table_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.flagged_content.arn}/*",
          "${var.video_upload_bucket_arn}/*",
          "${var.processed_videos_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.moderation_alerts.arn
      }
    ]
  })
}

# IAM role for moderation API Lambda
resource "aws_iam_role" "moderation_api_role" {
  name = "${var.project_name}-${var.environment}-moderation-api-role"

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
    Service = "content-moderation"
    Type    = "iam-role"
  })
}

resource "aws_iam_role_policy" "moderation_api_policy" {
  name = "${var.project_name}-${var.environment}-moderation-api-policy"
  role = aws_iam_role.moderation_api_role.id

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
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          var.moderation_table_arn,
          "${var.moderation_table_arn}/index/*",
          var.videos_table_arn,
          var.messages_table_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.flagged_content.arn}/*",
          "${var.video_upload_bucket_arn}/*",
          "${var.processed_videos_bucket_arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "content_analyzer_logs" {
  name              = "/aws/lambda/${aws_lambda_function.content_analyzer.function_name}"
  retention_in_days = 7
  tags = merge(var.tags, {
    Service = "content-moderation"
    Type    = "log-group"
  })
}

resource "aws_cloudwatch_log_group" "moderation_api_logs" {
  name              = "/aws/lambda/${aws_lambda_function.moderation_api.function_name}"
  retention_in_days = 7
  tags = merge(var.tags, {
    Service = "content-moderation"
    Type    = "log-group"
  })
}

# CloudWatch Alarms for moderation monitoring
resource "aws_cloudwatch_metric_alarm" "high_flagged_content" {
  alarm_name          = "${var.project_name}-${var.environment}-high-flagged-content"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "This metric monitors high volume of flagged content"
  alarm_actions       = [aws_sns_topic.moderation_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.content_analyzer.function_name
  }

  tags = merge(var.tags, {
    Service = "content-moderation"
    Type    = "cloudwatch-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "moderation_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-moderation-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors content moderation errors"
  alarm_actions       = [aws_sns_topic.moderation_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.content_analyzer.function_name
  }

  tags = merge(var.tags, {
    Service = "content-moderation"
    Type    = "cloudwatch-alarm"
  })
}

# Data sources for Lambda deployment packages
data "archive_file" "content_analyzer" {
  type        = "zip"
  output_path = "${path.module}/content_analyzer.zip"
  source_file = "${path.module}/functions/content_analyzer.py"
}

data "archive_file" "moderation_api" {
  type        = "zip"
  output_path = "${path.module}/moderation_api.zip"
  source_file = "${path.module}/functions/moderation_api.py"
}