# Centralized Logging Infrastructure

A comprehensive, production-ready Terraform project for centralized logging infrastructure on AWS, designed for streaming services with cost optimization, security, and operational excellence.

## 🏗️ Architecture Overview

This infrastructure provides a complete logging pipeline with the following components:

- **📊 CloudWatch Logs** - Centralized log collection from all streaming services
- **🚀 Kinesis Data Firehose** - Real-time log streaming and delivery
- **🗄️ S3 Storage** - Cost-effective log storage with intelligent lifecycle policies
- **🔍 Amazon Athena** - Serverless log querying and analysis
- **📚 AWS Glue** - Automated data catalog and schema management
- **💾 Aurora Serverless v2** - Scalable metadata storage
- **⚡ DynamoDB** - High-performance NoSQL data storage
- **🔐 IAM & Security** - Comprehensive security with least privilege access
- **📈 Monitoring** - Full observability with dashboards and alerting

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.6.0 installed
- Git for version control

### 1-Minute Deployment
```bash
# Clone the repository
git clone <repository-url>
cd terraform_live_stream

# Quick setup using Makefile
make init ENV=dev
make plan ENV=dev
make apply ENV=dev

# Verify deployment
make test ENV=dev
```

### Manual Deployment
```bash
# Copy environment configuration
cp environments/dev/terraform.tfvars terraform.tfvars

# Initialize Terraform
terraform init
terraform workspace new dev

# Deploy infrastructure
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Verify deployment
terraform output
./tests/integration_test.sh
```

## 📁 Project Structure

```
terraform_live_stream/
├── 🏠 main.tf                     # Main Terraform configuration
├── 📝 variables.tf                # Variable definitions
├── 📤 outputs.tf                  # Output definitions
├── 🌍 environments/               # Environment-specific configurations
│   ├── dev/terraform.tfvars       # Development settings
│   ├── staging/terraform.tfvars   # Staging settings
│   └── prod/terraform.tfvars      # Production settings
├── 🧩 modules/                    # Reusable Terraform modules
│   ├── storage/                   # S3 storage with lifecycle policies
│   ├── cloudwatch_logs/           # Log groups and filters
│   ├── kinesis_firehose/          # Data streaming
│   ├── athena/                    # Query engine
│   ├── glue_catalog/              # Data catalog
│   ├── aurora/                    # Serverless database
│   ├── dynamodb/                  # NoSQL tables
│   ├── iam/                       # Security roles
│   └── monitoring/                # Dashboards and alarms
├── 🔧 scripts/                    # Automation and utility scripts
│   ├── validate-terraform.sh      # Pre-deployment validation
│   ├── rollback.sh                # Disaster recovery
│   ├── secrets-manager.sh         # Secrets management
│   └── workspace-manager.sh       # Environment management
├── 🧪 tests/                      # Comprehensive test suite
│   ├── integration_test.sh        # Infrastructure validation
│   ├── e2e_log_pipeline_test.sh   # End-to-end pipeline testing
│   └── backup_recovery_test.sh    # Backup and recovery validation
├── 📚 docs/                       # Comprehensive documentation
│   ├── deployment-guide.md        # Detailed deployment instructions
│   ├── operational-runbooks.md    # Day-to-day operations
│   └── disaster-recovery-procedures.md # DR procedures
├── 🔄 .github/workflows/          # GitHub Actions CI/CD
├── 🦊 .gitlab-ci.yml              # GitLab CI/CD pipeline
├── 🛠️ Makefile                    # Simplified command interface
└── 📋 athena_queries/             # Pre-built analysis queries
```

## 🧩 Infrastructure Modules

### Core Storage & Processing
- **🗄️ Storage Module** - S3 buckets with intelligent lifecycle policies, versioning, and encryption
- **📊 CloudWatch Logs** - Centralized log groups for all streaming services with retention policies
- **🚀 Kinesis Firehose** - Real-time log delivery with compression and error handling
- **🔍 Athena & Glue** - Serverless analytics with automated schema discovery

### Database Layer
- **💾 Aurora Serverless v2** - Auto-scaling MySQL cluster with automated backups
- **⚡ DynamoDB** - High-performance NoSQL with point-in-time recovery

### Security & Operations
- **🔐 IAM Module** - Least privilege security roles and policies
- **📈 Monitoring** - CloudWatch dashboards, alarms, and cost tracking
- **🏗️ Terraform State** - Remote state management with locking

## 🌍 Environment Configuration

### Development Environment
- **Cost-optimized** settings for development workloads
- **7-day** log retention for cost savings
- **Minimal** Aurora capacity for development needs
- **Automated cleanup** for temporary resources

### Staging Environment
- **Production-like** configuration for testing
- **30-day** log retention for thorough testing
- **Enhanced monitoring** for performance validation
- **Manual approval** for sensitive operations

### Production Environment
- **Full redundancy** across multiple AZs
- **Extended retention** periods for compliance
- **Comprehensive monitoring** and alerting
- **Strict security** controls and audit logging

## 💰 Cost Optimization Features

### Intelligent Storage Management
- **Automated lifecycle policies** - Standard → IA (30 days) → Glacier (90 days)
- **Compression** - GZIP compression for all log data
- **Partitioning** - Efficient data organization for query optimization

### Compute Optimization
- **Aurora Serverless v2** - Automatic scaling based on demand
- **DynamoDB On-Demand** - Pay-per-request pricing model
- **Optimized Firehose** - Intelligent buffering for cost efficiency

### Monitoring & Control
- **Cost alerts** - Automated budget monitoring and notifications
- **Usage tracking** - Detailed cost breakdown by service
- **Optimization recommendations** - Regular cost review procedures

## 🔐 Security Features

### Data Protection
- **Encryption at rest** - All data encrypted using AWS KMS
- **Encryption in transit** - TLS encryption for all data transfers
- **Access logging** - Comprehensive audit trails

### Access Control
- **IAM roles** - Service-specific roles with minimal permissions
- **VPC endpoints** - Private connectivity between services
- **Security groups** - Network-level access controls

### Compliance
- **Audit logging** - CloudTrail integration for all API calls
- **Data retention** - Configurable retention policies for compliance
- **Backup encryption** - All backups encrypted with customer-managed keys

## 📈 Monitoring & Observability

### Real-time Dashboards
- **Infrastructure health** - Service status and performance metrics
- **Log pipeline** - Ingestion rates and delivery success
- **Cost tracking** - Real-time spend monitoring
- **Query performance** - Athena query optimization metrics

### Automated Alerting
- **Service health** - Immediate notification of service issues
- **Performance degradation** - Proactive performance monitoring
- **Cost anomalies** - Budget threshold and spike detection
- **Security events** - Suspicious activity alerts

### Operational Metrics
- **SLA tracking** - Service level agreement monitoring
- **Capacity planning** - Growth trend analysis
- **Performance optimization** - Query and storage optimization

## 🧪 Testing & Validation

### Comprehensive Test Suite
```bash
# Infrastructure validation
make test ENV=dev

# End-to-end pipeline testing
./tests/e2e_log_pipeline_test.sh

# Backup and recovery validation
./tests/backup_recovery_test.sh

# Security and compliance checks
make security
```

### Automated CI/CD
- **GitHub Actions** - Automated validation and deployment
- **GitLab CI** - Alternative CI/CD pipeline
- **Pre-commit hooks** - Code quality and security checks
- **Integration testing** - Comprehensive infrastructure validation

## 📚 Documentation

### Operational Guides
- **[🚀 Deployment Guide](docs/deployment-guide.md)** - Complete deployment procedures and troubleshooting
- **[📋 Operational Runbooks](docs/operational-runbooks.md)** - Day-to-day operations, monitoring, and maintenance
- **[🆘 Disaster Recovery](docs/disaster-recovery-procedures.md)** - Emergency procedures and recovery protocols

### Quick References
- **[🔧 Makefile Commands](#makefile-commands)** - Simplified operation commands
- **[🧪 Testing Procedures](#testing--validation)** - Validation and testing guidelines
- **[💰 Cost Optimization](#cost-optimization-features)** - Cost management strategies

## 🛠️ Makefile Commands

The project includes a comprehensive Makefile for simplified operations:

```bash
# Environment Management
make init ENV=dev          # Initialize Terraform for environment
make plan ENV=staging      # Generate deployment plan
make apply ENV=prod        # Deploy infrastructure
make destroy ENV=dev       # Destroy infrastructure (with confirmation)

# Testing & Validation
make test                  # Run all tests
make test-modules          # Test individual modules
make security              # Run security scans
make lint                  # Code linting and formatting

# Operations
make outputs ENV=prod      # Show infrastructure outputs
make backup ENV=prod       # Create infrastructure backup
make rollback ENV=prod     # Rollback to previous state
make clean                 # Clean temporary files

# Development
make format                # Format Terraform code
make validate              # Validate configuration
make docs                  # Generate documentation
make setup-hooks           # Setup git pre-commit hooks

# Utilities
make check-tools           # Check required tools
make install-tools         # Install optional tools
make cost-estimate         # Estimate infrastructure costs
```

## 🔄 CI/CD Integration

### GitHub Actions
Automated workflows for:
- **Code validation** - Terraform format, validate, and security checks
- **Multi-environment planning** - Automated plan generation for dev/staging
- **Security scanning** - tfsec, Checkov, and Semgrep integration
- **PR comments** - Automated plan output in pull requests

### GitLab CI
Comprehensive pipeline with:
- **Validation stages** - Format, validate, lint, and security
- **Environment deployment** - Automated dev, manual staging/prod
- **Cost estimation** - Infracost integration for cost awareness
- **Artifact management** - Plan files and reports

## 🆘 Support & Troubleshooting

### Common Issues
1. **Permission errors** - Verify AWS credentials and IAM permissions
2. **State lock issues** - Use `terraform force-unlock` with caution
3. **Resource conflicts** - Check for existing resources with same names
4. **Cost spikes** - Review lifecycle policies and retention settings

### Getting Help
- **📖 Documentation** - Check comprehensive guides in `/docs`
- **🔍 Logs** - Review CloudWatch logs and Terraform output
- **🧪 Testing** - Run diagnostic tests to identify issues
- **👥 Community** - Terraform and AWS community forums

### Emergency Contacts
- **Operations Team:** ops-team@company.com
- **On-call Engineer:** +1-555-0123 (24/7)
- **Security Team:** security@company.com

## 🤝 Contributing

### Development Workflow
1. **Fork** the repository
2. **Create** a feature branch
3. **Make** changes with proper testing
4. **Run** validation: `make ci-validate`
5. **Submit** pull request with detailed description

### Code Standards
- **Terraform formatting** - Use `terraform fmt`
- **Security scanning** - All code must pass security checks
- **Documentation** - Update docs for any changes
- **Testing** - Include tests for new functionality

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🏷️ Version

**Current Version:** 1.0.0  
**Terraform Version:** >= 1.6.0  
**AWS Provider Version:** >= 5.0  

---

## 📊 Infrastructure Metrics

| Component | RTO | RPO | Availability Target |
|-----------|-----|-----|-------------------|
| Aurora Database | 4 hours | 15 minutes | 99.9% |
| DynamoDB | 2 hours | 1 minute | 99.99% |
| S3 Storage | 1 hour | 0 | 99.999999999% |
| Log Pipeline | 2 hours | 5 minutes | 99.9% |
| Full System | 6 hours | 15 minutes | 99.9% |

---

**Built with ❤️ for reliable, scalable, and cost-effective logging infrastructure**