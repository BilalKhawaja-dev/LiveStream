# ALB Module Outputs
# Requirements: 7.3, 8.1, 8.6

output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.frontend_alb.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.frontend_alb.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  value       = aws_lb.frontend_alb.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.frontend_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.frontend_alb.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the Application Load Balancer"
  value       = aws_security_group.alb_sg.id
}

output "target_group_arns" {
  description = "ARNs of the target groups for each frontend application"
  value = {
    for app, tg in aws_lb_target_group.frontend_apps : app => tg.arn
  }
}

output "target_group_arn_suffixes" {
  description = "ARN suffixes of the target groups for each frontend application"
  value = {
    for app, tg in aws_lb_target_group.frontend_apps : app => tg.arn_suffix
  }
}

output "target_group_names" {
  description = "Names of the target groups for each frontend application"
  value = {
    for app, tg in aws_lb_target_group.frontend_apps : app => tg.name
  }
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.frontend_http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.frontend_https.arn
}

output "listener_rule_arns" {
  description = "ARNs of the listener rules for each frontend application"
  value = {
    for app, rule in aws_lb_listener_rule.frontend_routing : app => rule.arn
  }
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group (if enabled)"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.alb_logs[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group (if enabled)"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.alb_logs[0].arn : null
}

output "alb_hosted_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer (for Route53 alias records)"
  value       = aws_lb.frontend_alb.zone_id
}

output "frontend_applications_config" {
  description = "Configuration of frontend applications"
  value = {
    for app, config in var.frontend_applications : app => {
      port              = config.port
      priority          = config.priority
      health_check_path = config.health_check_path
      target_group_arn  = aws_lb_target_group.frontend_apps[app].arn
    }
  }
}