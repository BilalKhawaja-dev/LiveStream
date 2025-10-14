# Outputs for ACM Certificate Module

# Primary Certificate
output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = var.domain_name != "" ? aws_acm_certificate_validation.main[0].certificate_arn : null
}

output "certificate_domain_name" {
  description = "Domain name of the certificate"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].domain_name : null
}

output "certificate_status" {
  description = "Status of the certificate"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].status : null
}

# Wildcard Certificate
output "wildcard_certificate_arn" {
  description = "ARN of the wildcard ACM certificate"
  value       = var.enable_wildcard_certificate && var.domain_name != "" ? aws_acm_certificate_validation.wildcard[0].certificate_arn : null
}

output "wildcard_certificate_domain_name" {
  description = "Domain name of the wildcard certificate"
  value       = var.enable_wildcard_certificate && var.domain_name != "" ? aws_acm_certificate.wildcard[0].domain_name : null
}

# Route53 Records
output "domain_validation_records" {
  description = "Domain validation records for manual DNS setup"
  value = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}
}

output "route53_record_fqdn" {
  description = "FQDN of the Route53 A record"
  value       = var.domain_name != "" && var.alb_dns_name != "" ? aws_route53_record.alb[0].fqdn : null
}

# Certificate Information
output "certificate_info" {
  description = "Certificate information summary"
  value = var.domain_name != "" ? {
    domain_name               = aws_acm_certificate.main[0].domain_name
    subject_alternative_names = aws_acm_certificate.main[0].subject_alternative_names
    certificate_arn           = aws_acm_certificate_validation.main[0].certificate_arn
    validation_method         = aws_acm_certificate.main[0].validation_method

    wildcard_enabled         = var.enable_wildcard_certificate
    wildcard_certificate_arn = var.enable_wildcard_certificate ? aws_acm_certificate_validation.wildcard[0].certificate_arn : null

    monitoring_enabled    = var.enable_certificate_monitoring
    expiry_threshold_days = var.certificate_expiry_threshold_days

    route53_integration = var.alb_dns_name != ""
    ipv6_enabled        = var.enable_ipv6
  } : null
}

# For use in other modules
output "use_ssl" {
  description = "Whether SSL is configured and should be used"
  value       = var.domain_name != ""
}

output "primary_domain" {
  description = "Primary domain name for the application"
  value       = var.domain_name
}