# Scheduled Scaling for Cost Optimization
# This file contains scheduled scaling policies for predictable workloads

# Scheduled Scaling Policies
resource "aws_appautoscaling_scheduled_action" "scale_down_night" {
  for_each = var.scheduled_scaling_enabled ? local.frontend_apps : {}

  name               = "${var.project_name}-${var.environment}-${each.key}-scale-down-night"
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension

  # Scale down at 10 PM UTC (adjust based on your timezone)
  schedule = "cron(0 22 * * ? *)"

  scalable_target_action {
    min_capacity = var.environment == "prod" ? 1 : 0
    max_capacity = var.environment == "prod" ? 2 : 1
  }

  timezone = "UTC"
}

resource "aws_appautoscaling_scheduled_action" "scale_up_morning" {
  for_each = var.scheduled_scaling_enabled ? local.frontend_apps : {}

  name               = "${var.project_name}-${var.environment}-${each.key}-scale-up-morning"
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension

  # Scale up at 6 AM UTC (adjust based on your timezone)
  schedule = "cron(0 6 * * ? *)"

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  timezone = "UTC"
}

# Weekend scaling for non-production environments
resource "aws_appautoscaling_scheduled_action" "scale_down_weekend" {
  for_each = var.scheduled_scaling_enabled && var.environment != "prod" ? local.frontend_apps : {}

  name               = "${var.project_name}-${var.environment}-${each.key}-scale-down-weekend"
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension

  # Scale down on Friday at 6 PM UTC
  schedule = "cron(0 18 ? * FRI *)"

  scalable_target_action {
    min_capacity = 0
    max_capacity = 1
  }

  timezone = "UTC"
}

resource "aws_appautoscaling_scheduled_action" "scale_up_monday" {
  for_each = var.scheduled_scaling_enabled && var.environment != "prod" ? local.frontend_apps : {}

  name               = "${var.project_name}-${var.environment}-${each.key}-scale-up-monday"
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension

  # Scale up on Monday at 8 AM UTC
  schedule = "cron(0 8 ? * MON *)"

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  timezone = "UTC"
}

# Custom scheduled scaling rules from variables
resource "aws_appautoscaling_scheduled_action" "custom" {
  for_each = {
    for rule in var.scheduled_scaling_rules : "${rule.name}" => rule
  }

  name               = "${var.project_name}-${var.environment}-${each.value.name}"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${var.project_name}-${var.environment}-viewer-portal" # Apply to main service
  scalable_dimension = "ecs:service:DesiredCount"

  schedule = each.value.schedule

  scalable_target_action {
    min_capacity = each.value.min_capacity
    max_capacity = each.value.max_capacity
  }

  timezone = each.value.timezone
}