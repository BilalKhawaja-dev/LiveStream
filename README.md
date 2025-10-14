# Streaming Platform Infrastructure

A comprehensive Terraform-based infrastructure for a streaming platform with centralized logging, disaster recovery, and cost optimization features.

## 🏗️ Architecture Overview

This infrastructure includes:

- **VPC & Networking**: Multi-AZ VPC with public/private subnets
- **Storage**: S3 buckets with lifecycle policies for logs and backups
- **Database**: Aurora Serverless v2 (optional) and DynamoDB tables
- **Analytics**: Athena workgroups with Glue Data Catalog
- **Monitoring**: CloudWatch dashboards, alarms, and cost monitoring
- **Security**: KMS encryption, IAM roles, and security groups
- **Frontend**: React-based streaming platform applications

## 📋 Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Node.js >= 18 (for frontend applications)
- Bash shell (for scripts)

## 🚀 Quick Start

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review Configuration

```bash
# Check the configuration
terraform validate

# Review the deployment plan
terraform plan
```

### 3. Deploy Infrastructure

```bash
# Deploy to development environment
terraform apply

# Or use the Makefile
make init ENV=dev
make plan ENV=dev
make apply ENV=dev
```

### 4. Deploy Applications (Optional)

#### Option A: Local Development
```bash
cd streaming-platform-frontend
chmod +x install-dependencies.sh
./install-dependencies.sh
npm run dev
```

#### Option B: ECS Deployment
```bash
# Enable ECS in terraform.tfvars
# enable_ecs = true

# Build and push Docker images
make docker-push ENV=dev

# Deploy ECS infrastructure
make deploy-ecs ENV=dev
```

## 📁 Project Structure

```
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Variable definitions
├── outputs.tf              # Output definitions
├── terraform.tfvars        # Environment-specific values
├── modules/                # Terraform modules
│   ├── vpc/               # VPC and networking
│   ├── storage/           # S3 buckets and KMS
│   ├── aurora/            # Aurora Serverless database
│   ├── dynamodb/          # DynamoDB tables
│   ├── athena/            # Athena workgroups
│   ├── glue_catalog/      # Glue Data Catalog
│   ├── kinesis_firehose/  # Kinesis Firehose streams
│   ├── cloudwatch_logs/   # CloudWatch log groups
│   ├── iam/               # IAM roles and policies
│   └── monitoring/        # CloudWatch dashboards
├── environments/          # Environment-specific configurations
├── scripts/               # Utility scripts
├── tests/                 # Integration tests
├── athena_queries/        # Pre-built Athena queries
├── docs/                  # Documentation
└── streaming-platform-frontend/  # Frontend applications
```

## 🔧 Configuration

### Environment Variables

Key variables in `terraform.tfvars`:

```hcl
# Basic Configuration
aws_region = "eu-west-2"
environment = "dev"
project_name = "streaming-logs"

# Cost Optimization
enable_aurora = false  # Disable for development
log_retention_days = 7
monitoring_monthly_budget_limit = 50
```

### Cost Optimization Features

- **Development Mode**: Aurora disabled by default
- **Lifecycle Policies**: Automatic S3 storage class transitions
- **Log Retention**: Configurable CloudWatch log retention
- **Budget Alerts**: Cost monitoring and alerts
- **Resource Tagging**: Comprehensive cost allocation tags

## 🛡️ Security Features

- **Encryption**: KMS encryption for all data at rest
- **IAM**: Least-privilege access policies
- **VPC**: Private subnets for databases
- **Security Groups**: Restrictive network access
- **Audit Logging**: CloudTrail integration
- **Secure Frontend**: XSS protection, input sanitization

## 📊 Monitoring & Observability

- **CloudWatch Dashboards**: Infrastructure and application metrics
- **Cost Monitoring**: Budget alerts and cost optimization
- **Performance Metrics**: Query performance and resource utilization
- **Security Monitoring**: Security events and audit logs
- **Automated Cleanup**: Scheduled cleanup of old logs and results

## 🧪 Testing

Run the validation and test scripts:

```bash
# Validate Terraform configuration
./scripts/validate-terraform.sh

# Run integration tests
./tests/integration_test.sh

# Test backup and recovery
./tests/backup_recovery_test.sh
```

## 📚 Documentation

- [Deployment Guide](docs/deployment-guide.md)
- [Disaster Recovery Procedures](docs/disaster-recovery-procedures.md)
- [Operational Runbooks](docs/operational-runbooks.md)
- [Athena Query Guide](athena_queries/README.md)

## 🔄 Environments

### Development
- Cost-optimized configuration
- Aurora disabled by default
- Shorter retention periods
- Basic monitoring

### Staging
- Production-like configuration
- Full monitoring enabled
- Extended retention periods

### Production
- High availability setup
- Full disaster recovery
- Comprehensive monitoring
- Extended backup retention

## 🛠️ Maintenance

### Regular Tasks

1. **Update Dependencies**: Keep Terraform providers updated
2. **Review Costs**: Monitor AWS costs and optimize
3. **Security Audits**: Regular security reviews
4. **Backup Testing**: Validate backup and recovery procedures

### Cleanup Commands

```bash
# Clean up old Athena results
aws s3 rm s3://your-athena-results-bucket/ --recursive

# Clean up old CloudWatch logs
aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output text | xargs -I {} aws logs delete-log-group --log-group-name {}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and validation
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:

1. Check the [documentation](docs/)
2. Review [troubleshooting guides](docs/operational-runbooks.md)
3. Open an issue in the repository

## 🎯 Next Steps

After deployment:

1. Configure monitoring alerts
2. Set up backup schedules
3. Configure cost budgets
4. Deploy frontend applications
5. Set up CI/CD pipelines (when ready)

---

**Note**: This infrastructure is optimized for development by default. Review and adjust configurations for staging and production environments.