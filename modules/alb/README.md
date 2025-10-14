# Application Load Balancer (ALB) Module

This module creates an Application Load Balancer with path-based routing for the streaming platform frontend applications, integrated with API Gateway certificate management.

## Features

- **Application Load Balancer** with HTTPS termination
- **Path-based routing** for 6 frontend applications
- **Target groups** with health checks for each application
- **Security groups** with appropriate ingress/egress rules
- **CloudWatch monitoring** with alarms for key metrics
- **SSL/TLS termination** using API Gateway certificate
- **HTTP to HTTPS redirect** for security
- **WAF integration** support for additional security
- **Access logging** to S3 or CloudWatch
- **Auto-scaling integration** ready for ECS services

## Architecture

```
API Gateway → ALB → Target Groups → ECS Services
     ↓
  SSL Cert
```

The ALB receives traffic from API Gateway and routes it to appropriate ECS services based on path patterns.

## Target Applications

| Application | Path Pattern | Port | Health Check |
|------------|-------------|------|--------------|
| Viewer Portal | `/viewer/*` | 80 | `/health` |
| Creator Dashboard | `/creator/*` | 80 | `/health` |
| Admin Portal | `/admin/*` | 80 | `/health` |
| Support System | `/support/*` | 80 | `/health` |
| Analytics Dashboard | `/analytics/*` | 80 | `/health` |
| Developer Console | `/dev/*` | 80 | `/health` |

## Usage

```hcl
module "alb" {
  source = "./modules/alb"

  project_name       = "streaming-platform"
  environment        = "prod"
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = "10.0.0.0/16"
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.api_gateway.certificate_arn

  # Frontend applications configuration
  frontend_applications = {
    viewer = {
      port              = 80
      priority          = 10
      health_check_path = "/health"
    }
    creator = {
      port              = 80
      priority          = 20
      health_check_path = "/health"
    }
    admin = {
      port              = 80
      priority          = 30
      health_check_path = "/health"
    }
    support = {
      port              = 80
      priority          = 40
      health_check_path = "/health"
    }
    analytics = {
      port              = 80
      priority          = 50
      health_check_path = "/health"
    }
    dev = {
      port              = 80
      priority          = 60
      health_check_path = "/health"
    }
  }

  # Security
  enable_deletion_protection = true
  ssl_policy                = "ELBSecurityPolicy-TLS-1-2-2017-01"
  
  # Logging
  enable_access_logs    = true
  access_logs_bucket   = "${var.project_name}-alb-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"
  
  # Monitoring
  enable_cloudwatch_alarms = true
  sns_topic_arns          = ["arn:aws:sns:us-east-1:123456789012:alerts"]
  response_time_threshold = 5
  unhealthy_host_threshold = 1
  http_5xx_threshold      = 10

  tags = {
    Environment = "prod"
    Project     = "streaming-platform"
    Service     = "load-balancer"
  }
}
```

## Health Checks

Each target group is configured with health checks:

- **Path**: `/health` (configurable per application)
- **Protocol**: HTTP
- **Port**: Traffic port (80)
- **Healthy threshold**: 2 consecutive successes
- **Unhealthy threshold**: 3 consecutive failures
- **Timeout**: 5 seconds
- **Interval**: 30 seconds

## Security Features

### Security Groups
- **Ingress**: HTTP (80), HTTPS (443), Health check port
- **Egress**: All traffic allowed
- **Source**: API Gateway and VPC CIDR for health checks

### SSL/TLS
- **Certificate**: Uses API Gateway managed certificate
- **Policy**: Configurable SSL policy (default: TLS 1.2)
- **Redirect**: Automatic HTTP to HTTPS redirect

### WAF Integration
- Optional WAF Web ACL association
- Additional protection against common web exploits
- Rate limiting and IP filtering capabilities

## Monitoring and Alarms

### CloudWatch Metrics
- **Target Response Time**: Average response time from targets
- **Unhealthy Host Count**: Number of unhealthy targets
- **HTTP 5XX Errors**: Server error count
- **Request Count**: Total number of requests
- **Active Connection Count**: Number of active connections

### Alarms
- **High Response Time**: Triggers when average response time exceeds threshold
- **Unhealthy Hosts**: Triggers when unhealthy host count exceeds threshold
- **5XX Errors**: Triggers when 5XX error count exceeds threshold

## Integration with ECS

The ALB target groups are designed to work with ECS services:

```hcl
resource "aws_ecs_service" "viewer_portal" {
  # ... other configuration ...

  load_balancer {
    target_group_arn = module.alb.target_group_arns["viewer"]
    container_name   = "viewer-portal"
    container_port   = 80
  }
}
```

## Load Balancing Algorithms

Supports two algorithms:
- **Round Robin** (default): Distributes requests evenly
- **Least Outstanding Requests**: Routes to target with fewest active requests

## Stickiness

Optional session stickiness using load balancer cookies:
- **Duration**: Configurable (default: 24 hours)
- **Type**: Load balancer generated cookie
- **Use case**: Stateful applications requiring session persistence

## Access Logging

Two options for access logs:
1. **S3 Bucket**: Traditional ALB access logs to S3
2. **CloudWatch Logs**: Real-time log streaming to CloudWatch

Log format includes:
- Request timestamp and processing time
- Client IP and user agent
- Request method and URI
- Response status and size
- Target information

## Deployment Considerations

### Blue-Green Deployments
- Target groups support blue-green deployment patterns
- Health checks ensure traffic only goes to healthy targets
- Gradual traffic shifting supported

### Auto Scaling
- Target groups automatically register/deregister targets
- Health checks trigger auto-scaling events
- Connection draining during scale-down events

### Multi-AZ
- ALB spans multiple availability zones
- Target groups can have targets in multiple AZs
- Automatic failover between AZs

## Requirements Mapping

This module addresses the following requirements:

- **7.3**: ALB integration with API Gateway certificate
- **8.1**: Health checks for each target group with /health endpoints
- **8.6**: Path-based routing to match API Gateway structure

## Dependencies

- VPC with public subnets
- SSL certificate (from API Gateway module)
- S3 bucket for access logs (optional)
- SNS topics for alarm notifications (optional)
- WAF Web ACL (optional)

## Outputs

The module provides comprehensive outputs for integration:
- ALB DNS name and zone ID
- Target group ARNs for ECS service integration
- Security group ID for ECS task security groups
- Listener ARNs for additional rule configuration