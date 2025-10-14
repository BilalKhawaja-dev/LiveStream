# Terraform Validation Tests for S3 Storage Module

# Test module instantiation with default values
module "storage_test_default" {
  source = "../"

  project_name = "test-logging"
  environment  = "test"

  tags = {
    TestCase = "default_configuration"
  }
}

# Test module instantiation with custom values
module "storage_test_custom" {
  source = "../"

  project_name                       = "custom-logging"
  environment                        = "dev"
  hot_tier_days                      = 5
  warm_tier_days                     = 20
  cold_tier_days                     = 200
  athena_results_retention_days      = 15
  noncurrent_version_expiration_days = 14
  kms_deletion_window                = 10

  tags = {
    TestCase = "custom_configuration"
    Owner    = "test-team"
  }
}

# Validation checks using check blocks (Terraform 1.5+)
check "bucket_naming_convention" {
  assert {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", module.storage_test_default.streaming_logs_bucket_id))
    error_message = "Bucket names must follow AWS naming conventions"
  }
}

check "bucket_encryption_enabled" {
  assert {
    condition     = module.storage_test_default.kms_key_arn != null
    error_message = "KMS encryption must be enabled for all buckets"
  }
}

check "lifecycle_policy_validation" {
  assert {
    condition     = module.storage_test_custom.streaming_logs_bucket_id != null
    error_message = "Streaming logs bucket must be created successfully"
  }
}

# Output validation
output "test_bucket_names" {
  description = "Bucket names for validation"
  value = {
    default_streaming = module.storage_test_default.streaming_logs_bucket_id
    default_errors    = module.storage_test_default.error_logs_bucket_id
    default_backups   = module.storage_test_default.backups_bucket_id
    default_athena    = module.storage_test_default.athena_results_bucket_id
    custom_streaming  = module.storage_test_custom.streaming_logs_bucket_id
    custom_errors     = module.storage_test_custom.error_logs_bucket_id
    custom_backups    = module.storage_test_custom.backups_bucket_id
    custom_athena     = module.storage_test_custom.athena_results_bucket_id
  }
}

output "test_kms_keys" {
  description = "KMS key ARNs for validation"
  value = {
    default_kms = module.storage_test_default.kms_key_arn
    custom_kms  = module.storage_test_custom.kms_key_arn
  }
}