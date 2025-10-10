# Terraform State Management Module

This module creates secure, reliable Terraform state storage with S3 backend, DynamoDB locking, and comprehensive backup and monitoring capabilities.

## Features

### Core State Management
- **S3 backend storage** with versioning and encryption
- **DynamoDB state locking** to prevent concurrent modifications
- **KMS encryption** for state data at rest and in transit
- **Cross-region backup** with automated replication
- **Access control** with IAM policies and roles

### Security Features
- **Encryption at rest** using customer-managed KMS keys
- **Bucket versioning** for state history and recovery
- **Public access blocking** for enhanced security
- **IAM-based access control** with least privilege
- **Optional MFA delete** for production environments

### Backup & Recovery
- **Automated S3 replication** to backup bucket
- **Version retention policies** for cost optimization
- **Point-in-time recovery** for DynamoDB lock table
- **Cross-region disaster recovery** capabilities
- **State backup monitoring** and alerting

### CI/CD Integration
- **Dedicated CI/CD role** for automated deployments
- **External ID support** for enhanced security
- **Cross-account access** capabilities
- **Environment-specific state keys** for isolation
- **Workspace support** for multi-environment management

## Usage

```hcl
module "terraform_state" {
  source = "./modules/terraform_state"
  
  project_name = "streaming-logs"
  environment  = "dev"
  
  # Access control
  terraform_users_arns = [
    "arn:aws:iam::123456789012:user/terraform-user",
    "arn:aws:iam::123456789012:role/admin-role"
  ]
  
  # CI/CD configuration
  create_cicd_role      = true
  cicd_role_trusted_arns = [
    "arn:aws:iam::123456789012:role/github-actions-role"
  ]
  
  # Backup and monitoring
  enable_state_backup    = true
  enable_state_monitoring = true
  
  # Retention policies
  state_version_retention_days = 30
  log_retention_days          = 30
}
```

## Backend Configuration

After deploying this module, configure your Terraform backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "streaming-logs-terraform-state-dev-abc123"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "streaming-logs-terraform-state-lock-dev"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:eu-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| random | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| random | >= 3.0 |

## Resources Created

### Core Resources
- `aws_s3_bucket.terraform_state` - Main state storage bucket
- `aws_dynamodb_table.terraform_state_lock` - State locking table
- `aws_kms_key.terraform_state` - Encryption key for state data
- `aws_kms_alias.terraform_state` - KMS key alias

### Security Resources
- `aws_s3_bucket_versioning.terraform_state` - Bucket versioning
- `aws_s3_bucket_server_side_encryption_configuration.terraform_state` - Encryption config
- `aws_s3_bucket_public_access_block.terraform_state` - Public access blocking
- `aws_iam_policy.terraform_state_access` - State access policy

### Backup Resources (Optional)
- `aws_s3_bucket.terraform_state_backup` - Backup storage bucket
- `aws_s3_bucket_replication_configuration.terraform_state_backup` - Replication config
- `aws_iam_role.replication_role` - S3 replication role

### CI/CD Resources (Optional)
- `aws_iam_role.terraform_cicd_role` - CI/CD execution role
- `aws_iam_role_policy_attachment.terraform_cicd_state_access` - Policy attachment

### Monitoring Resources (Optional)
- `aws_cloudwatch_log_group.terraform_state_logs` - State operation logs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | `"streaming-logs"` | no |
| environment | Environment name (dev, staging, prod) | `string` | `"dev"` | no |
| state_version_retention_days | Number of days to retain old state versions | `number` | `30` | no |
| terraform_users_arns | List of IAM user/role ARNs that need state access | `list(string)` | `[]` | no |
| create_cicd_role | Create IAM role for CI/CD pipeline | `bool` | `true` | no |
| enable_state_backup | Enable state backup with S3 replication | `bool` | `true` | no |
| enable_state_monitoring | Enable CloudWatch monitoring | `bool` | `true` | no |
| kms_deletion_window | KMS key deletion window in days | `number` | `7` | no |

## Outputs

| Name | Description |
|------|-------------|
| state_bucket_name | Name of the Terraform state S3 bucket |
| lock_table_name | Name of the DynamoDB lock table |
| kms_key_arn | ARN of the KMS key used for state encryption |
| backend_config | Terraform backend configuration |
| cicd_role_arn | ARN of the CI/CD role for Terraform operations |
| state_management_summary | Summary of state management configuration |

## Environment-Specific Configurations

### Development Environment
- **Version retention**: 30 days for cost optimization
- **Backup**: Enabled for testing disaster recovery
- **Monitoring**: Basic monitoring enabled
- **CI/CD role**: Created for automated testing
- **MFA delete**: Disabled for ease of development

### Staging Environment
- **Version retention**: 60 days for extended testing
- **Backup**: Enabled with cross-region replication
- **Monitoring**: Full monitoring suite enabled
- **CI/CD role**: Created with external ID requirement
- **MFA delete**: Optional for testing

### Production Environment
- **Version retention**: 90+ days for compliance
- **Backup**: Enabled with multiple backup strategies
- **Monitoring**: Comprehensive monitoring and alerting
- **CI/CD role**: Created with strict security controls
- **MFA delete**: Enabled for enhanced security

## Security Best Practices

### Access Control
- **Least privilege**: IAM policies grant minimal required permissions
- **Role-based access**: Use IAM roles instead of user credentials
- **External ID**: Required for cross-account access
- **MFA requirements**: Enforced for sensitive operations

### Encryption
- **Data at rest**: All state data encrypted with KMS
- **Data in transit**: HTTPS/TLS for all API communications
- **Key rotation**: Automatic KMS key rotation enabled
- **Backup encryption**: Backup data also encrypted

### Network Security
- **Private endpoints**: Use VPC endpoints where possible
- **CIDR restrictions**: Limit access to known IP ranges
- **Public access blocking**: Prevent accidental public exposure
- **Secure transport**: Enforce HTTPS for all operations

## Backup and Recovery

### Automated Backups
- **S3 replication**: Real-time replication to backup bucket
- **Version retention**: Configurable retention for old versions
- **Cross-region**: Backup to different region for DR
- **Encryption**: All backups encrypted with same KMS key

### Recovery Procedures
1. **State corruption**: Restore from S3 version history
2. **Accidental deletion**: Recover from backup bucket
3. **Region failure**: Switch to backup region
4. **Lock table issues**: Recreate from backup or manual unlock

### Testing
- **Regular recovery tests**: Validate backup procedures
- **Disaster recovery drills**: Test cross-region failover
- **State validation**: Verify state integrity after recovery
- **Documentation**: Maintain updated recovery procedures

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: eu-west-2

- name: Terraform Init
  run: terraform init
  env:
    TF_VAR_environment: ${{ github.ref_name }}
```

### GitLab CI Example
```yaml
terraform:
  before_script:
    - aws sts assume-role --role-arn $AWS_ROLE_ARN --role-session-name gitlab-ci
    - terraform init
  script:
    - terraform plan
    - terraform apply -auto-approve
```

## Monitoring and Alerting

### CloudWatch Metrics
- **State operations**: Track state read/write operations
- **Lock duration**: Monitor lock hold times
- **Access patterns**: Analyze state access patterns
- **Error rates**: Track failed operations

### Alerting
- **Lock timeouts**: Alert on long-held locks
- **Access failures**: Monitor authentication failures
- **Backup failures**: Alert on replication issues
- **Cost anomalies**: Monitor unexpected cost increases

## Cost Optimization

### Storage Costs
- **Lifecycle policies**: Automatic transition to cheaper storage classes
- **Version cleanup**: Remove old versions after retention period
- **Compression**: State files automatically compressed
- **Right-sizing**: Monitor and optimize storage usage

### Operational Costs
- **DynamoDB on-demand**: Pay only for actual lock operations
- **KMS usage**: Optimize key usage patterns
- **Monitoring costs**: Balance monitoring detail with cost
- **Backup optimization**: Efficient replication strategies

## Troubleshooting

### Common Issues

1. **State lock timeout**: Check for stuck locks in DynamoDB
2. **Access denied**: Verify IAM permissions and KMS access
3. **Bucket not found**: Check bucket name and region
4. **Version conflicts**: Resolve using state version history

### Debugging Steps

1. **Check AWS credentials**: Verify authentication
2. **Validate permissions**: Test IAM policy permissions
3. **Inspect state**: Use `terraform state list` and `terraform show`
4. **Review logs**: Check CloudWatch logs for errors

## Migration

### From Local State
```bash
# 1. Deploy state management module
terraform apply

# 2. Configure backend in existing project
# Add backend configuration to terraform block

# 3. Initialize with backend
terraform init -migrate-state

# 4. Verify state migration
terraform plan
```

### From Existing Remote State
```bash
# 1. Export existing state
terraform state pull > backup.tfstate

# 2. Configure new backend
terraform init -reconfigure

# 3. Import state if needed
terraform state push backup.tfstate

# 4. Verify migration
terraform plan
```

## Maintenance

### Regular Tasks
- **Review access logs**: Monitor state access patterns
- **Update retention policies**: Adjust based on compliance needs
- **Test backup procedures**: Validate recovery capabilities
- **Review IAM permissions**: Ensure least privilege access

### Security Updates
- **Rotate KMS keys**: Regular key rotation schedule
- **Update IAM policies**: Keep permissions current
- **Review access patterns**: Identify unusual activity
- **Update external IDs**: Change periodically for security