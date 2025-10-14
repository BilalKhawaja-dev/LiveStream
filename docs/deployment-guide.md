# Terraform Deployment and Testing Guide

## Overview

This guide covers the complete deployment, validation, and testing procedures for the centralized logging infrastructure using Terraform.

## Prerequisites

### Required Tools

- **Terraform** >= 1.6.0
- **AWS CLI** >= 2.0
- **Git** for version control
- **tfsec** (optional, for security scanning)
- **tflint** (optional, for linting)

### AWS Setup

1. Configure AWS credentials:
```bash
aws configure
# OR use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-2"
```

2. Verify AWS access:
```bash
aws sts get-caller-identity
```

## Project Structure

```
terraform_live_stream/
├── main.tf                     # Main Terraform configuration
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── terraform.tfvars.example    # Example variables file
├── environments/               # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/                    # Reusable Terraform modules
├── scripts/                    # Automation scripts
├── tests/                      # Integration tests
└── docs/                       # Documentation
```

## Deployment Procedures

### 1. Initial Setup

1. **Clone and navigate to the project:**
```bash
git clone <repository-url>
cd terraform_live_stream
```

2. **Copy environment variables:**
```bash
# For development environment
cp environments/dev/terraform.tfvars terraform.tfvars

# For other environments
cp environments/staging/terraform.tfvars terraform.tfvars
cp environments/prod/terraform.tfvars terraform.tfvars
```

3. **Review and customize variables:**
```bash
# Edit the terraform.tfvars file to match your requirements
vim terraform.tfvars
```

### 2. Terraform Initialization

```bash
# Initialize Terraform
terraform init

# Verify initialization
terraform version
```

### 3. Workspace Management

```bash
# Create or select workspace for environment
terraform workspace new dev
# OR
terraform workspace select dev

# List available workspaces
terraform workspace list
```

### 4. Validation and Planning

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Generate execution plan
terraform plan -var-file=terraform.tfvars -out=deployment.tfplan

# Review the plan
terraform show deployment.tfplan
```

### 5. Deployment

```bash
# Apply the plan
terraform apply deployment.tfplan

# OR apply directly (not recommended for production)
terraform apply -var-file=terraform.tfvars
```

### 6. Verification

```bash
# Check outputs
terraform output

# Verify AWS resources
aws s3 ls | grep streaming-logs
aws logs describe-log-groups --log-group-name-prefix /aws/streaming
```

## Testing Procedures

### 1. Pre-commit Validation

Run pre-commit hooks before committing changes:

```bash
# Run pre-commit validation
./scripts/pre-commit-hooks.sh

# Setup git hooks (optional)
ln -sf ../../scripts/pre-commit-hooks.sh .git/hooks/pre-commit
```

### 2. Integration Testing

Run comprehensive integration tests:

```bash
# Run all integration tests
./tests/integration_test.sh

# Run tests for specific environment
TEST_ENVIRONMENT=staging ./tests/integration_test.sh

# Run with custom AWS region
AWS_REGION=us-east-1 ./tests/integration_test.sh
```

### 3. Module Testing

Test individual modules:

```bash
# Test storage module
cd modules/storage/tests
./test_storage_module.sh

# Test other modules
cd modules/cloudwatch_logs
terraform init -backend=false
terraform validate
```

### 4. Security Scanning

```bash
# Run security scan with tfsec
tfsec .

# Run with specific checks
tfsec . --include-passed --soft-fail

# Generate report
tfsec . --format json --out security-report.json
```

### 5. Linting

```bash
# Run Terraform linting
tflint --init
tflint

# Run with specific rules
tflint --enable-rule=terraform_unused_declarations
```

## CI/CD Pipeline Usage

### GitHub Actions

The project includes GitHub Actions workflows for automated validation and deployment:

1. **Validation Pipeline** (`.github/workflows/terraform-validation.yml`):
   - Triggered on push/PR to main/develop branches
   - Runs formatting, validation, security scans
   - Generates plans for review

2. **Usage:**
```bash
# Push changes to trigger pipeline
git push origin feature-branch

# Create PR to main for full validation
git checkout -b feature/new-logging-feature
# Make changes
git commit -m "Add new logging feature"
git push origin feature/new-logging-feature
# Create PR via GitHub UI
```

### GitLab CI

For GitLab environments, use the `.gitlab-ci.yml` pipeline:

1. **Pipeline Stages:**
   - validate: Format, validate, lint
   - security: Security scanning
   - plan: Generate deployment plans
   - deploy: Deploy to environments
   - cleanup: Clean up artifacts

2. **Usage:**
```bash
# Push to trigger pipeline
git push origin main

# Manual deployment to production
# Use GitLab UI to trigger manual job
```

## Rollback Procedures

### 1. Using Rollback Script

```bash
# List available backups
./scripts/rollback.sh --list

# Rollback to previous state
./scripts/rollback.sh --environment dev --backup-id 20241010-120000

# Rollback with confirmation
./scripts/rollback.sh --environment prod --backup-id 20241010-120000 --confirm
```

### 2. Manual Rollback

```bash
# Revert to previous Terraform state
terraform workspace select dev
terraform state pull > current-state.json

# Apply previous configuration
git checkout previous-commit
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 3. Emergency Rollback

```bash
# Destroy specific resources
terraform destroy -target=module.problematic_module

# Recreate from known good state
terraform import aws_s3_bucket.logs existing-bucket-name
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Troubleshooting

### Common Issues

1. **State Lock Issues:**
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID

# Check lock status
aws dynamodb get-item --table-name terraform-state-lock --key '{"LockID":{"S":"terraform-state-lock"}}'
```

2. **Provider Version Conflicts:**
```bash
# Upgrade providers
terraform init -upgrade

# Lock provider versions
terraform providers lock -platform=linux_amd64
```

3. **Resource Conflicts:**
```bash
# Import existing resources
terraform import aws_s3_bucket.example existing-bucket-name

# Remove from state without destroying
terraform state rm aws_s3_bucket.example
```

4. **Permission Issues:**
```bash
# Check AWS permissions
aws iam get-user
aws iam list-attached-user-policies --user-name your-username

# Test specific permissions
aws s3 ls
aws logs describe-log-groups
```

### Debugging Commands

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan -var-file=terraform.tfvars

# Validate specific resources
terraform plan -target=module.storage

# Check state
terraform state list
terraform state show aws_s3_bucket.logs
```

## Environment-Specific Considerations

### Development Environment

- Uses minimal resources for cost optimization
- Shorter retention periods
- Relaxed security settings for testing
- Auto-cleanup enabled

### Staging Environment

- Production-like configuration
- Extended retention periods
- Full security scanning
- Manual cleanup

### Production Environment

- Full redundancy and backup
- Maximum retention periods
- Strict security controls
- Manual deployment approval required

## Cost Optimization

### Monitoring Costs

```bash
# Check current costs
aws ce get-cost-and-usage --time-period Start=2024-10-01,End=2024-10-31 --granularity MONTHLY --metrics BlendedCost

# Set up billing alerts
aws budgets create-budget --account-id 123456789012 --budget file://budget.json
```

### Cost-Saving Measures

1. **S3 Lifecycle Policies:**
   - Automatic transition to IA after 30 days
   - Archive to Glacier after 90 days
   - Delete after retention period

2. **CloudWatch Logs:**
   - Appropriate retention periods
   - Log filtering to reduce volume

3. **Kinesis Firehose:**
   - Optimized buffer settings
   - Compression enabled

## Security Best Practices

### 1. Secrets Management

```bash
# Use AWS Secrets Manager
./scripts/secrets-manager.sh --create --name db-password --value "secure-password"

# Rotate secrets
./scripts/secrets-manager.sh --rotate --name db-password
```

### 2. IAM Policies

- Use least privilege principle
- Regular policy reviews
- Service-specific roles

### 3. Encryption

- Enable encryption at rest for all storage
- Use customer-managed KMS keys
- Encrypt data in transit

## Monitoring and Alerting

### CloudWatch Dashboards

Access the monitoring dashboard:
```bash
# Get dashboard URL from Terraform output
terraform output monitoring_dashboard_url
```

### Key Metrics to Monitor

1. **Log Pipeline Health:**
   - Log ingestion rate
   - Firehose delivery success rate
   - S3 storage usage

2. **Database Performance:**
   - Aurora connection count
   - DynamoDB throttling
   - Backup success rate

3. **Cost Metrics:**
   - Daily spend by service
   - Storage growth rate
   - Query execution costs

## Backup and Recovery

### Automated Backups

- Aurora: 7-day automated backups
- DynamoDB: Point-in-time recovery enabled
- S3: Versioning and cross-region replication

### Manual Backup

```bash
# Create manual Aurora snapshot
aws rds create-db-cluster-snapshot --db-cluster-identifier ${PROJECT_NAME}-aurora-${ENVIRONMENT} --db-cluster-snapshot-identifier manual-backup-$(date +%Y%m%d)

# Export DynamoDB table
aws dynamodb create-backup --table-name ${PROJECT_NAME}-metadata-${ENVIRONMENT} --backup-name manual-backup-$(date +%Y%m%d)
```

### Recovery Testing

```bash
# Test Aurora recovery
./tests/integration_test.sh --test-recovery

# Validate backup integrity
aws rds describe-db-cluster-snapshots --db-cluster-identifier ${PROJECT_NAME}-aurora-${ENVIRONMENT}
```

## Support and Maintenance

### Regular Maintenance Tasks

1. **Weekly:**
   - Review CloudWatch alarms
   - Check cost reports
   - Validate backup success

2. **Monthly:**
   - Update Terraform providers
   - Review security scan results
   - Optimize resource usage

3. **Quarterly:**
   - Disaster recovery testing
   - Security policy review
   - Performance optimization

### Getting Help

1. **Documentation:** Check this guide and module READMEs
2. **Logs:** Review CloudWatch logs and Terraform output
3. **AWS Support:** Use AWS Support Center for service issues
4. **Community:** Terraform and AWS community forums

## Appendix

### Useful Commands Reference

```bash
# Terraform
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform destroy -var-file=terraform.tfvars
terraform output
terraform state list
terraform workspace list

# AWS CLI
aws sts get-caller-identity
aws s3 ls
aws logs describe-log-groups
aws rds describe-db-clusters

# Testing
./scripts/validate-terraform.sh
./tests/integration_test.sh
./scripts/pre-commit-hooks.sh

# Monitoring
aws cloudwatch get-metric-statistics
aws ce get-cost-and-usage
```

### Environment Variables

```bash
# Terraform
export TF_VAR_environment=dev
export TF_VAR_region=eu-west-2

# AWS
export AWS_REGION=eu-west-2
export AWS_PROFILE=default

# Testing
export TEST_ENVIRONMENT=dev
```