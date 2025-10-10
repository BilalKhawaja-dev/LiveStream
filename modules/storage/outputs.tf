# Outputs for S3 Storage Module

# KMS Key Outputs
output "kms_key_id" {
  description = "ID of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3_encryption.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3_encryption.arn
}

output "kms_alias_name" {
  description = "Alias name of the KMS key"
  value       = aws_kms_alias.s3_encryption.name
}

# Streaming Logs Bucket Outputs
output "streaming_logs_bucket_id" {
  description = "ID of the streaming logs S3 bucket"
  value       = aws_s3_bucket.streaming_logs.id
}

output "streaming_logs_bucket_arn" {
  description = "ARN of the streaming logs S3 bucket"
  value       = aws_s3_bucket.streaming_logs.arn
}

output "streaming_logs_bucket_domain_name" {
  description = "Domain name of the streaming logs S3 bucket"
  value       = aws_s3_bucket.streaming_logs.bucket_domain_name
}

# Error Logs Bucket Outputs
output "error_logs_bucket_id" {
  description = "ID of the error logs S3 bucket"
  value       = aws_s3_bucket.error_logs.id
}

output "error_logs_bucket_arn" {
  description = "ARN of the error logs S3 bucket"
  value       = aws_s3_bucket.error_logs.arn
}

output "error_logs_bucket_domain_name" {
  description = "Domain name of the error logs S3 bucket"
  value       = aws_s3_bucket.error_logs.bucket_domain_name
}

# Backups Bucket Outputs
output "backups_bucket_id" {
  description = "ID of the backups S3 bucket"
  value       = aws_s3_bucket.backups.id
}

output "backups_bucket_arn" {
  description = "ARN of the backups S3 bucket"
  value       = aws_s3_bucket.backups.arn
}

output "backups_bucket_domain_name" {
  description = "Domain name of the backups S3 bucket"
  value       = aws_s3_bucket.backups.bucket_domain_name
}

# Athena Results Bucket Outputs
output "athena_results_bucket_id" {
  description = "ID of the Athena results S3 bucket"
  value       = aws_s3_bucket.athena_results.id
}

output "athena_results_bucket_arn" {
  description = "ARN of the Athena results S3 bucket"
  value       = aws_s3_bucket.athena_results.arn
}

output "athena_results_bucket_domain_name" {
  description = "Domain name of the Athena results S3 bucket"
  value       = aws_s3_bucket.athena_results.bucket_domain_name
}

# Bucket Names for Reference
output "bucket_names" {
  description = "Map of all bucket names for easy reference"
  value = {
    streaming_logs  = aws_s3_bucket.streaming_logs.id
    error_logs      = aws_s3_bucket.error_logs.id
    backups         = aws_s3_bucket.backups.id
    athena_results  = aws_s3_bucket.athena_results.id
  }
}