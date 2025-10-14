# CloudWatch Monitoring and Alarms for ECS Services

# CloudWatch Dashboard for ECS Services
resource "aws_cloudwatch_dashboard" "ecs_services" {
  dashboard_name = "${var.project_name}-${var.environment}-ecs-services"

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
            for service_name in keys(local.frontend_apps) : [
              "AWS/ECS",
              "CPUUtilization",
              "ServiceName",
              "${var.project_name}-${var.environment}-${service_name}",
              "ClusterName",
              aws_ecs_cluster.main.name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "ECS Service CPU Utilization"
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
            for service_name in keys(local.frontend_apps) : [
              "AWS/ECS",
              "MemoryUtilization",
              "ServiceName",
              "${var.project_name}-${var.environment}-${service_name}",
              "ClusterName",
              aws_ecs_cluster.main.name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "ECS Service Memory Utilization"
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
            for service_name in keys(local.frontend_apps) : [
              "AWS/ECS",
              "RunningTaskCount",
              "ServiceName",
              "${var.project_name}-${var.environment}-${service_name}",
              "ClusterName",
              aws_ecs_cluster.main.name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "ECS Service Running Task Count"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            for service_name in keys(local.frontend_apps) : [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "TargetGroup",
              split("/", var.target_group_arns[service_name])[1]
            ] if contains(keys(var.target_group_arns), service_name)
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "ALB Target Response Time"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms for High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  for_each = local.frontend_apps

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ECS service CPU utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    ServiceName = aws_ecs_service.services[each.key].name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = var.tags
}

# CloudWatch Alarms for High Memory Utilization
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  for_each = local.frontend_apps

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  alarm_description   = "This metric monitors ECS service memory utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    ServiceName = aws_ecs_service.services[each.key].name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = var.tags
}

# CloudWatch Alarms for Service Health
resource "aws_cloudwatch_metric_alarm" "service_unhealthy" {
  for_each = local.frontend_apps

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-unhealthy-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ECS service running task count"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = aws_ecs_service.services[each.key].name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = var.tags
}

# CloudWatch Alarms for ALB Target Health
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  for_each = { for k, v in local.frontend_apps : k => v if contains(keys(var.target_group_arns), k) }

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors ALB unhealthy target count"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    TargetGroup = split("/", var.target_group_arns[each.key])[1]
  }

  tags = var.tags
}

# CloudWatch Alarms for High Response Time
resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  for_each = { for k, v in local.frontend_apps : k => v if contains(keys(var.target_group_arns), k) }

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    TargetGroup = split("/", var.target_group_arns[each.key])[1]
  }

  tags = var.tags
}

# Custom Metrics for Application-Level Monitoring
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  for_each = local.frontend_apps

  name           = "${var.project_name}-${var.environment}-${each.key}-error-count"
  log_group_name = aws_cloudwatch_log_group.services[each.key].name
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"

  metric_transformation {
    name      = "${var.project_name}-${var.environment}-${each.key}-ErrorCount"
    namespace = "StreamingPlatform/Application"
    value     = "1"
  }
}

# Alarms for Application Errors
resource "aws_cloudwatch_metric_alarm" "application_errors" {
  for_each = local.frontend_apps

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-application-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "${var.project_name}-${var.environment}-${each.key}-ErrorCount"
  namespace           = "StreamingPlatform/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors application error count"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# Cost Monitoring - ECS Service Costs
resource "aws_cloudwatch_metric_alarm" "high_task_count" {
  for_each = local.frontend_apps

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-high-task-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.environment == "prod" ? "5" : "2"
  alarm_description   = "This metric monitors ECS service task count for cost control"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    ServiceName = aws_ecs_service.services[each.key].name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = var.tags
}