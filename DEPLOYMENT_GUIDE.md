# 🚀 Streaming Platform Infrastructure Deployment Guide

## 📋 Overview

This guide provides step-by-step instructions for deploying the complete streaming platform infrastructure on AWS. The infrastructure includes:

- **Core Services**: VPC, Aurora Serverless v2, DynamoDB, S3, CloudFront
- **Container Platform**: ECS with Fargate, ALB, Auto-scaling
- **Authentication**: Cognito User Pools, JWT middleware
- **Media Services**: S3 storage, CloudFront CDN, MediaLive (optional)
- **AI Services**: Bedrock integration for support and moderation
- **Security**: WAF, SSL/TLS, IAM roles, encryption
- **Monitoring**: CloudWatch dashboards, alarms, cost monitoring

## 🔧 Prerequisites

### Required Tools
```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Install Docker (for container builds)
sudo apt-get update
sudo apt-get install docker.io docker-compose
sudo usermod -aG docker $USER
```

### AWS Account Setup
1. **AWS Account**: Active AWS account with billing enabled
2. **IAM User**: Create IAM user with AdministratorAccess policy
3. **AWS CLI**: Configure with your credentials
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (e.g., us-east-1), Output format (json)
```

### Domain Setup (Optional)
- **Domain Name**: Register domain for SSL certificates (optional for development)
- **Route53**: Hosted zone for your domain (if using custom domain)

## 🚀 Deployment Steps

### Step 1: Clone and Prepare
```bash
# Clone the repository
git clone <your-repo-url>
cd streaming-platform-infrastructure

# Review configuration
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Configure Variables
Edit `terraform.tfvars`:

```hcl
# Basic Configuration
project_name = "streaming-platform"
environment  = "dev"  # or "staging", "prod"
aws_region   = "us-east-1"

# Network Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Domain Configuration (Optional - leave empty for HTTP-only development)
domain_name                = ""  # e.g., "streaming.example.com"
ssl_certificate_arn        = ""  # Leave empty to auto-create with ACM
enable_wildcard_certificate = false

# Feature Toggles
enable_ecs           = true   # Frontend applications
enable_media_services = true   # S3 + CloudFront
enable_medialive     = false  # Live streaming (costs ~$1.50/hour when running)
enable_waf           = true   # Web Application Firewall
enable_monitoring_alerts = true

# Cost Optimization
aurora_min_capacity = 0.5     # Serverless v2 minimum
aurora_max_capacity = 1.0     # Serverless v2 maximum
ecs_enable_spot_instances = true
cloudfront_price_class = "PriceClass_100"  # US, Canada, Europe only

# Container Configuration (Required if enable_ecs = true)
ecr_repository_url = ""  # Will be created during deployment
container_image_tag = "latest"

# Email Notifications (Optional)
support_email_addresses = ["support@example.com"]
```

### Step 3: Initialize Terraform
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (review changes)
terraform plan
```

### Step 4: Deploy Infrastructure
```bash
# Deploy infrastructure
terraform apply

# Confirm with 'yes' when prompted
```

**⏱️ Deployment Time**: 15-25 minutes for complete infrastructure

### Step 5: Build and Deploy Containers (If ECS Enabled)
```bash
# Navigate to frontend directory
cd streaming-platform-frontend

# Build all container images
./build-containers.sh

# Push to ECR (repository URL from Terraform output)
ECR_URL=$(terraform output -raw ecr_repository_url)
./push-containers.sh $ECR_URL

# Update ECS services with new images
aws ecs update-service --cluster streaming-platform-dev-cluster \
  --service streaming-platform-dev-viewer-portal --force-new-deployment
```

### Step 6: Verify Deployment
```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Application URL: http://$ALB_DNS"

# Check service health
curl -I http://$ALB_DNS/health

# View CloudWatch dashboards
aws cloudwatch list-dashboards --query 'DashboardEntries[?contains(DashboardName, `streaming-platform`)]'
```

## 🔐 Security Configuration

### SSL/TLS Setup (Production)
```hcl
# In terraform.tfvars for production
domain_name = "streaming.example.com"
enable_wildcard_certificate = true
```

### WAF Configuration
```hcl
# Enable WAF protection
enable_waf = true
waf_rate_limit_per_5min = 2000
waf_blocked_countries = ["CN", "RU"]  # Optional geo-blocking
```

### Secrets Management
```bash
# Store sensitive values in AWS Secrets Manager
aws secretsmanager create-secret \
  --name "streaming-platform/dev/stripe" \
  --description "Stripe API keys" \
  --secret-string '{"secret_key":"sk_test_...","webhook_secret":"whsec_..."}'
```

## 💰 Cost Management

### Development Environment (~$50-100/month)
- **Aurora Serverless v2**: ~$15-30/month (0.5-1.0 ACU)
- **ECS Fargate**: ~$20-40/month (Spot instances)
- **S3 + CloudFront**: ~$5-15/month
- **Other services**: ~$10-15/month

### Cost Controls
```hcl
# Enable cost optimization features
aurora_min_capacity = 0.5
ecs_enable_spot_instances = true
media_enable_intelligent_tiering = true
enable_scheduled_scaling = true
```

### MediaLive Costs (Optional)
- **Single Pipeline HD**: ~$1.50/hour when running
- **Standard HD**: ~$3.00/hour when running
- **Auto-shutdown**: Configured for 4-hour maximum runtime

## 📊 Monitoring and Alerts

### CloudWatch Dashboards
- **Infrastructure**: VPC, ECS, Aurora, DynamoDB metrics
- **Application**: API Gateway, Lambda, error rates
- **Cost**: Billing alerts, service costs
- **Security**: WAF blocks, failed authentications

### Key Metrics to Monitor
- **ECS CPU/Memory**: Auto-scaling triggers
- **Aurora Connections**: Database performance
- **API Gateway Errors**: Application health
- **CloudFront Cache Hit Ratio**: CDN efficiency
- **WAF Blocked Requests**: Security threats

## 🔧 Maintenance

### Regular Tasks
```bash
# Update container images
./build-containers.sh && ./push-containers.sh

# Check for Terraform updates
terraform plan

# Review cost reports
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY --metrics BlendedCost
```

### Backup Verification
- **Aurora**: Automated backups (7-day retention)
- **DynamoDB**: Point-in-time recovery enabled
- **S3**: Versioning and lifecycle policies

## 🚨 Troubleshooting

### Common Issues

#### ECS Tasks Not Starting
```bash
# Check ECS service events
aws ecs describe-services --cluster streaming-platform-dev-cluster \
  --services streaming-platform-dev-viewer-portal

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/ecs/streaming-platform"
```

#### Aurora Connection Issues
```bash
# Check Aurora cluster status
aws rds describe-db-clusters --db-cluster-identifier streaming-platform-dev-aurora

# Test connectivity from ECS
aws ecs execute-command --cluster streaming-platform-dev-cluster \
  --task <task-id> --container viewer-portal --interactive --command "/bin/bash"
```

#### High Costs
```bash
# Check cost breakdown
aws ce get-dimension-values --dimension SERVICE \
  --time-period Start=2024-01-01,End=2024-01-31

# Review MediaLive usage
aws medialive describe-channel --channel-id <channel-id>
```

## 🔄 Updates and Scaling

### Scaling for Production
```hcl
# Production configuration
environment = "prod"
aurora_max_capacity = 4.0
ecs_max_capacity = 20
enable_deletion_protection = true
cloudfront_price_class = "PriceClass_All"
```

### Blue-Green Deployments
```bash
# Create new environment
terraform workspace new prod
terraform apply -var="environment=prod"

# Switch traffic via Route53 weighted routing
```

## 📞 Support

### Getting Help
- **Documentation**: Check module README files
- **Logs**: CloudWatch logs for all services
- **Metrics**: CloudWatch dashboards and alarms
- **Costs**: AWS Cost Explorer and budgets

### Emergency Procedures
1. **High Costs**: Check MediaLive channels, stop if needed
2. **Security Issues**: Review WAF logs, update rules
3. **Performance Issues**: Check ECS auto-scaling, Aurora metrics
4. **Outages**: Check ALB health checks, ECS service status

---

## ✅ Deployment Checklist

- [ ] AWS CLI configured with appropriate permissions
- [ ] Terraform installed and initialized
- [ ] Variables configured in terraform.tfvars
- [ ] Infrastructure deployed successfully
- [ ] Container images built and pushed (if using ECS)
- [ ] Health checks passing
- [ ] Monitoring dashboards accessible
- [ ] Cost alerts configured
- [ ] Security settings reviewed
- [ ] Backup verification completed

**🎉 Congratulations! Your streaming platform infrastructure is now deployed and ready for use.**