# Outputs for Media Services Module

# S3 Buckets
output "media_content_bucket_id" {
  description = "ID of the media content S3 bucket"
  value       = aws_s3_bucket.media_content.id
}

output "media_content_bucket_arn" {
  description = "ARN of the media content S3 bucket"
  value       = aws_s3_bucket.media_content.arn
}

output "media_content_bucket_domain_name" {
  description = "Domain name of the media content S3 bucket"
  value       = aws_s3_bucket.media_content.bucket_domain_name
}

output "media_content_bucket_regional_domain_name" {
  description = "Regional domain name of the media content S3 bucket"
  value       = aws_s3_bucket.media_content.bucket_regional_domain_name
}

output "processed_media_bucket_id" {
  description = "ID of the processed media S3 bucket"
  value       = aws_s3_bucket.processed_media.id
}

output "processed_media_bucket_arn" {
  description = "ARN of the processed media S3 bucket"
  value       = aws_s3_bucket.processed_media.arn
}

# CloudFront Distribution
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.media_distribution[0].id : null
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.media_distribution[0].arn : null
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.media_distribution[0].domain_name : null
}

output "cloudfront_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.media_distribution[0].hosted_zone_id : null
}

# Origin Access Control
output "origin_access_control_id" {
  description = "ID of the CloudFront Origin Access Control"
  value       = aws_cloudfront_origin_access_control.media_oac.id
}

# Response Headers Policy
output "response_headers_policy_id" {
  description = "ID of the CloudFront response headers policy"
  value       = aws_cloudfront_response_headers_policy.media_headers.id
}

# CloudWatch Log Group
output "log_group_name" {
  description = "Name of the CloudWatch log group for media processing"
  value       = aws_cloudwatch_log_group.media_processing.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for media processing"
  value       = aws_cloudwatch_log_group.media_processing.arn
}

# Media URLs
output "media_base_url" {
  description = "Base URL for media content access"
  value = var.enable_cloudfront ? (
    var.custom_domain != "" ?
    "https://${var.custom_domain}" :
    "https://${aws_cloudfront_distribution.media_distribution[0].domain_name}"
  ) : "https://${aws_s3_bucket.media_content.bucket_regional_domain_name}"
}

output "processed_media_base_url" {
  description = "Base URL for processed media content access"
  value = var.enable_cloudfront ? (
    var.custom_domain != "" ?
    "https://${var.custom_domain}/processed" :
    "https://${aws_cloudfront_distribution.media_distribution[0].domain_name}/processed"
  ) : "https://${aws_s3_bucket.processed_media.bucket_regional_domain_name}"
}

# Configuration Summary
output "media_services_configuration" {
  description = "Summary of media services configuration"
  value = {
    # S3 Configuration
    s3_buckets = {
      media_content = {
        name               = aws_s3_bucket.media_content.id
        arn                = aws_s3_bucket.media_content.arn
        versioning_enabled = var.enable_versioning
        encryption_enabled = true
      }
      processed_media = {
        name               = aws_s3_bucket.processed_media.id
        arn                = aws_s3_bucket.processed_media.arn
        versioning_enabled = false
        encryption_enabled = true
      }
    }

    # Lifecycle Configuration
    lifecycle_policies = {
      ia_transition_days                 = var.ia_transition_days
      glacier_transition_days            = var.glacier_transition_days
      deep_archive_transition_days       = var.deep_archive_transition_days
      noncurrent_version_expiration_days = var.noncurrent_version_expiration_days
    }

    # CloudFront Configuration
    cloudfront = {
      enabled         = var.enable_cloudfront
      distribution_id = var.enable_cloudfront ? aws_cloudfront_distribution.media_distribution[0].id : null
      domain_name     = var.enable_cloudfront ? aws_cloudfront_distribution.media_distribution[0].domain_name : null
      custom_domain   = var.custom_domain
      price_class     = var.cloudfront_price_class
      ipv6_enabled    = var.enable_ipv6
    }

    # Security Configuration
    security = {
      waf_enabled                   = var.waf_web_acl_arn != ""
      origin_access_control_enabled = true
      ssl_certificate_arn           = var.ssl_certificate_arn
      geo_restrictions = {
        type      = var.geo_restriction_type
        locations = var.geo_restriction_locations
      }
    }

    # Monitoring Configuration
    monitoring = {
      enabled                  = var.enable_monitoring
      s3_size_threshold_gb     = var.s3_size_alarm_threshold_gb
      cloudfront_4xx_threshold = var.cloudfront_4xx_threshold
      log_retention_days       = var.log_retention_days
    }

    # Cost Optimization
    cost_optimization = {
      intelligent_tiering_enabled   = var.enable_intelligent_tiering
      transfer_acceleration_enabled = var.enable_transfer_acceleration
      cloudfront_price_class        = var.cloudfront_price_class
    }

    # Access URLs
    urls = {
      media_base_url = var.enable_cloudfront ? (
        var.custom_domain != "" ?
        "https://${var.custom_domain}" :
        "https://${aws_cloudfront_distribution.media_distribution[0].domain_name}"
      ) : "https://${aws_s3_bucket.media_content.bucket_regional_domain_name}"

      processed_media_base_url = var.enable_cloudfront ? (
        var.custom_domain != "" ?
        "https://${var.custom_domain}/processed" :
        "https://${aws_cloudfront_distribution.media_distribution[0].domain_name}/processed"
      ) : "https://${aws_s3_bucket.processed_media.bucket_regional_domain_name}"
    }
  }
}

# For integration with other modules
output "bucket_names" {
  description = "Map of bucket names for other modules"
  value = {
    media_content   = aws_s3_bucket.media_content.id
    processed_media = aws_s3_bucket.processed_media.id
  }
}

output "bucket_arns" {
  description = "Map of bucket ARNs for IAM policies"
  value = {
    media_content   = aws_s3_bucket.media_content.arn
    processed_media = aws_s3_bucket.processed_media.arn
  }
}