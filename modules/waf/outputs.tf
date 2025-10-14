# Outputs for WAF Module

# WAF Web ACL
output "web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_name" {
  description = "WAF Web ACL name"
  value       = aws_wafv2_web_acl.main.name
}

output "web_acl_capacity" {
  description = "WAF Web ACL capacity units used"
  value       = aws_wafv2_web_acl.main.capacity
}

# IP Sets
output "allowed_ip_set_id" {
  description = "Allowed IP set ID"
  value       = length(aws_wafv2_ip_set.allowed_ips) > 0 ? aws_wafv2_ip_set.allowed_ips[0].id : null
}

output "allowed_ip_set_arn" {
  description = "Allowed IP set ARN"
  value       = length(aws_wafv2_ip_set.allowed_ips) > 0 ? aws_wafv2_ip_set.allowed_ips[0].arn : null
}

output "admin_ip_set_id" {
  description = "Admin IP set ID"
  value       = length(aws_wafv2_ip_set.admin_ips) > 0 ? aws_wafv2_ip_set.admin_ips[0].id : null
}

output "admin_ip_set_arn" {
  description = "Admin IP set ARN"
  value       = length(aws_wafv2_ip_set.admin_ips) > 0 ? aws_wafv2_ip_set.admin_ips[0].arn : null
}

# Logging
output "log_group_name" {
  description = "CloudWatch log group name for WAF logs"
  value       = aws_cloudwatch_log_group.waf_logs.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for WAF logs"
  value       = aws_cloudwatch_log_group.waf_logs.arn
}

# Configuration Summary
output "waf_configuration_summary" {
  description = "Summary of WAF configuration"
  value = {
    web_acl_name            = aws_wafv2_web_acl.main.name
    rate_limit_per_5min     = var.rate_limit_per_5min
    geo_blocking_enabled    = var.enable_geo_blocking
    blocked_countries       = var.blocked_countries
    allowed_ip_ranges_count = length(var.allowed_ip_ranges)
    admin_ip_ranges_count   = length(var.admin_ip_ranges)
    max_request_body_size   = var.max_request_body_size

    protection_features = {
      sql_injection_protection = var.enable_sql_injection_protection
      xss_protection           = var.enable_xss_protection
      size_restrictions        = var.enable_size_restrictions
      admin_path_protection    = var.enable_admin_path_protection
    }

    managed_rule_groups = [
      "AWSManagedRulesCommonRuleSet",
      "AWSManagedRulesKnownBadInputsRuleSet"
    ]

    custom_rules = [
      "RateLimitRule",
      "SQLInjectionRule",
      "XSSRule",
      "SizeRestrictionsRule",
      "AdminPathProtection"
    ]

    monitoring = {
      alarms_enabled             = var.enable_waf_alarms
      blocked_requests_threshold = var.blocked_requests_threshold
      rate_limit_alarm_threshold = var.rate_limit_alarm_threshold
    }
  }
}