# Centralized Logging and Disaster Recovery Infrastructure

This Terraform project implements a comprehensive centralized logging and disaster recovery solution for streaming applications on AWS.

## Architecture Overview

The infrastructure includes:
- **CloudWatch Logs** for real-time log collection
- **Kinesis Data Firehose** for log streaming and transformation
- **S3** for long-term log storage with lifecycle policies
- **Aurora Serverless v2** for structured log data and metadata
- **DynamoDB** for high-performance log indexing
- **Athena** for log analytics and querying
- **Cross-region backup** for disaster recovery

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **S3 bucket** for Terraform state (create manually first)
4. **DynamoDB table** for state locking (create manually first)

### Initial Setup

Before running Terraform, create the state backend resources:

```bash
# Create S3 bucket for state
aws s3 mb s3://terraform-state-centralized-logging-dr --region eu-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-centralized-logging-dr \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock-centralized-logging-dr \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-2
```

## Project Structure

```
terraform_live_stream/
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Variable definitions
├── outputs.tf             # Output definitions
├── terraform.tfvars.example # Example variables file
├── environments/          # Environment-specific configurations
│   ├── dev/
│   │   └── terraform.tfvars
│   ├── staging/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
└── modules/               # Reusable Terraform modules
    ├── networking/        # VPC and network resources
    ├── security/          # IAM and KMS resources
    ├── cloudwatch/        # CloudWatch log groups
    ├── kinesis/           # Kinesis Data Firehose
    ├── s3/               # S3 buckets and policies
    ├── aurora/           # Aurora Serverless cluster
    ├── dynamodb/         # DynamoDB tables
    ├── athena/           # Athena workgroups
    └── monitoring/       # CloudWatch dashboards and alarms
```

## Usage

### Development Environment

```bash
# Initialize Terraform
terraform init

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values

# Or use environment-specific variables
cp environments/dev/terraform.tfvars .

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

### Environment-Specific Deployment

```bash
# Deploy to development
terraform apply -var-file="environments/dev/terraform.tfvars"

# Deploy to staging
terraform apply -var-file="environments/staging/terraform.tfvars"

# Deploy to production
terraform apply -var-file="environments/prod/terraform.tfvars"
```

## Environment Configurations

### Development (dev)
- **Cost-optimized** settings
- **7-day** log retention
- **Minimal** Aurora capacity (0.5-2 ACU)
- **Pay-per-request** DynamoDB billing
- **Disabled** cross-region backup and enhanced monitoring

### Staging (staging)
- **Production-like** settings with cost optimizations
- **14-day** log retention
- **Moderate** Aurora capacity (1-8 ACU)
- **Enhanced monitoring** enabled
- **Cross-region backup** disabled for cost

### Production (prod)
- **Full production** settings
- **30-day** log retention with 7-year archival
- **High** Aurora capacity (2-16 ACU)
- **All monitoring** and backup features enabled
- **MFA delete** protection enabled

## Key Features

### Cost Optimization
- Environment-specific resource sizing
- Intelligent S3 lifecycle policies
- Aurora Serverless v2 auto-scaling
- Pay-per-request DynamoDB billing for dev/staging

### Security
- KMS encryption for all data at rest
- IAM roles with least privilege access
- VPC with private subnets for databases
- Optional MFA delete protection

### Monitoring
- CloudWatch dashboards for all components
- Automated alarms for error rates and performance
- Cost monitoring and budgets
- Performance Insights for Aurora (prod only)

### Disaster Recovery
- Cross-region backup (prod only)
- Point-in-time recovery for databases
- Versioned S3 storage
- Multi-AZ deployment

## Outputs

After deployment, Terraform provides outputs for:
- S3 bucket names and ARNs
- CloudWatch log group names
- Database endpoints (sensitive)
- VPC and subnet IDs
- Athena database and workgroup names

## Cleanup

```bash
# Destroy infrastructure
terraform destroy

# Or for specific environment
terraform destroy -var-file="environments/dev/terraform.tfvars"
```

## Module Development

Each module follows standard Terraform conventions:
- `main.tf` - Resource definitions
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `README.md` - Module documentation

See `modules/README.md` for detailed module information.

## Cost Estimation

Use `terraform plan` with cost estimation tools or AWS Cost Calculator to estimate monthly costs based on your expected log volume and retention requirements.

## Support

For issues or questions:
1. Check the module-specific README files
2. Review AWS service documentation
3. Validate Terraform configuration with `terraform validate`
4. Use `terraform plan` to preview changes before applying