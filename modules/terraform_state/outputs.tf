# Terraform State Management Outputs

# S3 bucket information
output "state_bucket_name" {
  description = "Name of the Terraform state S3 bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "Region of the Terraform state S3 bucket"
  value       = aws_s3_bucket.terraform_state.region
}

# DynamoDB table information
output "lock_table_name" {
  description = "Name of the DynamoDB lock table"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "lock_table_arn" {
  description = "ARN of the DynamoDB lock table"
  value       = aws_dynamodb_table.terraform_state_lock.arn
}

# KMS key information
output "kms_key_id" {
  description = "ID of the KMS key used for state encryption"
  value       = aws_kms_key.terraform_state.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for state encryption"
  value       = aws_kms_key.terraform_state.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key used for state encryption"
  value       = aws_kms_alias.terraform_state.name
}

# IAM resources
output "state_access_policy_arn" {
  description = "ARN of the Terraform state access policy"
  value       = aws_iam_policy.terraform_state_access.arn
}

output "cicd_role_arn" {
  description = "ARN of the CI/CD role for Terraform operations"
  value       = var.create_cicd_role ? aws_iam_role.terraform_cicd_role[0].arn : null
}

output "cicd_role_name" {
  description = "Name of the CI/CD role for Terraform operations"
  value       = var.create_cicd_role ? aws_iam_role.terraform_cicd_role[0].name : null
}

# Backup information
output "backup_bucket_name" {
  description = "Name of the state backup S3 bucket"
  value       = var.enable_state_backup ? aws_s3_bucket.terraform_state_backup[0].bucket : null
}

output "backup_bucket_arn" {
  description = "ARN of the state backup S3 bucket"
  value       = var.enable_state_backup ? aws_s3_bucket.terraform_state_backup[0].arn : null
}

# Backend configuration
output "backend_config" {
  description = "Terraform backend configuration"
  value = {
    bucket         = aws_s3_bucket.terraform_state.bucket
    key            = var.default_workspace_key
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.terraform_state_lock.name
    encrypt        = true
    kms_key_id     = aws_kms_key.terraform_state.arn
  }
}

# Backend configuration for different environments
output "backend_config_by_environment" {
  description = "Environment-specific backend configurations"
  value = {
    dev = {
      bucket         = aws_s3_bucket.terraform_state.bucket
      key            = "dev/terraform.tfstate"
      region         = data.aws_region.current.name
      dynamodb_table = aws_dynamodb_table.terraform_state_lock.name
      encrypt        = true
      kms_key_id     = aws_kms_key.terraform_state.arn
    }
    staging = {
      bucket         = aws_s3_bucket.terraform_state.bucket
      key            = "staging/terraform.tfstate"
      region         = data.aws_region.current.name
      dynamodb_table = aws_dynamodb_table.terraform_state_lock.name
      encrypt        = true
      kms_key_id     = aws_kms_key.terraform_state.arn
    }
    prod = {
      bucket         = aws_s3_bucket.terraform_state.bucket
      key            = "prod/terraform.tfstate"
      region         = data.aws_region.current.name
      dynamodb_table = aws_dynamodb_table.terraform_state_lock.name
      encrypt        = true
      kms_key_id     = aws_kms_key.terraform_state.arn
    }
  }
}

# Configuration summary
output "state_management_summary" {
  description = "Summary of Terraform state management configuration"
  value = {
    state_bucket_name = aws_s3_bucket.terraform_state.bucket
    lock_table_name   = aws_dynamodb_table.terraform_state_lock.name
    kms_key_alias     = aws_kms_alias.terraform_state.name
    backup_enabled    = var.enable_state_backup
    monitoring_enabled = var.enable_state_monitoring
    cicd_role_created = var.create_cicd_role
    environment       = var.environment
    region           = data.aws_region.current.name
  }
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}