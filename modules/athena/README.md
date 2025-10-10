# Athena Module

This module creates and configures Amazon Athena workgroups with cost controls and query optimization for the centralized logging infrastructure.

## Features

- **Athena Workgroup**: Creates a workgroup with development-optimized settings
- **Cost Controls**: Implements bytes scanned cutoff per query for cost management
- **Query Result Management**: Configures S3 location for query results with lifecycle policies
- **IAM Roles**: Creates necessary IAM roles and policies for Athena operations
- **CloudWatch Integration**: Optional CloudWatch logging and monitoring
- **Development Optimization**: Environment-specific configurations for cost efficiency

## Resources Created

### Core Resources
- `aws_athena_workgroup.streaming_logs` - Main Athena workgroup
- `aws_athena_database.streaming_logs` - Athena database referencing Glue catalog
- `aws_iam_role.athena_workgroup_role` - IAM role for Athena operations
- `aws_iam_role_policy.athena_workgroup_policy` - IAM policy for S3 and Glue access

### Lifecycle Management
- `aws_s3_bucket_lifecycle_configuration.athena_results_lifecycle` - Lifecycle policy for query results

### Monitoring (Optional)
- `aws_cloudwatch_log_group.athena_query_logs` - CloudWatch log group for query logs
- `aws_cloudwatch_metric_alarm.athena_data_scanned` - Cost monitoring alarm
- `aws_cloudwatch_metric_alarm.athena_query_execution_time` - Performance monitoring alarm

## Configuration

### Development Environment Optimizations

The module includes several development-specific optimizations:

- **Data Scanned Limit**: 1GB per query (vs 10GB for production)
- **Encryption**: SSE-S3 encryption for cost efficiency
- **Query Results Retention**: 30 days (configurable)
- **CloudWatch Metrics**: Optional for cost control

### Cost Controls

- Bytes scanned cutoff per query to prevent runaway costs
- Workgroup configuration enforcement
- Lifecycle policies for automatic cleanup of query results
- CloudWatch alarms for cost and performance monitoring

## Usage

```hcl
module "athena" {
  source = "./modules/athena"

  project_name                = "streaming-logs"
  environment                 = "dev"
  athena_results_bucket_name  = "my-athena-results-bucket"
  athena_results_bucket_arn   = "arn:aws:s3:::my-athena-results-bucket"
  s3_logs_bucket_arn          = "arn:aws:s3:::my-logs-bucket"
  glue_database_name          = "streaming_logs_db"
  kms_key_arn                 = "arn:aws:kms:region:account:key/key-id"
  
  # Optional configurations
  log_retention_days                = 7
  athena_results_retention_days     = 30
  enable_query_logging              = true
  enable_cost_monitoring            = true
  enable_performance_monitoring     = true
  data_scanned_alarm_threshold      = 1073741824  # 1GB
  query_execution_time_threshold    = 300000      # 5 minutes

  tags = {
    Environment = "dev"
    Project     = "centralized-logging"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for resource naming | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| athena_results_bucket_name | Name of the S3 bucket for Athena query results | `string` | n/a | yes |
| athena_results_bucket_arn | ARN of the S3 bucket for Athena query results | `string` | n/a | yes |
| s3_logs_bucket_arn | ARN of the S3 bucket containing logs for querying | `string` | n/a | yes |
| glue_database_name | Name of the Glue database for log analytics | `string` | n/a | yes |
| kms_key_arn | ARN of the KMS key for encryption | `string` | n/a | yes |
| log_retention_days | CloudWatch log retention period in days | `number` | `7` | no |
| athena_results_retention_days | Retention period for Athena query results in days | `number` | `30` | no |
| enable_query_logging | Enable CloudWatch logging for Athena queries | `bool` | `true` | no |
| enable_cost_monitoring | Enable CloudWatch alarms for cost monitoring | `bool` | `true` | no |
| enable_performance_monitoring | Enable CloudWatch alarms for performance monitoring | `bool` | `true` | no |
| data_scanned_alarm_threshold | Threshold for data scanned alarm in bytes | `number` | `1073741824` | no |
| query_execution_time_threshold | Threshold for query execution time alarm in milliseconds | `number` | `300000` | no |
| sns_topic_arn | SNS topic ARN for alarm notifications (optional) | `string` | `null` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| athena_workgroup_name | Name of the Athena workgroup |
| athena_workgroup_arn | ARN of the Athena workgroup |
| athena_database_name | Name of the Athena database |
| athena_workgroup_role_arn | ARN of the IAM role used by the Athena workgroup |
| query_result_location | S3 location for Athena query results |
| workgroup_configuration | Summary of Athena workgroup configuration |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Dependencies

This module depends on:
- S3 storage module (for Athena results bucket)
- Glue Data Catalog module (for database and tables)
- KMS key for encryption (from storage module)

## Notes

- The module is optimized for development environments with cost controls
- Query results are automatically cleaned up based on lifecycle policies
- CloudWatch monitoring is optional and can be disabled for cost savings
- The workgroup enforces configuration to ensure consistent cost controls