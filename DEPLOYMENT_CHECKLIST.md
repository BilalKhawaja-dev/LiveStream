# Deployment Checklist

## Pre-Deployment Validation ✅

- [x] **Terraform Configuration**
  - [x] All syntax errors fixed
  - [x] Configuration validated successfully
  - [x] All modules properly structured

- [x] **Frontend Applications**
  - [x] All 6 applications have proper structure
  - [x] All Dockerfiles present and valid
  - [x] Build script executable and tested
  - [x] Cross-service integration implemented

- [x] **Backend Services**
  - [x] All Lambda functions syntax validated
  - [x] Database schemas properly defined
  - [x] API Gateway configuration complete
  - [x] Monitoring and alerting configured

- [x] **Infrastructure Components**
  - [x] VPC and networking configured
  - [x] ECS with service discovery
  - [x] Load balancer configuration
  - [x] Security groups and WAF rules

## Deployment Steps

### 1. Infrastructure Deployment

```bash
# 1. Review and update terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values

# 2. Plan the deployment
terraform plan -out=tfplan

# 3. Apply the infrastructure
terraform apply tfplan
```

### 2. Container Images

```bash
# 1. Build all container images
cd streaming-platform-frontend
./build-containers.sh

# 2. If using ECR, tag and push images
export REGISTRY_URL="your-account-id.dkr.ecr.region.amazonaws.com"
./build-containers.sh
```

### 3. Database Initialization

```bash
# The Aurora database will be initialized automatically via Lambda
# Check CloudWatch logs for initialization status
```

### 4. Post-Deployment Verification

```bash
# 1. Check ECS services
aws ecs list-services --cluster streaming-platform-dev-cluster

# 2. Check ALB health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# 3. Test API endpoints
curl https://your-api-domain/auth/login

# 4. Check CloudWatch dashboards
# Navigate to CloudWatch console and verify dashboards are populated
```

## Configuration Requirements

### Required AWS Services
- ECS Fargate
- Aurora Serverless v2
- DynamoDB
- API Gateway
- Lambda
- CloudWatch
- S3
- MediaLive (for streaming)
- Cognito (for authentication)

### Required Permissions
- ECS full access
- RDS full access
- DynamoDB full access
- Lambda full access
- API Gateway full access
- CloudWatch full access
- S3 full access
- MediaLive full access
- Cognito full access

### Environment Variables to Configure

#### terraform.tfvars
```hcl
project_name = "streaming-platform"
environment  = "dev"
aws_region   = "us-east-1"

# Networking
vpc_cidr = "10.0.0.0/16"

# Database
aurora_master_username = "admin"
aurora_database_name   = "streaming_platform"

# Domain (optional)
domain_name = "your-domain.com"

# Notification email
notification_email = "your-email@domain.com"
```

#### Frontend .env
```bash
REACT_APP_API_BASE_URL=https://your-api-domain
REACT_APP_COGNITO_USER_POOL_ID=your-user-pool-id
REACT_APP_COGNITO_USER_POOL_CLIENT_ID=your-client-id
REACT_APP_AWS_REGION=us-east-1
```

## Monitoring and Alerts

### CloudWatch Dashboards Created
- Infrastructure Overview
- ECS Applications Monitoring  
- Lambda Functions Monitoring
- Streaming and Media Services
- Cost Monitoring
- Security Monitoring

### Alarms Configured
- ECS high CPU/memory usage
- Lambda function errors
- API Gateway 4xx/5xx errors
- Database connection issues
- Cost threshold alerts

## Security Features Implemented

- [x] WAF protection on API Gateway
- [x] VPC with private subnets
- [x] Security groups with least privilege
- [x] IAM roles with minimal permissions
- [x] Encryption at rest and in transit
- [x] Content moderation with AI services
- [x] Rate limiting and throttling

## Rollback Procedures

### Infrastructure Rollback
```bash
# 1. Revert to previous Terraform state
terraform apply -target=module.specific_module

# 2. Or destroy and recreate
terraform destroy
terraform apply
```

### Application Rollback
```bash
# 1. Deploy previous container images
TAG=previous-version ./build-containers.sh

# 2. Update ECS services
aws ecs update-service --cluster cluster-name --service service-name --task-definition task-def:previous-revision
```

## Troubleshooting

### Common Issues

1. **ECS Services Not Starting**
   - Check CloudWatch logs
   - Verify security group rules
   - Check task definition resource limits

2. **Database Connection Issues**
   - Verify Aurora cluster is running
   - Check security group rules
   - Verify database credentials

3. **API Gateway 5xx Errors**
   - Check Lambda function logs
   - Verify IAM permissions
   - Check integration timeouts

4. **Frontend Not Loading**
   - Check ALB target group health
   - Verify container health checks
   - Check CloudFront distribution (if used)

### Useful Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster cluster-name --services service-name

# View Lambda logs
aws logs tail /aws/lambda/function-name --follow

# Check API Gateway logs
aws logs tail /aws/apigateway/api-name --follow

# Monitor ECS tasks
aws ecs list-tasks --cluster cluster-name --service-name service-name
```

## Performance Optimization

### Auto Scaling Configured
- ECS services scale based on CPU/memory
- Aurora scales based on connections
- API Gateway has usage plans and throttling

### Cost Optimization
- Fargate Spot instances enabled
- Aurora Serverless v2 for variable workloads
- S3 lifecycle policies for log retention
- CloudWatch log retention policies

## Next Steps After Deployment

1. **Set up CI/CD Pipeline**
   - GitHub Actions or AWS CodePipeline
   - Automated testing and deployment

2. **Configure Custom Domain**
   - Route 53 hosted zone
   - ACM certificate
   - CloudFront distribution

3. **Enhanced Monitoring**
   - X-Ray tracing
   - Custom metrics
   - Application Insights

4. **Security Hardening**
   - AWS Config rules
   - GuardDuty monitoring
   - Security Hub compliance

5. **Backup and Disaster Recovery**
   - Aurora automated backups
   - Cross-region replication
   - Infrastructure as Code versioning