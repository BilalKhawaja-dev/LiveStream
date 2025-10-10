# IAM Module

This module creates service-specific IAM roles and policies with least privilege access for the streaming platform's centralized logging system.

## Features

### Service-Specific Roles
- **CloudWatch Logs Role**: Permissions for log publishing and Firehose integration
- **Kinesis Firehose Role**: S3 delivery, KMS encryption, and Glue catalog access
- **S3 Service Role**: Cross-service access and KMS encryption
- **Aurora Service Role**: Database operations, logging, and backup access
- **DynamoDB Service Role**: Table operations, KMS encryption, and streaming
- **Glue Service Role**: Data catalog operations and S3 access
- **Athena Service Role**: Query execution and result storage
- **Lambda Execution Role**: Function execution and cross-service access

### Security Features
- **Least privilege principle**: Each role has minimal required permissions
- **Cross-service integration**: Secure communication between AWS services
- **KMS encryption support**: Access to customer-managed encryption keys
- **Resource-specific permissions**: Scoped to project resources only
- **Environment isolation**: Role names include environment for separation

### Policy Management
- **Inline policies**: Custom policies tailored to specific service needs
- **AWS managed policies**: Standard AWS service policies where appropriate
- **Resource ARN filtering**: Permissions limited to specific resources
- **Conditional access**: Support for MFA and external ID requirements

## Usage

```hcl
module "iam" {
  source = "./modules/iam"
  
  project_name = "streaming-logs"
  environment  = "dev"
  
  # Resource ARNs for cross-service permissions
  s3_bucket_arns       = module.storage.bucket_arns
  kms_key_arns         = [module.storage.kms_key_arn]
  kinesis_firehose_arns = module.kinesis_firehose.delivery_stream_arns
  dynamodb_table_arns  = module.dynamodb.table_arns
  aurora_cluster_arns  = [module.aurora.cluster_arn]
  glue_catalog_arns    = module.glue_catalog.catalog_arns
  
  # Security settings
  require_mfa              = false  # Set to true for production
  max_session_duration     = 3600   # 1 hour
  enable_cross_account_access = false
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Resources Created

### IAM Roles
- `aws_iam_role.cloudwatch_logs_role` - CloudWatch Logs service role
- `aws_iam_role.kinesis_firehose_role` - Kinesis Firehose service role
- `aws_iam_role.s3_service_role` - S3 service role
- `aws_iam_role.aurora_service_role` - Aurora service role
- `aws_iam_role.dynamodb_service_role` - DynamoDB service role
- `aws_iam_role.glue_service_role` - Glue service role
- `aws_iam_role.athena_service_role` - Athena service role
- `aws_iam_role.lambda_execution_role` - Lambda execution role

### IAM Policies
- `aws_iam_role_policy.*` - Custom inline policies for each service
- `aws_iam_role_policy_attachment.*` - AWS managed policy attachments

## Service Role Details

### 1. CloudWatch Logs Role
**Purpose**: Enable CloudWatch Logs to deliver log data to Kinesis Firehose

**Permissions**:
- `firehose:PutRecord`, `firehose:PutRecordBatch` - Send logs to Firehose
- KMS encryption/decryption for log data

**Trust Policy**: `logs.amazonaws.com`

### 2. Kinesis Firehose Role
**Purpose**: Enable Firehose to deliver data to S3 and access Glue catalog

**Permissions**:
- S3 bucket operations (put, get, list objects)
- KMS encryption/decryption for data
- CloudWatch Logs for error logging
- Glue catalog access for table metadata

**Trust Policy**: `firehose.amazonaws.com`

### 3. S3 Service Role
**Purpose**: Enable S3 to perform cross-service operations

**Permissions**:
- KMS encryption/decryption
- CloudWatch Logs for access logging

**Trust Policy**: `s3.amazonaws.com`

### 4. Aurora Service Role
**Purpose**: Enable Aurora to perform backup, logging, and monitoring operations

**Permissions**:
- KMS encryption/decryption for backups
- CloudWatch Logs for database logs
- S3 access for backup storage

**Trust Policy**: `rds.amazonaws.com`

### 5. DynamoDB Service Role
**Purpose**: Enable DynamoDB to perform streaming and logging operations

**Permissions**:
- KMS encryption/decryption for data
- CloudWatch Logs for table logs
- Kinesis streams for change data capture

**Trust Policy**: `dynamodb.amazonaws.com`

### 6. Glue Service Role
**Purpose**: Enable Glue to crawl S3 data and manage catalog

**Permissions**:
- S3 bucket operations for data discovery
- KMS encryption/decryption for data
- CloudWatch Logs for crawler logs
- AWS managed Glue service permissions

**Trust Policy**: `glue.amazonaws.com`

### 7. Athena Service Role
**Purpose**: Enable Athena to query data and store results

**Permissions**:
- S3 access for data and query results
- Glue catalog operations for metadata
- KMS encryption/decryption for data

**Trust Policy**: `athena.amazonaws.com`

### 8. Lambda Execution Role
**Purpose**: Enable Lambda functions for backup validation and automation

**Permissions**:
- CloudWatch Logs for function logging
- DynamoDB and Aurora describe operations
- CloudWatch metrics for custom metrics
- SNS publish for notifications
- KMS encryption/decryption

**Trust Policy**: `lambda.amazonaws.com`

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | `"streaming-logs"` | no |
| environment | Environment name (dev, staging, prod) | `string` | `"dev"` | no |
| s3_bucket_arns | List of S3 bucket ARNs for service access | `list(string)` | `[]` | no |
| kms_key_arns | List of KMS key ARNs for encryption access | `list(string)` | `[]` | no |
| kinesis_firehose_arns | List of Kinesis Firehose delivery stream ARNs | `list(string)` | `[]` | no |
| dynamodb_table_arns | List of DynamoDB table ARNs | `list(string)` | `[]` | no |
| aurora_cluster_arns | List of Aurora cluster ARNs | `list(string)` | `[]` | no |
| glue_catalog_arns | List of Glue catalog ARNs | `list(string)` | `[]` | no |
| require_mfa | Require MFA for role assumption | `bool` | `false` | no |
| max_session_duration | Maximum session duration for role assumption | `number` | `3600` | no |

## Outputs

| Name | Description |
|------|-------------|
| service_role_arns | Map of service role ARNs |
| service_role_names | Map of service role names |
| cloudwatch_logs_role_arn | CloudWatch Logs service role ARN |
| kinesis_firehose_role_arn | Kinesis Firehose service role ARN |
| lambda_execution_role_arn | Lambda execution role ARN |
| iam_configuration_summary | Summary of IAM configuration |

## Security Best Practices

### Least Privilege Access
- Each role has only the minimum permissions required
- Resource ARNs are used to limit scope of permissions
- Actions are restricted to specific service operations

### Cross-Service Security
- Trust policies limit which services can assume roles
- KMS permissions ensure encrypted data access
- Resource-based policies provide additional security layers

### Environment Isolation
- Role names include environment for clear separation
- Resource ARNs are environment-specific
- No cross-environment access by default

### Monitoring and Auditing
- All roles support CloudWatch logging
- IAM actions are logged to CloudTrail
- Role usage can be monitored through AWS Config

## Environment-Specific Configurations

### Development Environment
- **MFA**: Disabled for ease of development
- **Session duration**: 1 hour (3600 seconds)
- **Cross-account access**: Disabled
- **Resource scope**: Limited to dev resources

### Staging Environment
- **MFA**: Optional (can be enabled for testing)
- **Session duration**: 1 hour (3600 seconds)
- **Cross-account access**: Optional for testing
- **Resource scope**: Limited to staging resources

### Production Environment
- **MFA**: Enabled for enhanced security
- **Session duration**: 1 hour or less
- **Cross-account access**: Carefully controlled
- **Resource scope**: Strictly limited to production resources

## Integration with Other Modules

The IAM module integrates with all other infrastructure modules:

- **Storage Module**: S3 bucket access permissions
- **CloudWatch Logs Module**: Log publishing permissions
- **Kinesis Firehose Module**: Data delivery permissions
- **Glue Catalog Module**: Data catalog access permissions
- **Athena Module**: Query execution permissions
- **Aurora Module**: Database operation permissions
- **DynamoDB Module**: Table operation permissions

## Troubleshooting

### Common Issues

1. **Access Denied Errors**: Check resource ARNs in variables
2. **Role Assumption Failures**: Verify trust policies and conditions
3. **KMS Access Issues**: Ensure KMS key ARNs are provided
4. **Cross-Service Failures**: Check service-specific permissions

### Debugging Steps

1. **Review CloudTrail logs** for IAM actions and denials
2. **Check IAM policy simulator** for permission testing
3. **Verify resource ARNs** match actual resource ARNs
4. **Test role assumption** using AWS CLI or SDK

## Compliance and Governance

### AWS Well-Architected Framework
- **Security Pillar**: Implements least privilege and defense in depth
- **Reliability Pillar**: Provides consistent access patterns
- **Performance Pillar**: Optimizes for service integration
- **Cost Optimization**: Avoids over-privileged roles

### Compliance Standards
- **SOC 2**: Supports access control requirements
- **ISO 27001**: Implements access management controls
- **PCI DSS**: Provides secure access to payment data (if applicable)
- **GDPR**: Supports data protection through access controls

## Maintenance

### Regular Tasks
- **Review role usage** through AWS Access Analyzer
- **Update permissions** as services evolve
- **Rotate external IDs** for cross-account access
- **Monitor for unused roles** and permissions

### Security Updates
- **Review AWS managed policies** for updates
- **Update resource ARNs** when resources change
- **Audit cross-service permissions** regularly
- **Test role assumptions** in different scenarios