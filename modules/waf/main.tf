# WAF Module for Application Security
# This module creates AWS WAF v2 Web ACL for protecting the streaming platform

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# CloudWatch Log Group for WAF logs
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/wafv2/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-${var.environment}-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: AWS Managed Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclude rules that might interfere with streaming
        dynamic "rule_action_override" {
          for_each = var.excluded_common_rules
          content {
            action_to_use {
              allow {}
            }
            name = rule_action_override.value
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Known Bad Inputs Rule Set
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Rate Limiting
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"

        scope_down_statement {
          not_statement {
            statement {
              byte_match_statement {
                search_string = "/health"
                field_to_match {
                  uri_path {}
                }
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
                positional_constraint = "STARTS_WITH"
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-RateLimit"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Geographic Restrictions (if enabled)
  dynamic "rule" {
    for_each = var.enable_geo_blocking ? [1] : []
    content {
      name     = "GeoBlockRule"
      priority = 4

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-GeoBlock"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 5: IP Whitelist (if enabled)
  dynamic "rule" {
    for_each = length(var.allowed_ip_ranges) > 0 ? [1] : []
    content {
      name     = "IPWhitelistRule"
      priority = 5

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed_ips[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-IPWhitelist"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 6: SQL Injection Protection
  rule {
    name     = "SQLInjectionRule"
    priority = 6

    action {
      block {}
    }

    statement {
      sqli_match_statement {
        field_to_match {
          all_query_arguments {}
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 1
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-SQLInjection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 7: XSS Protection
  rule {
    name     = "XSSRule"
    priority = 7

    action {
      block {}
    }

    statement {
      xss_match_statement {
        field_to_match {
          all_query_arguments {}
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 1
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-XSS"
      sampled_requests_enabled   = true
    }
  }

  # Rule 8: Size Restrictions
  rule {
    name     = "SizeRestrictionsRule"
    priority = 8

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          size_constraint_statement {
            field_to_match {
              body {}
            }
            comparison_operator = "GT"
            size                = var.max_request_body_size
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          size_constraint_statement {
            field_to_match {
              single_header {
                name = "content-length"
              }
            }
            comparison_operator = "GT"
            size                = var.max_request_body_size
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-SizeRestrictions"
      sampled_requests_enabled   = true
    }
  }

  # Rule 9: Admin Path Protection (only if admin IPs are configured)
  dynamic "rule" {
    for_each = var.enable_admin_path_protection && length(var.admin_ip_ranges) > 0 ? [1] : []
    content {
      name     = "AdminPathProtection"
      priority = 9

      action {
        block {}
      }

      statement {
        and_statement {
          statement {
            byte_match_statement {
              search_string = "/admin"
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
              positional_constraint = "STARTS_WITH"
            }
          }
          statement {
            not_statement {
              statement {
                ip_set_reference_statement {
                  arn = aws_wafv2_ip_set.admin_ips[0].arn
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-AdminPathProtection"
        sampled_requests_enabled   = true
      }
    }
  }

  tags = var.tags

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-WebACL"
    sampled_requests_enabled   = true
  }
}

# IP Set for allowed IPs
resource "aws_wafv2_ip_set" "allowed_ips" {
  count = length(var.allowed_ip_ranges) > 0 ? 1 : 0

  name               = "${var.project_name}-${var.environment}-allowed-ips"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.allowed_ip_ranges

  tags = var.tags
}

# IP Set for admin IPs
resource "aws_wafv2_ip_set" "admin_ips" {
  count = length(var.admin_ip_ranges) > 0 ? 1 : 0

  name               = "${var.project_name}-${var.environment}-admin-ips"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.admin_ip_ranges

  tags = var.tags
}

# WAF Logging Configuration - Disabled for now
# WAF logging requires Kinesis Data Firehose, not CloudWatch logs directly
# resource "aws_wafv2_web_acl_logging_configuration" "main" {
#   resource_arn            = aws_wafv2_web_acl.main.arn
#   log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
# }

# CloudWatch Alarms for WAF
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  count = var.enable_waf_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.blocked_requests_threshold
  alarm_description   = "This metric monitors WAF blocked requests"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = data.aws_region.current.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_triggered" {
  count = var.enable_waf_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-waf-rate-limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "${var.project_name}-${var.environment}-RateLimit"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.rate_limit_alarm_threshold
  alarm_description   = "This metric monitors WAF rate limiting"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = data.aws_region.current.name
  }

  tags = var.tags
}