# DynamoDB Module

This module creates DynamoDB tables with on-demand billing, encryption, and comprehensive monitoring for the streaming platform's centralized logging system.

## Features

### Core Infrastructure
- **Four DynamoDB tables** optimized for different use cases:
  - **Log Metadata**: Stores log event metadata and indexing information
  - **User Sessions**: Tracks user session data and activity
  - **System Config**: Manages system configuration and feature flags
  - **Audit Trail**: Records audit events for compliance and security
- **On-demand billing** for cost-effective development and automatic scaling
- **Customer-managed KMS encryption** for all tables
- **Point-in-time recovery** with configurable retention periods

### Security & Compliance
- **Encryption at rest** using customer-managed KMS keys
- **Fine-grained access control** through IAM policies
- **Audit trail table** for compliance and security monitoring
- **TTL (Time To Live)** for automatic data cleanup and cost optimization

### Monitoring & Alerting
- **Comprehensive CloudWatch alarms** for:
  - Read/write throttle events
  - Consumed capacity monitoring (provisioned mode)
  - System and user errors
  - Performance metrics
- **SNS integration** for alarm notifications
- **Auto-scaling support** for provisioned billing mode

### Data Management
- **Global Secondary Indexes (GSI)** for efficient querying:
  - Service-based queries for log metadata
  - User-based queries for sessions and audit trails
  - Time-based queries for all tables
- **DynamoDB Streams** support for change data capture
- **TTL configuration** for automatic data lifecycle management

## Usage

```hcl
module "dynamodb" {
  source = "./modules/dynamodb"
  
  project_name = "streaming-logs"
  environment  = "dev"
  
  # Billing configuration
  billing_mode = "PAY_PER_REQUEST"  # Cost-effective for development
  
  # Backup and recovery
  enable_point_in_time_recovery = true
  backup_retention_days         = 7
  
  # Monitoring
  enable_cloudwatch_alarms = true
  
  # Security
  kms_deletion_window = 7
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Resources Created

### Core Resources
- `aws_dynamodb_table` - Four tables for different data types
- `aws_kms_key` - Customer-managed encryption key
- `aws_kms_alias` - KMS key alias for easy reference

### Monitoring Resources
- `aws_cloudwatch_metric_alarm` - Comprehensive monitoring alarms
- `aws_sns_topic` - Alarm notifications (optional)

### Auto-scaling Resources (Provisioned Mode)
- `aws_appautoscaling_target` - Auto-scaling targets
- `aws_appautoscaling_policy` - Auto-scaling policies

## Tables Overview

### 1. Log Metadata Table
**Purpose**: Store log event metadata and enable efficient querying

**Schema**:
- **Hash Key**: `log_id` (String)
- **Range Key**: `timestamp` (String)
- **Attributes**: `service_name`, `log_level`, `user_id`, `message`, etc.

**Global Secondary Indexes**:
- **ServiceIndex**: Query by service and time
- **LogLevelIndex**: Query by log level and time
- **UserIndex**: Query by user and time

**Features**:
- TTL enabled for automatic cleanup
- Point-in-time recovery enabled
- Streams optional (disabled by default)

### 2. User Sessions Table
**Purpose**: Track user session data and activity patterns

**Schema**:
- **Hash Key**: `session_id` (String)
- **Range Key**: `user_id` (String)
- **Attributes**: `created_at`, `last_activity`, `ip_address`, etc.

**Global Secondary Indexes**:
- **UserSessionIndex**: Query sessions by user and creation time

**Features**:
- TTL enabled for session cleanup
- Point-in-time recovery enabled
- Automatic session expiration

### 3. System Config Table
**Purpose**: Manage system configuration and feature flags

**Schema**:
- **Hash Key**: `config_key` (String)
- **Attributes**: `environment`, `config_value`, `description`, etc.

**Global Secondary Indexes**:
- **EnvironmentIndex**: Query configuration by environment

**Features**:
- No TTL (persistent configuration)
- Point-in-time recovery enabled
- Streams enabled for configuration change tracking

### 4. Audit Trail Table
**Purpose**: Record audit events for compliance and security

**Schema**:
- **Hash Key**: `audit_id` (String)
- **Range Key**: `timestamp` (String)
- **Attributes**: `action_type`, `user_id`, `resource_id`, etc.

**Global Secondary Indexes**:
- **ActionTypeIndex**: Query by action type and time
- **UserAuditIndex**: Query by user and time

**Features**:
- TTL enabled for compliance retention
- Point-in-time recovery enabled
- Comprehensive audit logging

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | `"streaming-logs"` | no |
| environment | Environment name (dev, staging, prod) | `string` | `"dev"` | no |
| billing_mode | DynamoDB billing mode | `string` | `"PAY_PER_REQUEST"` | no |
| enable_point_in_time_recovery | Enable point-in-time recovery | `bool` | `true` | no |
| backup_retention_days | Point-in-time recovery retention period | `number` | `7` | no |
| enable_streams | Enable DynamoDB Streams | `bool` | `false` | no |
| enable_ttl | Enable Time To Live for automatic cleanup | `bool` | `true` | no |
| enable_cloudwatch_alarms | Enable CloudWatch alarms | `bool` | `true` | no |
| kms_deletion_window | KMS key deletion window in days | `number` | `7` | no |

## Outputs

| Name | Description |
|------|-------------|
| table_names | Map of DynamoDB table names |
| table_arns | Map of DynamoDB table ARNs |
| kms_key_arn | KMS key ARN used for encryption |
| table_configurations | Summary of table configurations |
| dynamodb_endpoints | Connection information for applications |

## Environment-Specific Configurations

### Development Environment
- **Billing mode**: PAY_PER_REQUEST for cost optimization
- **Backup retention**: 7 days
- **TTL**: Enabled for cost management
- **Streams**: Disabled to reduce costs
- **Monitoring**: Basic alarms enabled

### Staging Environment
- **Billing mode**: PAY_PER_REQUEST or PROVISIONED
- **Backup retention**: 14 days
- **TTL**: Enabled with longer retention
- **Streams**: Enabled for testing
- **Monitoring**: Full alarm suite

### Production Environment
- **Billing mode**: PROVISIONED with auto-scaling
- **Backup retention**: 30+ days
- **TTL**: Enabled with compliance retention
- **Streams**: Enabled for real-time processing
- **Monitoring**: Comprehensive alarms and dashboards

## Cost Optimization

### On-Demand Billing
- **Automatic scaling**: No capacity planning required
- **Pay-per-use**: Only pay for actual read/write requests
- **No idle costs**: Perfect for development and variable workloads

### TTL Configuration
- **Automatic cleanup**: Reduces storage costs
- **Compliance retention**: Configurable retention periods
- **No manual intervention**: Automated data lifecycle

### Monitoring Costs
- **Targeted alarms**: Focus on critical metrics
- **Threshold optimization**: Environment-specific thresholds
- **SNS integration**: Cost-effective notifications

## Security Best Practices

1. **Encryption**: All data encrypted at rest with customer-managed KMS keys
2. **Access control**: Fine-grained IAM policies for table access
3. **Audit logging**: Comprehensive audit trail for compliance
4. **Network security**: VPC endpoints for private connectivity
5. **Backup encryption**: Point-in-time recovery data encrypted

## Monitoring & Alerting

### CloudWatch Alarms
- **Throttle monitoring**: Read/write throttle events
- **Capacity monitoring**: Consumed capacity for provisioned tables
- **Error monitoring**: System and user errors
- **Performance monitoring**: Latency and success rates

### Metrics Available
- Read/write capacity consumption
- Throttle events and errors
- Item count and table size
- Global Secondary Index metrics

## Backup & Recovery

### Point-in-Time Recovery
- **Continuous backups**: Automatic backup every second
- **Retention period**: Configurable (7-35 days)
- **Recovery granularity**: Restore to any point within retention period
- **Cross-region support**: Available for disaster recovery

### Best Practices
- **Regular testing**: Test recovery procedures regularly
- **Monitoring**: Monitor backup lag and failures
- **Documentation**: Maintain recovery runbooks

## Integration

The DynamoDB module integrates with:
- **Application services**: Provides data storage for log metadata and user sessions
- **Monitoring systems**: Exports metrics to CloudWatch
- **Security systems**: Audit trail and access logging
- **Cost management**: Automated cleanup and optimization

## Troubleshooting

### Common Issues

1. **Throttling**: Increase capacity or optimize access patterns
2. **Hot partitions**: Review partition key design
3. **High costs**: Enable TTL and optimize queries
4. **Backup failures**: Check IAM permissions and retention settings

### Monitoring Resources
- **CloudWatch dashboards**: Create custom dashboards for table metrics
- **DynamoDB Insights**: Use for performance analysis
- **Cost Explorer**: Monitor DynamoDB costs and usage patterns

## Dependencies

This module requires:
- Proper IAM permissions for DynamoDB operations
- KMS permissions for encryption key management
- CloudWatch permissions for monitoring and alarms

## Performance Optimization

### Query Patterns
- **Use GSI effectively**: Design indexes for common query patterns
- **Avoid scans**: Use Query operations instead of Scan
- **Batch operations**: Use batch read/write for efficiency
- **Consistent reads**: Use eventually consistent reads when possible

### Capacity Planning
- **Monitor metrics**: Track consumed capacity and throttling
- **Auto-scaling**: Enable for provisioned tables
- **On-demand**: Consider for unpredictable workloads
- **Reserved capacity**: Consider for predictable workloads in production