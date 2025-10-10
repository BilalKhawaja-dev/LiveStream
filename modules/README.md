# Terraform Modules

This directory contains reusable Terraform modules for the centralized logging and DR infrastructure.

## Module Structure

Each module follows the standard Terraform module structure:
- `main.tf` - Main resource definitions
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `README.md` - Module documentation

## Available Modules

### Core Infrastructure
- `networking/` - VPC, subnets, security groups, and network configuration
- `security/` - IAM roles, policies, and KMS keys

### Logging Pipeline
- `cloudwatch/` - CloudWatch log groups and subscription filters
- `kinesis/` - Kinesis Data Firehose delivery streams
- `s3/` - S3 buckets with lifecycle policies for log storage

### Analytics
- `athena/` - Athena workgroups and query configuration
- `glue/` - Glue Data Catalog and crawlers

### Data Storage & Backup
- `aurora/` - Aurora Serverless v2 cluster with backup configuration
- `dynamodb/` - DynamoDB tables with point-in-time recovery

### Monitoring
- `monitoring/` - CloudWatch dashboards, alarms, and cost monitoring

## Usage

Modules are called from the root `main.tf` file with appropriate variable passing:

```hcl
module "networking" {
  source = "./modules/networking"
  
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  environment        = var.environment
  name_prefix        = local.name_prefix
}
```