# ACM Certificate Module for SSL/TLS termination
# This module creates and validates SSL certificates for the streaming platform

# Data sources
data "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

# ACM Certificate
resource "aws_acm_certificate" "main" {
  count = var.domain_name != "" ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-certificate"
  })
}

# Route53 records for certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  count = var.domain_name != "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# CloudWatch Log Group for certificate monitoring
resource "aws_cloudwatch_log_group" "certificate_logs" {
  count = var.domain_name != "" && var.enable_certificate_monitoring ? 1 : 0

  name              = "/aws/acm/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# CloudWatch Alarm for certificate expiration
resource "aws_cloudwatch_metric_alarm" "certificate_expiry" {
  count = var.domain_name != "" && var.enable_certificate_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-certificate-expiry"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry"
  namespace           = "AWS/CertificateManager"
  period              = "86400" # 24 hours
  statistic           = "Average"
  threshold           = var.certificate_expiry_threshold_days
  alarm_description   = "This metric monitors SSL certificate expiry"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "breaching"

  dimensions = {
    CertificateArn = aws_acm_certificate.main[0].arn
  }

  tags = var.tags
}

# Route53 A record for ALB
resource "aws_route53_record" "alb" {
  count = var.domain_name != "" && var.alb_dns_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Route53 AAAA record for ALB (IPv6)
resource "aws_route53_record" "alb_ipv6" {
  count = var.domain_name != "" && var.alb_dns_name != "" && var.enable_ipv6 ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Wildcard certificate for subdomains (optional)
resource "aws_acm_certificate" "wildcard" {
  count = var.enable_wildcard_certificate && var.domain_name != "" ? 1 : 0

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-wildcard-certificate"
  })
}

# Route53 records for wildcard certificate validation
resource "aws_route53_record" "wildcard_cert_validation" {
  for_each = var.enable_wildcard_certificate && var.domain_name != "" ? {
    for dvo in aws_acm_certificate.wildcard[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

# Wildcard certificate validation
resource "aws_acm_certificate_validation" "wildcard" {
  count = var.enable_wildcard_certificate && var.domain_name != "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.wildcard[0].arn
  validation_record_fqdns = [for record in aws_route53_record.wildcard_cert_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}