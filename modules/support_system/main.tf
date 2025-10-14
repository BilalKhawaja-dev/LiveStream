# Support System Module with AI Integration
# This module creates smart ticket filtering, AI responses, and support dashboard

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# SNS Topics for different support categories
resource "aws_sns_topic" "support_general" {
  name = "${var.project_name}-${var.environment}-support-general"

  tags = merge(var.tags, {
    Category = "general"
  })
}

resource "aws_sns_topic" "support_technical" {
  name = "${var.project_name}-${var.environment}-support-technical"

  tags = merge(var.tags, {
    Category = "technical"
  })
}

resource "aws_sns_topic" "support_billing" {
  name = "${var.project_name}-${var.environment}-support-billing"

  tags = merge(var.tags, {
    Category = "billing"
  })
}

resource "aws_sns_topic" "support_urgent" {
  name = "${var.project_name}-${var.environment}-support-urgent"

  tags = merge(var.tags, {
    Category = "urgent"
  })
}

# Lambda function for smart ticket filtering
resource "aws_lambda_function" "ticket_filter" {
  filename      = "${path.module}/functions/ticket_filter.zip"
  function_name = "${var.project_name}-${var.environment}-ticket-filter"
  role          = aws_iam_role.ticket_filter.arn
  handler       = "ticket_filter.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  memory_size   = 512

  environment {
    variables = {
      DYNAMODB_TICKETS_TABLE = var.dynamodb_tickets_table
      SNS_GENERAL_TOPIC      = aws_sns_topic.support_general.arn
      SNS_TECHNICAL_TOPIC    = aws_sns_topic.support_technical.arn
      SNS_BILLING_TOPIC      = aws_sns_topic.support_billing.arn
      SNS_URGENT_TOPIC       = aws_sns_topic.support_urgent.arn
      BEDROCK_MODEL_ID       = var.bedrock_model_id
      ENVIRONMENT            = var.environment
      LOG_LEVEL              = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.ticket_filter_basic,
    aws_cloudwatch_log_group.ticket_filter,
    data.archive_file.ticket_filter
  ]

  tags = var.tags
}

# Archive file for ticket filter
data "archive_file" "ticket_filter" {
  type        = "zip"
  source_file = "${path.module}/functions/ticket_filter.py"
  output_path = "${path.module}/functions/ticket_filter.zip"
}

# IAM role for ticket filter Lambda
resource "aws_iam_role" "ticket_filter" {
  name = "${var.project_name}-${var.environment}-ticket-filter-role"

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

resource "aws_iam_role_policy_attachment" "ticket_filter_basic" {
  role       = aws_iam_role.ticket_filter.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissions for ticket filter
resource "aws_iam_role_policy" "ticket_filter_policy" {
  name = "${var.project_name}-${var.environment}-ticket-filter-policy"
  role = aws_iam_role.ticket_filter.id

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
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_tickets_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.support_general.arn,
          aws_sns_topic.support_technical.arn,
          aws_sns_topic.support_billing.arn,
          aws_sns_topic.support_urgent.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}"
      }
    ]
  })
}

# CloudWatch log group for ticket filter
resource "aws_cloudwatch_log_group" "ticket_filter" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-ticket-filter"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Lambda function for AI support responses
resource "aws_lambda_function" "ai_support" {
  filename      = "${path.module}/functions/ai_support.zip"
  function_name = "${var.project_name}-${var.environment}-ai-support"
  role          = aws_iam_role.ai_support.arn
  handler       = "ai_support.lambda_handler"
  runtime       = "python3.9"
  timeout       = 120
  memory_size   = 1024

  environment {
    variables = {
      DYNAMODB_TICKETS_TABLE = var.dynamodb_tickets_table
      BEDROCK_MODEL_ID       = var.bedrock_model_id
      KNOWLEDGE_BASE_ID      = var.knowledge_base_id
      ENVIRONMENT            = var.environment
      LOG_LEVEL              = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.ai_support_basic,
    aws_cloudwatch_log_group.ai_support,
    data.archive_file.ai_support
  ]

  tags = var.tags
}

# Archive file for AI support
data "archive_file" "ai_support" {
  type        = "zip"
  source_file = "${path.module}/functions/ai_support.py"
  output_path = "${path.module}/functions/ai_support.zip"
}

# IAM role for AI support Lambda
resource "aws_iam_role" "ai_support" {
  name = "${var.project_name}-${var.environment}-ai-support-role"

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

resource "aws_iam_role_policy_attachment" "ai_support_basic" {
  role       = aws_iam_role.ai_support.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissions for AI support
resource "aws_iam_role_policy" "ai_support_policy" {
  name = "${var.project_name}-${var.environment}-ai-support-policy"
  role = aws_iam_role.ai_support.id

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
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_tickets_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:Retrieve"
        ]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}",
          "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:knowledge-base/${var.knowledge_base_id}"
        ]
      }
    ]
  })
}

# CloudWatch log group for AI support
resource "aws_cloudwatch_log_group" "ai_support" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-ai-support"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Email subscriptions for support topics
resource "aws_sns_topic_subscription" "support_general_email" {
  count = length(var.support_email_addresses)

  topic_arn = aws_sns_topic.support_general.arn
  protocol  = "email"
  endpoint  = var.support_email_addresses[count.index]
}

resource "aws_sns_topic_subscription" "support_technical_email" {
  count = length(var.technical_email_addresses)

  topic_arn = aws_sns_topic.support_technical.arn
  protocol  = "email"
  endpoint  = var.technical_email_addresses[count.index]
}

resource "aws_sns_topic_subscription" "support_billing_email" {
  count = length(var.billing_email_addresses)

  topic_arn = aws_sns_topic.support_billing.arn
  protocol  = "email"
  endpoint  = var.billing_email_addresses[count.index]
}

resource "aws_sns_topic_subscription" "support_urgent_email" {
  count = length(var.urgent_email_addresses)

  topic_arn = aws_sns_topic.support_urgent.arn
  protocol  = "email"
  endpoint  = var.urgent_email_addresses[count.index]
}

# CloudWatch Dashboard for support metrics
resource "aws_cloudwatch_dashboard" "support_metrics" {
  count = var.enable_support_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-support-metrics"

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
            ["Custom/Support", "TicketsCreated", "Category", "general"],
            [".", ".", ".", "technical"],
            [".", ".", ".", "billing"],
            [".", ".", ".", "urgent"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Support Tickets by Category"
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
            ["Custom/Support", "AIResponseGenerated"],
            [".", "TicketResolved"],
            [".", "ResponseTime"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Support Performance Metrics"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms for support monitoring
resource "aws_cloudwatch_metric_alarm" "high_ticket_volume" {
  count = var.enable_support_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-high-ticket-volume"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TicketsCreated"
  namespace           = "Custom/Support"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.high_ticket_volume_threshold
  alarm_description   = "High volume of support tickets detected"
  alarm_actions       = [aws_sns_topic.support_urgent.arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}