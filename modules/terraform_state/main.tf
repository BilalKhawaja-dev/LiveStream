# Terraform State Management Module
# Requirements: 4.3, 4.4

# S3 bucket for Terraform state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${var.environment}-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-terraform-state-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "terraform-state"
  }
}

# Random suffix for bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "terraform_state_lifecycle"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.state_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# KMS key for state encryption
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Terraform state access"
        Effect = "Allow"
        Principal = {
          AWS = var.terraform_users_arns
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-terraform-state-key-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "terraform-state"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${var.project_name}-terraform-state-${var.environment}"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${var.project_name}-terraform-state-lock-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.terraform_state.arn
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  tags = {
    Name        = "${var.project_name}-terraform-state-lock-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "terraform-state-lock"
  }
}

# IAM policy for Terraform state access
resource "aws_iam_policy" "terraform_state_access" {
  name        = "${var.project_name}-terraform-state-access-${var.environment}"
  description = "Policy for Terraform state access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_state_lock.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.terraform_state.arn
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-terraform-state-access-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "terraform-state"
  }
}

# IAM role for CI/CD pipeline
resource "aws_iam_role" "terraform_cicd_role" {
  count = var.create_cicd_role ? 1 : 0
  
  name = "${var.project_name}-terraform-cicd-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.cicd_role_trusted_arns
        }
        Condition = var.require_external_id ? {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        } : {}
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-terraform-cicd-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "terraform-cicd"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_cicd_state_access" {
  count = var.create_cicd_role ? 1 : 0
  
  role       = aws_iam_role.terraform_cicd_role[0].name
  policy_arn = aws_iam_policy.terraform_state_access.arn
}

# State backup configuration
resource "aws_s3_bucket" "terraform_state_backup" {
  count = var.enable_state_backup ? 1 : 0
  
  bucket = "${var.project_name}-terraform-state-backup-${var.environment}-${random_id.backup_bucket_suffix[0].hex}"

  tags = {
    Name        = "${var.project_name}-terraform-state-backup-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "terraform-state-backup"
  }
}

resource "random_id" "backup_bucket_suffix" {
  count = var.enable_state_backup ? 1 : 0
  
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "terraform_state_backup" {
  count = var.enable_state_backup ? 1 : 0
  
  bucket = aws_s3_bucket.terraform_state_backup[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_backup" {
  count = var.enable_state_backup ? 1 : 0
  
  bucket = aws_s3_bucket.terraform_state_backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 replication for state backup
resource "aws_iam_role" "replication_role" {
  count = var.enable_state_backup ? 1 : 0
  
  name = "${var.project_name}-terraform-state-replication-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication_policy" {
  count = var.enable_state_backup ? 1 : 0
  
  name = "${var.project_name}-terraform-state-replication-policy-${var.environment}"
  role = aws_iam_role.replication_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "${aws_s3_bucket.terraform_state_backup[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.terraform_state.arn
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "terraform_state_backup" {
  count = var.enable_state_backup ? 1 : 0
  
  role   = aws_iam_role.replication_role[0].arn
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "terraform_state_backup"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.terraform_state_backup[0].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.terraform_state.arn
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.terraform_state]
}

# CloudWatch monitoring for state operations
resource "aws_cloudwatch_log_group" "terraform_state_logs" {
  count = var.enable_state_monitoring ? 1 : 0
  
  name              = "/aws/s3/${aws_s3_bucket.terraform_state.bucket}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.terraform_state.arn

  tags = {
    Name        = "${var.project_name}-terraform-state-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "terraform-state-monitoring"
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}