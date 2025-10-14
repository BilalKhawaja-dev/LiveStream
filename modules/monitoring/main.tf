# Monitoring Module for CloudWatch Dashboards
# Requirements: 4.8, 5.6, 5.8

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Main Infrastructure Dashboard
resource "aws_cloudwatch_dashboard" "infrastructure_overview" {
  dashboard_name = "${var.project_name}-${var.environment}-infrastructure-overview"

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
            ["AWS/Logs", "IncomingLogEvents", "LogGroupName", "${var.project_name}-${var.environment}-medialive"],
            [".", ".", ".", "${var.project_name}-${var.environment}-mediastore"],
            [".", ".", ".", "${var.project_name}-${var.environment}-ecs"],
            [".", ".", ".", "${var.project_name}-${var.environment}-apigateway"],
            [".", ".", ".", "${var.project_name}-${var.environment}-cognito"],
            [".", ".", ".", "${var.project_name}-${var.environment}-payment"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Log Events by Service"
          period  = 300
          stat    = "Sum"
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
            ["AWS/KinesisFirehose", "DeliveryToS3.Records", "DeliveryStreamName", "${var.project_name}-${var.environment}-application-logs"],
            [".", "DeliveryToS3.Success", ".", "."],
            [".", "DeliveryToS3.DataFreshness", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Kinesis Firehose Delivery"
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.s3_logs_bucket_name, "StorageType", "StandardStorage"],
            [".", ".", ".", var.s3_error_logs_bucket_name, ".", "."],
            [".", ".", ".", var.s3_backups_bucket_name, ".", "."],
            [".", ".", ".", var.s3_athena_results_bucket_name, ".", "."]
          ]
          view    = "timeSeries"
          stacked = true
          region  = data.aws_region.current.name
          title   = "S3 Storage Usage"
          period  = 86400
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.aurora_cluster_id],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Aurora Performance"
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_log_metadata_table_name],
            [".", "ConsumedWriteCapacityUnits", ".", "."],
            [".", "ThrottledRequests", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "DynamoDB Performance"
          period  = 300
          stat    = "Sum"
        }
      }
    ]
  })
}

# Log Pipeline Health Dashboard
resource "aws_cloudwatch_dashboard" "log_pipeline_health" {
  dashboard_name = "${var.project_name}-${var.environment}-log-pipeline-health"

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
            ["AWS/Logs", "IncomingLogEvents", "LogGroupName", "${var.project_name}-${var.environment}-medialive"],
            ["AWS/KinesisFirehose", "DeliveryToS3.Records", "DeliveryStreamName", "${var.project_name}-${var.environment}-application-logs"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Log Pipeline Throughput"
          period  = 300
          stat    = "Sum"
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
            ["AWS/KinesisFirehose", "DeliveryToS3.Success", "DeliveryStreamName", "${var.project_name}-${var.environment}-application-logs"],
            [".", "DeliveryToS3.DataFreshness", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Delivery Success Rate"
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query  = "SOURCE '${var.project_name}-${var.environment}-kinesis-firehose-logs'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 100"
          region = data.aws_region.current.name
          title  = "Recent Pipeline Errors"
          view   = "table"
        }
      }
    ]
  })
}

# Cost Monitoring Dashboard
resource "aws_cloudwatch_dashboard" "cost_monitoring" {
  dashboard_name = "${var.project_name}-${var.environment}-cost-monitoring"

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
            ["AWS/S3", "NumberOfObjects", "BucketName", var.s3_logs_bucket_name, "StorageType", "AllStorageTypes"],
            [".", "BucketSizeBytes", ".", ".", ".", "StandardStorage"],
            [".", ".", ".", ".", ".", "StandardIAStorage"],
            [".", ".", ".", ".", ".", "GlacierStorage"]
          ]
          view    = "timeSeries"
          stacked = true
          region  = data.aws_region.current.name
          title   = "S3 Storage Costs by Tier"
          period  = 86400
          stat    = "Average"
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
            ["AWS/Athena", "DataScannedInBytes", "WorkGroup", var.athena_workgroup_name],
            [".", "QueryExecutionTime", ".", "."],
            [".", "ProcessedBytes", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Athena Query Costs"
          period  = 3600
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "ServerlessDatabaseCapacity", "DBClusterIdentifier", var.aurora_cluster_id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Aurora Serverless ACU Usage"
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_log_metadata_table_name],
            [".", "ConsumedWriteCapacityUnits", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "DynamoDB Capacity Usage"
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["AWS/KinesisFirehose", "DeliveryToS3.Records", "DeliveryStreamName", "${var.project_name}-${var.environment}-application-logs"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Firehose Data Transfer"
          period  = 3600
          stat    = "Sum"
        }
      }
    ]
  })
}

# Query Performance Dashboard
resource "aws_cloudwatch_dashboard" "query_performance" {
  dashboard_name = "${var.project_name}-${var.environment}-query-performance"

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
            ["AWS/Athena", "QueryExecutionTime", "WorkGroup", var.athena_workgroup_name],
            [".", "DataScannedInBytes", ".", "."],
            [".", "ProcessedBytes", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Athena Query Performance"
          period  = 300
          stat    = "Average"
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
            ["AWS/Glue", "glue.driver.aggregate.numCompletedTasks", "JobName", var.glue_crawler_name],
            [".", "glue.driver.aggregate.numFailedTasks", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Glue Crawler Performance"
          period  = 3600
          stat    = "Sum"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query  = "SOURCE '${var.project_name}-${var.environment}-athena-logs'\n| fields @timestamp, @message\n| filter @message like /FAILED/\n| sort @timestamp desc\n| limit 50"
          region = data.aws_region.current.name
          title  = "Failed Queries"
          view   = "table"
        }
      }
    ]
  })
}

# Security Monitoring Dashboard
resource "aws_cloudwatch_dashboard" "security_monitoring" {
  count = var.enable_security_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-security-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "log"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          query  = "SOURCE '${var.project_name}-${var.environment}-cognito'\n| fields @timestamp, @message\n| filter @message like /FAILED/ or @message like /ERROR/\n| sort @timestamp desc\n| limit 100"
          region = data.aws_region.current.name
          title  = "Authentication Failures"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          query  = "SOURCE '${var.project_name}-${var.environment}-apigateway'\n| fields @timestamp, @message\n| filter @message like /403/ or @message like /401/\n| sort @timestamp desc\n| limit 100"
          region = data.aws_region.current.name
          title  = "Access Denied Events"
          view   = "table"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          metrics = [
            ["AWS/DynamoDB", "UserErrors", "TableName", var.dynamodb_log_metadata_table_name],
            [".", "SystemErrors", ".", "."],
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.aurora_cluster_id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Security-Related Errors"
          period  = 300
          stat    = "Sum"
        }
      }
    ]
  })
}

# Cost Monitoring and Budget Alerts
# Requirements: 5.1, 5.6, 5.8

# KMS key for SNS topic encryption
resource "aws_kms_key" "sns_encryption" {
  description             = "KMS key for SNS topic encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow SNS service"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-sns-kms-key"
    Environment = var.environment
    Project     = var.project_name
    Type        = "encryption"
  }
}

resource "aws_kms_alias" "sns_encryption" {
  name          = "alias/${var.project_name}-${var.environment}-sns-encryption"
  target_key_id = aws_kms_key.sns_encryption.key_id
}

# SNS topic for cost alerts with encryption
resource "aws_sns_topic" "cost_alerts" {
  name              = "${var.project_name}-${var.environment}-cost-alerts"
  display_name      = "Cost Monitoring Alerts"
  kms_master_key_id = aws_kms_key.sns_encryption.arn

  # Enable server-side encryption
  delivery_policy = jsonencode({
    "http" = {
      "defaultHealthyRetryPolicy" = {
        "minDelayTarget"     = 20
        "maxDelayTarget"     = 20
        "numRetries"         = 3
        "numMaxDelayRetries" = 0
        "numMinDelayRetries" = 0
        "numNoDelayRetries"  = 0
        "backoffFunction"    = "linear"
      }
      "disableSubscriptionOverrides" = false
    }
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-cost-alerts"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cost-monitoring"
  }
}

# Budget for overall project costs
resource "aws_budgets_budget" "project_budget" {
  name              = "${var.project_name}-${var.environment}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "TagKey"
    values = ["Project"]
  }

  cost_filter {
    name   = "TagKey"
    values = ["Environment"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 120
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-monthly-budget"
    Environment = var.environment
    Project     = var.project_name
    Type        = "budget"
  }
}

# Service-specific budgets
resource "aws_budgets_budget" "s3_budget" {
  count = var.enable_service_budgets ? 1 : 0

  name              = "${var.project_name}-${var.environment}-s3-budget"
  budget_type       = "COST"
  limit_amount      = var.s3_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "Service"
    values = ["Amazon Simple Storage Service"]
  }

  cost_filter {
    name   = "TagKey"
    values = ["Project"]
  }

  cost_filter {
    name   = "TagKey"
    values = ["Environment"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-budget"
    Environment = var.environment
    Project     = var.project_name
    Service     = "s3"
    Type        = "budget"
  }
}

resource "aws_budgets_budget" "rds_budget" {
  count = var.enable_service_budgets ? 1 : 0

  name              = "${var.project_name}-${var.environment}-rds-budget"
  budget_type       = "COST"
  limit_amount      = var.rds_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "Service"
    values = ["Amazon Relational Database Service"]
  }

  cost_filter {
    name   = "TagKey"
    values = ["Project"]
  }

  cost_filter {
    name   = "TagKey"
    values = ["Environment"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-budget"
    Environment = var.environment
    Project     = var.project_name
    Service     = "rds"
    Type        = "budget"
  }
}

# CloudWatch billing alarms
resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  alarm_name          = "${var.project_name}-${var.environment}-estimated-charges"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400" # Daily
  statistic           = "Maximum"
  threshold           = var.billing_alarm_threshold
  alarm_description   = "This metric monitors estimated charges"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  ok_actions          = [aws_sns_topic.cost_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-estimated-charges-alarm"
    Environment = var.environment
    Project     = var.project_name
    Type        = "billing-alarm"
  }
}

# Service-specific cost alarms
resource "aws_cloudwatch_metric_alarm" "s3_costs" {
  count = var.enable_service_cost_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-s3-costs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.s3_cost_alarm_threshold
  alarm_description   = "This metric monitors S3 estimated charges"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonS3"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-costs-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "s3"
    Type        = "cost-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "athena_costs" {
  count = var.enable_service_cost_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-athena-costs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.athena_cost_alarm_threshold
  alarm_description   = "This metric monitors Athena estimated charges"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonAthena"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-athena-costs-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "athena"
    Type        = "cost-alarm"
  }
}

# Data transfer cost alarm
resource "aws_cloudwatch_metric_alarm" "data_transfer_costs" {
  count = var.enable_service_cost_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-data-transfer-costs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.data_transfer_cost_alarm_threshold
  alarm_description   = "This metric monitors data transfer estimated charges"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonEC2-DataTransfer"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-transfer-costs-alarm"
    Environment = var.environment
    Project     = var.project_name
    Service     = "data-transfer"
    Type        = "cost-alarm"
  }
}

# Cost anomaly detection - Commented out due to provider version compatibility
# resource "aws_ce_anomaly_detector" "project_anomaly_detector" {
#   count = var.enable_anomaly_detection ? 1 : 0
#   
#   name         = "${var.project_name}-${var.environment}-cost-anomaly-detector"
#   monitor_type = "DIMENSIONAL"
#
#   specification = jsonencode({
#     Dimension = "SERVICE"
#     MatchOptions = ["EQUALS"]
#     Values = [
#       "Amazon Simple Storage Service",
#       "Amazon Relational Database Service",
#       "Amazon DynamoDB",
#       "Amazon Athena",
#       "AWS Glue",
#       "Amazon Kinesis Firehose"
#     ]
#   })
#
#   tags = {
#     Name        = "${var.project_name}-${var.environment}-cost-anomaly-detector"
#     Environment = var.environment
#     Project     = var.project_name
#     Type        = "anomaly-detection"
#   }
# }

# resource "aws_ce_anomaly_subscription" "project_anomaly_subscription" {
#   count = var.enable_anomaly_detection ? 1 : 0
#   
#   name      = "${var.project_name}-${var.environment}-cost-anomaly-subscription"
#   frequency = "DAILY"
#   
#   monitor_arn_list = [
#     aws_ce_anomaly_detector.project_anomaly_detector[0].arn
#   ]
#   
#   subscriber {
#     type    = "EMAIL"
#     address = var.anomaly_detection_email
#   }
#
#   threshold_expression {
#     and {
#       dimension {
#         key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
#         values        = [tostring(var.anomaly_threshold_amount)]
#         match_options = ["GREATER_THAN_OR_EQUAL"]
#       }
#     }
#   }
#
#   tags = {
#     Name        = "${var.project_name}-${var.environment}-cost-anomaly-subscription"
#     Environment = var.environment
#     Project     = var.project_name
#     Type        = "anomaly-subscription"
#   }
# }

# Lambda function for cost optimization recommendations
resource "aws_iam_role" "cost_optimizer_role" {
  count = var.enable_cost_optimization_lambda ? 1 : 0

  name = "${var.project_name}-${var.environment}-cost-optimizer-role"

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
    Name        = "${var.project_name}-${var.environment}-cost-optimizer-role"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cost-optimization"
  }
}

resource "aws_iam_role_policy" "cost_optimizer_policy" {
  count = var.enable_cost_optimization_lambda ? 1 : 0

  name = "${var.project_name}-${var.environment}-cost-optimizer-policy"
  role = aws_iam_role.cost_optimizer_role[0].id

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
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetUsageReport",
          "ce:GetReservationCoverage",
          "ce:GetReservationPurchaseRecommendation",
          "ce:GetReservationUtilization",
          "ce:ListCostCategoryDefinitions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:GetBucketAnalyticsConfiguration",
          "s3:GetBucketIntelligentTieringConfiguration"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusters",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:ListTables"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.cost_alerts.arn
      }
    ]
  })
}

# Lambda function for cost optimization
resource "aws_lambda_function" "cost_optimizer" {
  count = var.enable_cost_optimization_lambda ? 1 : 0

  filename         = data.archive_file.cost_optimizer_zip[0].output_path
  function_name    = "${var.project_name}-${var.environment}-cost-optimizer"
  role             = aws_iam_role.cost_optimizer_role[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.cost_optimizer_zip[0].output_base64sha256
  runtime          = "python3.9"
  timeout          = 300

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.cost_alerts.arn
      PROJECT_NAME  = var.project_name
      ENVIRONMENT   = var.environment
      BUDGET_LIMIT  = var.monthly_budget_limit
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cost-optimizer"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cost-optimization"
  }
}

# Secure Lambda Function URL with authentication
resource "aws_lambda_function_url" "cost_optimizer_url" {
  count = var.enable_cost_optimization_lambda && var.enable_lambda_function_urls ? 1 : 0

  function_name      = aws_lambda_function.cost_optimizer[0].function_name
  authorization_type = "AWS_IAM" # Require IAM authentication

  cors {
    allow_credentials = false
    allow_headers     = ["date", "keep-alive", "authorization"]
    allow_methods     = ["POST"]
    allow_origins     = var.allowed_origins
    expose_headers    = ["date", "keep-alive"]
    max_age           = 86400
  }
}

# Lambda function source code for cost optimization
resource "local_file" "cost_optimizer_source" {
  count = var.enable_cost_optimization_lambda ? 1 : 0

  filename = "${path.module}/cost_optimizer.py"
  content  = <<EOF
import json
import boto3
import os
from datetime import datetime, timedelta
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ce_client = boto3.client('ce')
s3_client = boto3.client('s3')
rds_client = boto3.client('rds')
dynamodb_client = boto3.client('dynamodb')
sns_client = boto3.client('sns')

def handler(event, context):
    """
    Analyze costs and provide optimization recommendations
    """
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    project_name = os.environ['PROJECT_NAME']
    environment = os.environ['ENVIRONMENT']
    budget_limit = float(os.environ['BUDGET_LIMIT'])
    
    recommendations = []
    
    try:
        # Get cost and usage data for the last 30 days
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=30)
        
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.strftime('%Y-%m-%d'),
                'End': end_date.strftime('%Y-%m-%d')
            },
            Granularity='MONTHLY',
            Metrics=['BlendedCost'],
            GroupBy=[
                {
                    'Type': 'DIMENSION',
                    'Key': 'SERVICE'
                }
            ],
            Filter={
                'Tags': {
                    'Key': 'Project',
                    'Values': [project_name]
                }
            }
        )
        
        total_cost = 0
        service_costs = {}
        
        for result in response['ResultsByTime']:
            for group in result['Groups']:
                service = group['Keys'][0]
                cost = float(group['Metrics']['BlendedCost']['Amount'])
                service_costs[service] = service_costs.get(service, 0) + cost
                total_cost += cost
        
        # Analyze S3 costs and recommend lifecycle policies
        s3_cost = service_costs.get('Amazon Simple Storage Service', 0)
        if s3_cost > budget_limit * 0.3:  # More than 30% of budget
            recommendations.append(f"S3 costs are $${s3_cost:.2f} (high). Consider implementing more aggressive lifecycle policies.")
        
        # Analyze RDS costs and recommend right-sizing
        rds_cost = service_costs.get('Amazon Relational Database Service', 0)
        if rds_cost > budget_limit * 0.4:  # More than 40% of budget
            recommendations.append(f"RDS costs are $${rds_cost:.2f} (high). Consider Aurora Serverless v2 scaling optimization.")
        
        # Analyze Athena costs
        athena_cost = service_costs.get('Amazon Athena', 0)
        if athena_cost > budget_limit * 0.1:  # More than 10% of budget
            recommendations.append(f"Athena costs are $${athena_cost:.2f} (high). Review query patterns and partition strategies.")
        
        # Check if total cost is approaching budget
        budget_utilization = (total_cost / budget_limit) * 100
        if budget_utilization > 80:
            recommendations.append(f"Total cost utilization is {budget_utilization:.1f}% of budget. Consider cost optimization measures.")
        
        # Generate recommendations message
        if recommendations:
            message = f"Cost Optimization Recommendations for {project_name} {environment}:\\n\\n"
            message += f"Current monthly cost: $${total_cost:.2f} ({budget_utilization:.1f}% of $${budget_limit:.2f} budget)\\n\\n"
            message += "Recommendations:\\n"
            for i, rec in enumerate(recommendations, 1):
                message += f"{i}. {rec}\\n"
            
            message += "\\nTop service costs:\\n"
            sorted_costs = sorted(service_costs.items(), key=lambda x: x[1], reverse=True)[:5]
            for service, cost in sorted_costs:
                message += f"- {service}: $${cost:.2f}\\n"
            
            # Send SNS notification
            sns_client.publish(
                TopicArn=sns_topic_arn,
                Subject=f"Cost Optimization Recommendations - {project_name} {environment}",
                Message=message
            )
            
            logger.info(f"Sent cost optimization recommendations: {len(recommendations)} items")
        else:
            logger.info("No cost optimization recommendations needed")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'total_cost': total_cost,
                'budget_utilization': budget_utilization,
                'recommendations_count': len(recommendations)
            })
        }
        
    except Exception as e:
        logger.error(f"Error in cost optimization analysis: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
EOF
}

# Create ZIP file for Lambda deployment
data "archive_file" "cost_optimizer_zip" {
  count = var.enable_cost_optimization_lambda ? 1 : 0

  type        = "zip"
  source_file = local_file.cost_optimizer_source[0].filename
  output_path = "${path.module}/cost_optimizer.zip"

  depends_on = [local_file.cost_optimizer_source]
}

# CloudWatch Event Rule for scheduled cost optimization
resource "aws_cloudwatch_event_rule" "cost_optimization_schedule" {
  count = var.enable_cost_optimization_lambda ? 1 : 0

  name                = "${var.project_name}-${var.environment}-cost-optimization"
  description         = "Trigger cost optimization analysis"
  schedule_expression = var.cost_optimization_schedule

  tags = {
    Name        = "${var.project_name}-${var.environment}-cost-optimization"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cost-optimization"
  }
}

resource "aws_cloudwatch_event_target" "cost_optimization_target" {
  count = var.enable_cost_optimization_lambda ? 1 : 0

  rule      = aws_cloudwatch_event_rule.cost_optimization_schedule[0].name
  target_id = "CostOptimizationTarget"
  arn       = aws_lambda_function.cost_optimizer[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_cost_optimization" {
  count = var.enable_cost_optimization_lambda ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_optimizer[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_optimization_schedule[0].arn
}

# Automated Cleanup Procedures
# Requirements: 4.5, 5.8

# IAM role for cleanup Lambda functions
resource "aws_iam_role" "cleanup_lambda_role" {
  count = var.enable_automated_cleanup ? 1 : 0

  name = "${var.project_name}-${var.environment}-cleanup-lambda-role"

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
    Name        = "${var.project_name}-${var.environment}-cleanup-lambda-role"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cleanup"
  }
}

resource "aws_iam_role_policy" "cleanup_lambda_policy" {
  count = var.enable_automated_cleanup ? 1 : 0

  name = "${var.project_name}-${var.environment}-cleanup-lambda-policy"
  role = aws_iam_role.cleanup_lambda_role[0].id

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
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetBucketVersioning",
          "s3:ListBucketVersions",
          "s3:DeleteObjectVersion"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:DeleteLogGroup",
          "logs:DeleteLogStream"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.project_name}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "athena:ListQueryExecutions",
          "athena:GetQueryExecution",
          "athena:StopQueryExecution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.cost_alerts.arn
      }
    ]
  })
}

# Lambda function for S3 cleanup
resource "aws_lambda_function" "s3_cleanup" {
  count = var.enable_automated_cleanup ? 1 : 0

  filename         = data.archive_file.s3_cleanup_zip[0].output_path
  function_name    = "${var.project_name}-${var.environment}-s3-cleanup"
  role             = aws_iam_role.cleanup_lambda_role[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.s3_cleanup_zip[0].output_base64sha256
  runtime          = "python3.9"
  timeout          = 900 # 15 minutes

  environment {
    variables = {
      PROJECT_NAME                  = var.project_name
      ENVIRONMENT                   = var.environment
      SNS_TOPIC_ARN                 = aws_sns_topic.cost_alerts.arn
      ATHENA_RESULTS_RETENTION_DAYS = var.athena_results_retention_days
      QUERY_RESULTS_RETENTION_DAYS  = var.query_results_retention_days
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-cleanup"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cleanup"
  }
}

# S3 cleanup Lambda source code
resource "local_file" "s3_cleanup_source" {
  count = var.enable_automated_cleanup ? 1 : 0

  filename = "${path.module}/s3_cleanup.py"
  content  = <<EOF
import json
import boto3
import os
from datetime import datetime, timedelta
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

def handler(event, context):
    """
    Clean up old S3 objects based on retention policies
    """
    project_name = os.environ['PROJECT_NAME']
    environment = os.environ['ENVIRONMENT']
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    athena_retention_days = int(os.environ['ATHENA_RESULTS_RETENTION_DAYS'])
    query_retention_days = int(os.environ['QUERY_RESULTS_RETENTION_DAYS'])
    
    cleanup_summary = {
        'athena_results_deleted': 0,
        'query_results_deleted': 0,
        'total_size_freed': 0
    }
    
    try:
        # Clean up Athena query results
        athena_bucket = f"{project_name}-{environment}-athena-results"
        cleanup_summary['athena_results_deleted'] = cleanup_bucket_objects(
            athena_bucket, athena_retention_days
        )
        
        # Clean up old query results (if separate bucket)
        query_bucket = f"{project_name}-{environment}-query-results"
        try:
            cleanup_summary['query_results_deleted'] = cleanup_bucket_objects(
                query_bucket, query_retention_days
            )
        except s3_client.exceptions.NoSuchBucket:
            logger.info(f"Query results bucket {query_bucket} does not exist, skipping")
        
        # Send summary notification
        if cleanup_summary['athena_results_deleted'] > 0 or cleanup_summary['query_results_deleted'] > 0:
            message = f"S3 Cleanup Summary for {project_name} {environment}:\\n\\n"
            message += f"Athena results deleted: {cleanup_summary['athena_results_deleted']} objects\\n"
            message += f"Query results deleted: {cleanup_summary['query_results_deleted']} objects\\n"
            message += f"Total objects cleaned: {cleanup_summary['athena_results_deleted'] + cleanup_summary['query_results_deleted']}"
            
            sns_client.publish(
                TopicArn=sns_topic_arn,
                Subject=f"S3 Cleanup Report - {project_name} {environment}",
                Message=message
            )
        
        logger.info(f"S3 cleanup completed: {cleanup_summary}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(cleanup_summary)
        }
        
    except Exception as e:
        logger.error(f"Error in S3 cleanup: {str(e)}")
        
        # Send error notification
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=f"S3 Cleanup Error - {project_name} {environment}",
            Message=f"S3 cleanup failed with error: {str(e)}"
        )
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def cleanup_bucket_objects(bucket_name, retention_days):
    """
    Clean up objects older than retention_days in the specified bucket
    """
    deleted_count = 0
    cutoff_date = datetime.now() - timedelta(days=retention_days)
    
    try:
        paginator = s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name)
        
        objects_to_delete = []
        
        for page in pages:
            if 'Contents' in page:
                for obj in page['Contents']:
                    if obj['LastModified'].replace(tzinfo=None) < cutoff_date:
                        objects_to_delete.append({'Key': obj['Key']})
                        
                        # Delete in batches of 1000
                        if len(objects_to_delete) >= 1000:
                            delete_response = s3_client.delete_objects(
                                Bucket=bucket_name,
                                Delete={'Objects': objects_to_delete}
                            )
                            deleted_count += len(delete_response.get('Deleted', []))
                            objects_to_delete = []
        
        # Delete remaining objects
        if objects_to_delete:
            delete_response = s3_client.delete_objects(
                Bucket=bucket_name,
                Delete={'Objects': objects_to_delete}
            )
            deleted_count += len(delete_response.get('Deleted', []))
        
        logger.info(f"Deleted {deleted_count} objects from {bucket_name}")
        return deleted_count
        
    except Exception as e:
        logger.error(f"Error cleaning up bucket {bucket_name}: {str(e)}")
        raise e
EOF
}

# Lambda function for CloudWatch logs cleanup
resource "aws_lambda_function" "logs_cleanup" {
  count = var.enable_automated_cleanup ? 1 : 0

  filename         = data.archive_file.logs_cleanup_zip[0].output_path
  function_name    = "${var.project_name}-${var.environment}-logs-cleanup"
  role             = aws_iam_role.cleanup_lambda_role[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.logs_cleanup_zip[0].output_base64sha256
  runtime          = "python3.9"
  timeout          = 600 # 10 minutes

  environment {
    variables = {
      PROJECT_NAME       = var.project_name
      ENVIRONMENT        = var.environment
      SNS_TOPIC_ARN      = aws_sns_topic.cost_alerts.arn
      LOG_RETENTION_DAYS = var.log_cleanup_retention_days
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs-cleanup"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cleanup"
  }
}

# CloudWatch logs cleanup Lambda source code
resource "local_file" "logs_cleanup_source" {
  count = var.enable_automated_cleanup ? 1 : 0

  filename = "${path.module}/logs_cleanup.py"
  content  = <<EOF
import json
import boto3
import os
from datetime import datetime, timedelta
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

logs_client = boto3.client('logs')
sns_client = boto3.client('sns')

def handler(event, context):
    """
    Clean up old CloudWatch log streams and empty log groups
    """
    project_name = os.environ['PROJECT_NAME']
    environment = os.environ['ENVIRONMENT']
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    retention_days = int(os.environ['LOG_RETENTION_DAYS'])
    
    cleanup_summary = {
        'log_streams_deleted': 0,
        'log_groups_cleaned': 0,
        'empty_log_groups_deleted': 0
    }
    
    try:
        cutoff_timestamp = int((datetime.now() - timedelta(days=retention_days)).timestamp() * 1000)
        
        # Get all log groups for this project/environment
        paginator = logs_client.get_paginator('describe_log_groups')
        log_group_prefix = f"{project_name}-{environment}-"
        
        for page in paginator.paginate(logGroupNamePrefix=log_group_prefix):
            for log_group in page['logGroups']:
                log_group_name = log_group['logGroupName']
                
                # Clean up old log streams in this group
                streams_deleted = cleanup_log_streams(log_group_name, cutoff_timestamp)
                cleanup_summary['log_streams_deleted'] += streams_deleted
                
                if streams_deleted > 0:
                    cleanup_summary['log_groups_cleaned'] += 1
                
                # Check if log group is now empty and can be deleted
                if should_delete_empty_log_group(log_group_name):
                    try:
                        logs_client.delete_log_group(logGroupName=log_group_name)
                        cleanup_summary['empty_log_groups_deleted'] += 1
                        logger.info(f"Deleted empty log group: {log_group_name}")
                    except Exception as e:
                        logger.warning(f"Could not delete log group {log_group_name}: {str(e)}")
        
        # Send summary notification
        if any(cleanup_summary.values()):
            message = f"CloudWatch Logs Cleanup Summary for {project_name} {environment}:\\n\\n"
            message += f"Log streams deleted: {cleanup_summary['log_streams_deleted']}\\n"
            message += f"Log groups cleaned: {cleanup_summary['log_groups_cleaned']}\\n"
            message += f"Empty log groups deleted: {cleanup_summary['empty_log_groups_deleted']}"
            
            sns_client.publish(
                TopicArn=sns_topic_arn,
                Subject=f"CloudWatch Logs Cleanup Report - {project_name} {environment}",
                Message=message
            )
        
        logger.info(f"Logs cleanup completed: {cleanup_summary}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(cleanup_summary)
        }
        
    except Exception as e:
        logger.error(f"Error in logs cleanup: {str(e)}")
        
        # Send error notification
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=f"Logs Cleanup Error - {project_name} {environment}",
            Message=f"CloudWatch logs cleanup failed with error: {str(e)}"
        )
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def cleanup_log_streams(log_group_name, cutoff_timestamp):
    """
    Delete old log streams from a log group
    """
    deleted_count = 0
    
    try:
        paginator = logs_client.get_paginator('describe_log_streams')
        
        for page in paginator.paginate(logGroupName=log_group_name):
            for stream in page['logStreams']:
                # Check if stream is old enough to delete
                last_event_time = stream.get('lastEventTime', stream.get('creationTime', 0))
                
                if last_event_time < cutoff_timestamp:
                    try:
                        logs_client.delete_log_stream(
                            logGroupName=log_group_name,
                            logStreamName=stream['logStreamName']
                        )
                        deleted_count += 1
                        logger.debug(f"Deleted log stream: {stream['logStreamName']}")
                    except Exception as e:
                        logger.warning(f"Could not delete log stream {stream['logStreamName']}: {str(e)}")
        
        if deleted_count > 0:
            logger.info(f"Deleted {deleted_count} log streams from {log_group_name}")
        
        return deleted_count
        
    except Exception as e:
        logger.error(f"Error cleaning up log streams in {log_group_name}: {str(e)}")
        return 0

def should_delete_empty_log_group(log_group_name):
    """
    Check if a log group is empty and should be deleted
    """
    try:
        response = logs_client.describe_log_streams(
            logGroupName=log_group_name,
            limit=1
        )
        
        # If no log streams, the group is empty
        return len(response.get('logStreams', [])) == 0
        
    except Exception as e:
        logger.warning(f"Could not check if log group {log_group_name} is empty: {str(e)}")
        return False
EOF
}

# Create ZIP files for Lambda deployment
data "archive_file" "s3_cleanup_zip" {
  count = var.enable_automated_cleanup ? 1 : 0

  type        = "zip"
  source_file = local_file.s3_cleanup_source[0].filename
  output_path = "${path.module}/s3_cleanup.zip"

  depends_on = [local_file.s3_cleanup_source]
}

data "archive_file" "logs_cleanup_zip" {
  count = var.enable_automated_cleanup ? 1 : 0

  type        = "zip"
  source_file = local_file.logs_cleanup_source[0].filename
  output_path = "${path.module}/logs_cleanup.zip"

  depends_on = [local_file.logs_cleanup_source]
}

# CloudWatch Event Rules for scheduled cleanup
resource "aws_cloudwatch_event_rule" "s3_cleanup_schedule" {
  count = var.enable_automated_cleanup ? 1 : 0

  name                = "${var.project_name}-${var.environment}-s3-cleanup"
  description         = "Trigger S3 cleanup"
  schedule_expression = var.s3_cleanup_schedule

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-cleanup"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cleanup"
  }
}

resource "aws_cloudwatch_event_rule" "logs_cleanup_schedule" {
  count = var.enable_automated_cleanup ? 1 : 0

  name                = "${var.project_name}-${var.environment}-logs-cleanup"
  description         = "Trigger CloudWatch logs cleanup"
  schedule_expression = var.logs_cleanup_schedule

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs-cleanup"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cleanup"
  }
}

# Event targets
resource "aws_cloudwatch_event_target" "s3_cleanup_target" {
  count = var.enable_automated_cleanup ? 1 : 0

  rule      = aws_cloudwatch_event_rule.s3_cleanup_schedule[0].name
  target_id = "S3CleanupTarget"
  arn       = aws_lambda_function.s3_cleanup[0].arn
}

resource "aws_cloudwatch_event_target" "logs_cleanup_target" {
  count = var.enable_automated_cleanup ? 1 : 0

  rule      = aws_cloudwatch_event_rule.logs_cleanup_schedule[0].name
  target_id = "LogsCleanupTarget"
  arn       = aws_lambda_function.logs_cleanup[0].arn
}

# Lambda permissions
resource "aws_lambda_permission" "allow_cloudwatch_s3_cleanup" {
  count = var.enable_automated_cleanup ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_cleanup[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_cleanup_schedule[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_logs_cleanup" {
  count = var.enable_automated_cleanup ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.logs_cleanup[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.logs_cleanup_schedule[0].arn
}

# CloudWatch Log Groups for cleanup Lambda functions
resource "aws_cloudwatch_log_group" "s3_cleanup_logs" {
  count = var.enable_automated_cleanup ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.s3_cleanup[0].function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-cleanup-logs"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cleanup"
  }
}

resource "aws_cloudwatch_log_group" "logs_cleanup_logs" {
  count = var.enable_automated_cleanup ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.logs_cleanup[0].function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs-cleanup-logs"
    Environment = var.environment
    Project     = var.project_name
    Type        = "cleanup"
  }
}