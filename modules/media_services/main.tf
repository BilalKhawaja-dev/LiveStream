# Media Services Module for Streaming Platform
# This module creates S3 buckets, CloudFront distribution, and media processing infrastructure

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# S3 Bucket for media content storage
resource "aws_s3_bucket" "media_content" {
  bucket = "${var.project_name}-${var.environment}-media-content-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-media-content"
    Type = "MediaStorage"
  })
}

# Random suffix for bucket names to ensure uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "media_content" {
  bucket = aws_s3_bucket.media_content.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "media_content" {
  bucket = aws_s3_bucket.media_content.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "media_content" {
  bucket = aws_s3_bucket.media_content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "media_content" {
  bucket = aws_s3_bucket.media_content.id

  rule {
    id     = "media_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Transition to IA after 30 days
    transition {
      days          = var.ia_transition_days
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = var.glacier_transition_days
      storage_class = "GLACIER"
    }

    # Transition to Deep Archive after 365 days
    transition {
      days          = var.deep_archive_transition_days
      storage_class = "DEEP_ARCHIVE"
    }

    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Delete old versions after specified days
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  # Rule for temporary uploads cleanup
  rule {
    id     = "temp_uploads_cleanup"
    status = "Enabled"

    filter {
      prefix = "temp/"
    }

    expiration {
      days = 1
    }
  }
}

# S3 Bucket for processed media (thumbnails, transcoded videos)
resource "aws_s3_bucket" "processed_media" {
  bucket = "${var.project_name}-${var.environment}-processed-media-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-processed-media"
    Type = "ProcessedMedia"
  })
}

# Processed media bucket configuration
resource "aws_s3_bucket_versioning" "processed_media" {
  bucket = aws_s3_bucket.processed_media.id
  versioning_configuration {
    status = "Suspended" # No versioning needed for processed media
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_media" {
  bucket = aws_s3_bucket.processed_media.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "processed_media" {
  bucket = aws_s3_bucket.processed_media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "media_oac" {
  name                              = "${var.project_name}-${var.environment}-media-oac"
  description                       = "OAC for media content distribution"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "media_distribution" {
  count = var.enable_cloudfront ? 1 : 0

  # S3 Origin for media content
  origin {
    domain_name              = aws_s3_bucket.media_content.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.media_oac.id
    origin_id                = "S3-${aws_s3_bucket.media_content.bucket}"

    # Custom headers for origin requests
    custom_header {
      name  = "X-Forwarded-Host"
      value = var.custom_domain != "" ? var.custom_domain : "media.${var.project_name}.com"
    }
  }

  # S3 Origin for processed media
  origin {
    domain_name              = aws_s3_bucket.processed_media.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.media_oac.id
    origin_id                = "S3-${aws_s3_bucket.processed_media.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  comment             = "Media distribution for ${var.project_name}"
  default_root_object = "index.html"

  # Aliases (custom domains)
  aliases = var.custom_domain != "" ? [var.custom_domain] : []

  # Default cache behavior for media content
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.media_content.bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = var.default_cache_ttl
    max_ttl     = var.max_cache_ttl

    # Response headers policy
    response_headers_policy_id = aws_cloudfront_response_headers_policy.media_headers.id
  }

  # Cache behavior for processed media (longer TTL)
  ordered_cache_behavior {
    path_pattern           = "/processed/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.processed_media.bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 86400    # 1 day
    default_ttl = 604800   # 1 week
    max_ttl     = 31536000 # 1 year
  }

  # Cache behavior for HLS streaming
  ordered_cache_behavior {
    path_pattern           = "*.m3u8"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.media_content.bucket}"
    compress               = false # Don't compress streaming manifests
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 10 # Short TTL for live streaming
    max_ttl     = 60
  }

  # Cache behavior for video segments
  ordered_cache_behavior {
    path_pattern           = "*.ts"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.media_content.bucket}"
    compress               = false
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 86400    # 1 day
    default_ttl = 604800   # 1 week
    max_ttl     = 31536000 # 1 year
  }

  # Price class for cost optimization
  price_class = var.cloudfront_price_class

  # Geographic restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # SSL certificate configuration
  viewer_certificate {
    cloudfront_default_certificate = var.custom_domain == ""
    acm_certificate_arn            = var.custom_domain != "" ? var.ssl_certificate_arn : null
    ssl_support_method             = var.custom_domain != "" ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  # Web Application Firewall
  web_acl_id = var.waf_web_acl_arn

  # Logging configuration (only if bucket is specified)
  dynamic "logging_config" {
    for_each = var.access_logs_bucket != "" ? [1] : []
    content {
      include_cookies = false
      bucket          = "${var.access_logs_bucket}.s3.amazonaws.com"
      prefix          = "cloudfront-logs/"
    }
  }

  tags = var.tags
}

# CloudFront Response Headers Policy
resource "aws_cloudfront_response_headers_policy" "media_headers" {
  name    = "${var.project_name}-${var.environment}-media-headers"
  comment = "Security and CORS headers for media content"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    }

    access_control_allow_origins {
      items = var.cors_allowed_origins
    }

    access_control_expose_headers {
      items = ["ETag", "Content-Length", "Content-Type"]
    }

    access_control_max_age_sec = 86400
    origin_override            = false
  }

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
  }
}

# S3 Bucket Policy for CloudFront OAC
resource "aws_s3_bucket_policy" "media_content_policy" {
  bucket = aws_s3_bucket.media_content.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.media_content.arn}/*"
        Condition = var.enable_cloudfront ? {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.media_distribution[0].arn
          }
        } : {}
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "processed_media_policy" {
  bucket = aws_s3_bucket.processed_media.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.processed_media.arn}/*"
        Condition = var.enable_cloudfront ? {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.media_distribution[0].arn
          }
        } : {}
      }
    ]
  })
}

# CloudWatch Log Group for media processing
resource "aws_cloudwatch_log_group" "media_processing" {
  name              = "/aws/media/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# CloudWatch Alarms for S3 bucket monitoring
resource "aws_cloudwatch_metric_alarm" "s3_bucket_size" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-s3-bucket-size"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = "86400" # Daily
  statistic           = "Average"
  threshold           = var.s3_size_alarm_threshold_gb * 1073741824 # Convert GB to bytes
  alarm_description   = "This metric monitors S3 bucket size"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName  = aws_s3_bucket.media_content.bucket
    StorageType = "StandardStorage"
  }

  tags = var.tags
}

# CloudWatch Alarm for CloudFront errors
resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx_errors" {
  count = var.enable_cloudfront && var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cloudfront_4xx_threshold
  alarm_description   = "This metric monitors CloudFront 4xx error rate"
  alarm_actions       = var.sns_topic_arns
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.media_distribution[0].id
  }

  tags = var.tags
}