# API Gateway Module

This module creates an AWS API Gateway with custom domain and SSL certificate for the streaming platform frontend applications.

## Features

- **Regional API Gateway** with custom domain support
- **AWS-managed SSL certificate** with automatic validation
- **Path-based routing** for 6 frontend applications:
  - `/viewer/*` - Viewer Portal (Customer-Facing Application)
  - `/creator/*` - Creator Dashboard (Content Creator Interface)
  - `/admin/*` - Admin Portal (Platform Management)
  - `/support/*` - Support System (Customer Service Interface)
  - `/analytics/*` - Analytics Dashboard (Business Intelligence)
  - `/dev/*` - Developer Console (System Monitoring & Debugging)
- **CORS configuration** for cross-origin requests
- **CloudWatch logging** with structured log format
- **X-Ray tracing** for request monitoring
- **Throttling and caching** configuration
- **CloudWatch alarms** for monitoring 4XX/5XX errors and latency
- **Route53 integration** for DNS management

## Requirements

- Route53 hosted zone for domain validation
- Application Load Balancer for backend integration
- KMS key for log encryption (optional)
- SNS topics for alarm notifications (optional)

## Usage

```hcl
module "api_gateway" {
  source = "./modules/api_gateway"

  project_name     = "streaming-platform"
  environment      = "prod"
  domain_name      = "api.streaming-platform.com"
  route53_zone_id  = "Z1234567890ABC"
  alb_dns_name     = "streaming-alb-123456789.us-east-1.elb.amazonaws.com"
  
  # Optional configurations
  enable_xray_tracing        = true
  api_gateway_logging_level  = "INFO"
  throttling_rate_limit      = 1000
  throttling_burst_limit     = 2000
  enable_caching            = false
  
  # Monitoring
  enable_cloudwatch_alarms  = true
  sns_topic_arns           = ["arn:aws:sns:us-east-1:123456789012:alerts"]
  error_4xx_threshold      = 10
  error_5xx_threshold      = 5
  latency_threshold_ms     = 5000
  
  tags = {
    Environment = "prod"
    Project     = "streaming-platform"
    Service     = "api-gateway"
  }
}
```

## Architecture

The API Gateway acts as a single entry point for all frontend applications, providing:

1. **SSL Termination**: AWS-managed certificate with automatic renewal
2. **Path-based Routing**: Routes requests to appropriate ALB target groups
3. **CORS Handling**: Enables cross-origin requests for web applications
4. **Monitoring**: CloudWatch logs, metrics, and alarms
5. **Security**: Throttling and request validation

## Path Routing

| Path Pattern | Target Application | Description |
|-------------|-------------------|-------------|
| `/viewer/*` | Viewer Portal | Customer streaming interface |
| `/creator/*` | Creator Dashboard | Stream management and analytics |
| `/admin/*` | Admin Portal | Platform administration |
| `/support/*` | Support System | Customer service tools |
| `/analytics/*` | Analytics Dashboard | Business intelligence |
| `/dev/*` | Developer Console | System monitoring and debugging |

## Monitoring

The module includes comprehensive monitoring:

- **Access Logs**: Structured JSON logs in CloudWatch
- **Metrics**: Request count, latency, error rates
- **Alarms**: 4XX errors, 5XX errors, high latency
- **X-Ray Tracing**: Request flow visualization

## Security

- **HTTPS Only**: All traffic encrypted with TLS
- **Throttling**: Rate limiting to prevent abuse
- **CORS**: Configured for secure cross-origin requests
- **Logging**: All requests logged for audit purposes

## Integration with ALB

The API Gateway forwards requests to an Application Load Balancer using HTTP_PROXY integration:

```
Client → API Gateway → ALB → ECS Services
```

This allows for:
- SSL termination at API Gateway
- Path-based routing to different ECS services
- Health checks and auto-scaling at ALB level
- Blue-green deployments through ALB target groups

## Outputs

The module provides outputs for integration with other resources:

- API Gateway ID and ARN
- Domain name and certificate ARN
- CloudWatch log group details
- Resource IDs for each application path

## Requirements Mapping

This module addresses the following requirements:

- **7.1**: Cross-application navigation with unified entry point
- **7.2**: Context preservation between applications
- **10.2**: HTTPS/TLS encryption for all communications