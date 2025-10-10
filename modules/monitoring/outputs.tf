# Monitoring Module Outputs

# Dashboard URLs
output "dashboard_urls" {
  description = "Map of CloudWatch dashboard URLs"
  value = {
    infrastructure_overview = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.infrastructure_overview.dashboard_name}"
    log_pipeline_health     = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.log_pipeline_health.dashboard_name}"
    cost_monitoring         = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.cost_monitoring.dashboard_name}"
    query_performance       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.query_performance.dashboard_name}"
    security_monitoring     = var.enable_security_dashboard ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.security_monitoring[0].dashboard_name}" : null
  }
}

# Dashboard names
output "dashboard_names" {
  description = "Map of CloudWatch dashboard names"
  value = {
    infrastructure_overview = aws_cloudwatch_dashboard.infrastructure_overview.dashboard_name
    log_pipeline_health     = aws_cloudwatch_dashboard.log_pipeline_health.dashboard_name
    cost_monitoring         = aws_cloudwatch_dashboard.cost_monitoring.dashboard_name
    query_performance       = aws_cloudwatch_dashboard.query_performance.dashboard_name
    security_monitoring     = var.enable_security_dashboard ? aws_cloudwatch_dashboard.security_monitoring[0].dashboard_name : null
  }
}

# Dashboard ARNs
output "dashboard_arns" {
  description = "Map of CloudWatch dashboard ARNs"
  value = {
    infrastructure_overview = aws_cloudwatch_dashboard.infrastructure_overview.dashboard_arn
    log_pipeline_health     = aws_cloudwatch_dashboard.log_pipeline_health.dashboard_arn
    cost_monitoring         = aws_cloudwatch_dashboard.cost_monitoring.dashboard_arn
    query_performance       = aws_cloudwatch_dashboard.query_performance.dashboard_arn
    security_monitoring     = var.enable_security_dashboard ? aws_cloudwatch_dashboard.security_monitoring[0].dashboard_arn : null
  }
}

# Configuration summary
output "monitoring_configuration" {
  description = "Summary of monitoring configuration"
  value = {
    total_dashboards = var.enable_security_dashboard ? 5 : 4
    security_dashboard_enabled = var.enable_security_dashboard
    cost_dashboard_enabled = var.enable_cost_dashboard
    performance_dashboard_enabled = var.enable_performance_dashboard
    refresh_interval = var.dashboard_refresh_interval
    environment = var.environment
    project_name = var.project_name
  }
}

# Cost monitoring outputs
output "cost_alert_topic_arn" {
  description = "SNS topic ARN for cost alerts"
  value       = aws_sns_topic.cost_alerts.arn
}

output "budget_names" {
  description = "Map of budget names"
  value = {
    project_budget = aws_budgets_budget.project_budget.name
    s3_budget      = var.enable_service_budgets ? aws_budgets_budget.s3_budget[0].name : null
    rds_budget     = var.enable_service_budgets ? aws_budgets_budget.rds_budget[0].name : null
  }
}

output "cost_alarm_names" {
  description = "Map of cost alarm names"
  value = {
    estimated_charges = aws_cloudwatch_metric_alarm.estimated_charges.alarm_name
    s3_costs         = var.enable_service_cost_alarms ? aws_cloudwatch_metric_alarm.s3_costs[0].alarm_name : null
    athena_costs     = var.enable_service_cost_alarms ? aws_cloudwatch_metric_alarm.athena_costs[0].alarm_name : null
    data_transfer_costs = var.enable_service_cost_alarms ? aws_cloudwatch_metric_alarm.data_transfer_costs[0].alarm_name : null
  }
}

output "cost_optimization_function_arn" {
  description = "ARN of the cost optimization Lambda function"
  value       = var.enable_cost_optimization_lambda ? aws_lambda_function.cost_optimizer[0].arn : null
}

# Commented out due to provider version compatibility
# output "anomaly_detector_arn" {
#   description = "ARN of the cost anomaly detector"
#   value       = var.enable_anomaly_detection ? aws_ce_anomaly_detector.project_anomaly_detector[0].arn : null
# }

# Cost monitoring configuration summary
output "cost_monitoring_configuration" {
  description = "Summary of cost monitoring configuration"
  value = {
    monthly_budget_limit = var.monthly_budget_limit
    service_budgets_enabled = var.enable_service_budgets
    cost_alarms_enabled = var.enable_service_cost_alarms
    anomaly_detection_enabled = var.enable_anomaly_detection
    cost_optimization_enabled = var.enable_cost_optimization_lambda
    billing_alarm_threshold = var.billing_alarm_threshold
  }
}

# Cleanup outputs
output "cleanup_function_arns" {
  description = "Map of cleanup Lambda function ARNs"
  value = var.enable_automated_cleanup ? {
    s3_cleanup   = aws_lambda_function.s3_cleanup[0].arn
    logs_cleanup = aws_lambda_function.logs_cleanup[0].arn
  } : {}
}

output "cleanup_schedules" {
  description = "Map of cleanup schedules"
  value = {
    s3_cleanup_schedule   = var.s3_cleanup_schedule
    logs_cleanup_schedule = var.logs_cleanup_schedule
  }
}

# Cleanup configuration summary
output "cleanup_configuration" {
  description = "Summary of cleanup configuration"
  value = {
    automated_cleanup_enabled = var.enable_automated_cleanup
    athena_results_retention_days = var.athena_results_retention_days
    query_results_retention_days = var.query_results_retention_days
    log_cleanup_retention_days = var.log_cleanup_retention_days
    s3_cleanup_schedule = var.s3_cleanup_schedule
    logs_cleanup_schedule = var.logs_cleanup_schedule
  }
}