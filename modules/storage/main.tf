# S3 Storage Module for Centralized Logging Infrastructure

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Data source for current AWS region
data "aws_region" "current" {}

# KMS Key for S3 bucket encryption
resource "aws_kms_key" "s3_encryption" {
  description             = "KMS key for S3 bucket encryption - ${var.project_name}-${var.environment}"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-s3-encryption"
  })
}

resource "aws_kms_alias" "s3_encryption" {
  name          = "alias/${var.project_name}-${var.environment}-s3-encryption"
  target_key_id = aws_kms_key.s3_encryption.key_id
}

# S3 Bucket for Streaming Logs
resource "aws_s3_bucket" "streaming_logs" {
  bucket = "${var.project_name}-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name      = "${var.project_name}-logs-${var.environment}"
    Purpose   = "Streaming application logs storage"
    DataType  = "Logs"
    Retention = "1-year"
  })
}

# S3 Bucket for Error Logs
resource "aws_s3_bucket" "error_logs" {
  bucket = "${var.project_name}-errors-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name      = "${var.project_name}-errors-${var.environment}"
    Purpose   = "Failed log processing and error storage"
    DataType  = "ErrorLogs"
    Retention = "1-year"
  })
}

# S3 Bucket for Backups
resource "aws_s3_bucket" "backups" {
  bucket = "${var.project_name}-backups-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name      = "${var.project_name}-backups-${var.environment}"
    Purpose   = "Database and application backups"
    DataType  = "Backups"
    Retention = "1-year"
  })
}

# S3 Bucket for Athena Query Results
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-query-results-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name      = "${var.project_name}-query-results-${var.environment}"
    Purpose   = "Athena query results and temporary data"
    DataType  = "QueryResults"
    Retention = "30-days"
  })
}

# Versioning Configuration for Streaming Logs Bucket
resource "aws_s3_bucket_versioning" "streaming_logs" {
  bucket = aws_s3_bucket.streaming_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Versioning Configuration for Error Logs Bucket
resource "aws_s3_bucket_versioning" "error_logs" {
  bucket = aws_s3_bucket.error_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Versioning Configuration for Backups Bucket
resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Versioning Configuration for Athena Results Bucket
resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for Streaming Logs Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "streaming_logs" {
  bucket = aws_s3_bucket.streaming_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Server-side encryption for Error Logs Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "error_logs" {
  bucket = aws_s3_bucket.error_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Server-side encryption for Backups Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Server-side encryption for Athena Results Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Public access blocking for Streaming Logs Bucket
resource "aws_s3_bucket_public_access_block" "streaming_logs" {
  bucket = aws_s3_bucket.streaming_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Public access blocking for Error Logs Bucket
resource "aws_s3_bucket_public_access_block" "error_logs" {
  bucket = aws_s3_bucket.error_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Public access blocking for Backups Bucket
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Public access blocking for Athena Results Bucket
resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Configuration for Streaming Logs Bucket
resource "aws_s3_bucket_lifecycle_configuration" "streaming_logs" {
  bucket = aws_s3_bucket.streaming_logs.id

  rule {
    id     = "streaming_logs_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Current version transitions
    transition {
      days          = var.hot_tier_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.warm_tier_days
      storage_class = "GLACIER"
    }

    # Delete current version after cold tier retention
    expiration {
      days = var.cold_tier_days
    }

    # Noncurrent version management
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    # Abort incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.streaming_logs]
}

# Lifecycle Configuration for Error Logs Bucket
resource "aws_s3_bucket_lifecycle_configuration" "error_logs" {
  bucket = aws_s3_bucket.error_logs.id

  rule {
    id     = "error_logs_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Current version transitions
    transition {
      days          = var.hot_tier_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.warm_tier_days
      storage_class = "GLACIER"
    }

    # Delete current version after cold tier retention
    expiration {
      days = var.cold_tier_days
    }

    # Noncurrent version management
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    # Abort incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.error_logs]
}

# Lifecycle Configuration for Backups Bucket
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "backups_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Current version transitions - Keep backups in Standard for quick access
    transition {
      days          = var.hot_tier_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.warm_tier_days
      storage_class = "GLACIER"
    }

    # Delete current version after cold tier retention
    expiration {
      days = var.cold_tier_days
    }

    # Noncurrent version management
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    # Abort incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.backups]
}

# Lifecycle Configuration for Athena Results Bucket
resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "athena_results_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Athena results have shorter retention - delete after 30 days
    expiration {
      days = var.athena_results_retention_days
    }

    # Noncurrent version management - shorter retention for query results
    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    # Abort incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.athena_results]
}

# Intelligent Tiering Configuration for Streaming Logs (Optional cost optimization)
resource "aws_s3_bucket_intelligent_tiering_configuration" "streaming_logs" {
  bucket = aws_s3_bucket.streaming_logs.id
  name   = "streaming_logs_intelligent_tiering"

  # Apply to all objects
  filter {
    prefix = ""
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

# Intelligent Tiering Configuration for Backups (Optional cost optimization)
resource "aws_s3_bucket_intelligent_tiering_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  name   = "backups_intelligent_tiering"

  # Apply to all objects
  filter {
    prefix = ""
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}