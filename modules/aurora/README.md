# Aurora Serverless v2 Module

This module creates an Aurora Serverless v2 MySQL cluster with comprehensive backup, monitoring, and alerting capabilities for the streaming platform's centralized logging system.

## Features

### Core Infrastructure
- **Aurora Serverless v2 MySQL 8.0** cluster with development-optimized capacity scaling
- **Multi-AZ deployment** within eu-west-2 region for high availability
- **Encryption at rest and in transit** using customer-managed KMS keys
- **Secrets Manager integration** for secure password management

### Backup and Recovery
- **Automated backups** with configurable retention period (7 days for development)
- **Point-in-time recovery** capability
- **Backup encryption** using KMS keys
- **Cross-region backup preparation** (configurable for production)
- **Backup monitoring** with CloudWatch alarms

### Monitoring and Alerting
- **Enhanced monitoring** with 60-second granularity
- **Performance Insights** for query performance analysis
- **CloudWatch log exports** for error, general, and slow query logs
- **Comprehensive CloudWatch alarms** for:
  - CPU utilization
  - Database connections
  - Memory usage
  - ACU (Aurora Capacity Units) utilization
  - Read/write latency
  - Replica lag (multi-instance setups)
  - Backup failures

### Security
- **VPC deployment** with database subnets and security groups
- **KMS encryption** for data at rest, backups, and Performance Insights
- **IAM roles** for enhanced monitoring
- **Secrets Manager** for credential management
- **Deletion protection** (configurable by environment)

## Usage

```hcl
module "aurora" {
  source = "./modules/aurora"
  
  project_name = "streaming-logs"
  environment  = "dev"
  
  # Serverless v2 scaling
  min_capacity = 0.5
  max_capacity = 2.0
  
  # Backup configuration
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Monitoring
  enable_cloudwatch_alarms = true
  monitoring_interval      = 60
  performance_insights_enabled = true
  
  # Security
  deletion_protection = false  # Set to true for production
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| random | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| random | >= 3.0 |

## Resources Created

### Core Resources
- `aws_rds_cluster` - Aurora Serverless v2 cluster
- `aws_rds_cluster_instance` - Aurora cluster instances
- `aws_db_subnet_group` - Database subnet group
- `aws_kms_key` - KMS key for encryption
- `aws_kms_alias` - KMS key alias

### Security Resources
- `aws_secretsmanager_secret` - Master password secret
- `aws_secretsmanager_secret_version` - Secret version
- `random_password` - Generated master password

### Monitoring Resources
- `aws_cloudwatch_log_group` - Log groups for Aurora logs
- `aws_iam_role` - Enhanced monitoring role
- `aws_iam_role_policy_attachment` - Enhanced monitoring policy
- `aws_sns_topic` - Alarm notifications topic (optional)

### CloudWatch Alarms
- CPU utilization alarms (per instance)
- Database connection count alarm
- Freeable memory alarms (per instance)
- ACU utilization alarm
- Backup failure alarm
- Read/write latency alarms (per instance)
- Replica lag alarms (multi-instance)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | `"streaming-logs"` | no |
| environment | Environment name (dev, staging, prod) | `string` | `"dev"` | no |
| engine_version | Aurora MySQL engine version | `string` | `"8.0.mysql_aurora.3.02.0"` | no |
| database_name | Name of the default database to create | `string` | `"streaming_logs"` | no |
| master_username | Master username for Aurora cluster | `string` | `"admin"` | no |
| min_capacity | Minimum Aurora Serverless v2 capacity units | `number` | `0.5` | no |
| max_capacity | Maximum Aurora Serverless v2 capacity units | `number` | `2.0` | no |
| instance_count | Number of Aurora instances to create | `number` | `1` | no |
| backup_retention_period | Backup retention period in days | `number` | `7` | no |
| backup_window | Preferred backup window (UTC) | `string` | `"03:00-04:00"` | no |
| maintenance_window | Preferred maintenance window (UTC) | `string` | `"sun:04:00-sun:05:00"` | no |
| deletion_protection | Enable deletion protection for Aurora cluster | `bool` | `false` | no |
| enable_cloudwatch_alarms | Enable CloudWatch alarms for Aurora | `bool` | `true` | no |
| monitoring_interval | Enhanced monitoring interval in seconds | `number` | `60` | no |
| performance_insights_enabled | Enable Performance Insights | `bool` | `true` | no |
| sns_topic_arn | SNS topic ARN for alarm notifications | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | Aurora cluster identifier |
| cluster_arn | Aurora cluster ARN |
| cluster_endpoint | Aurora cluster writer endpoint |
| cluster_reader_endpoint | Aurora cluster reader endpoint |
| cluster_port | Aurora cluster port |
| kms_key_id | KMS key ID used for Aurora encryption |
| secrets_manager_secret_arn | Secrets Manager secret ARN for Aurora master password |
| connection_info | Aurora connection information (sensitive) |

## Environment-Specific Configurations

### Development Environment
- **Capacity**: 0.5-2.0 ACU for cost optimization
- **Backup retention**: 7 days
- **Deletion protection**: Disabled
- **Apply immediately**: Enabled for faster development
- **Skip final snapshot**: Enabled

### Production Environment
- **Capacity**: Higher limits based on workload
- **Backup retention**: 30+ days
- **Deletion protection**: Enabled
- **Apply immediately**: Disabled for safety
- **Final snapshot**: Required before deletion

## Cost Optimization

### Development Environment
- **Serverless v2 scaling**: Automatically scales down to 0.5 ACU during low usage
- **Backup retention**: Limited to 7 days to reduce storage costs
- **Log retention**: 7 days for CloudWatch logs
- **Performance Insights**: 7-day retention period

### Monitoring Costs
- **Enhanced monitoring**: 60-second intervals balance cost and visibility
- **CloudWatch alarms**: Focused on critical metrics to avoid alarm proliferation
- **SNS notifications**: Optional topic creation to avoid unnecessary costs

## Security Best Practices

1. **Encryption**: All data encrypted at rest and in transit
2. **Network isolation**: Deployed in private database subnets
3. **Access control**: Security groups restrict database access
4. **Credential management**: Passwords stored in Secrets Manager
5. **Monitoring**: Comprehensive logging and alerting for security events

## Backup and Recovery

### Automated Backups
- **Frequency**: Daily automated backups during maintenance window
- **Retention**: Configurable (7 days for dev, 30+ for prod)
- **Encryption**: All backups encrypted with KMS
- **Point-in-time recovery**: Available within retention period

### Monitoring
- **Backup success**: CloudWatch alarms monitor backup completion
- **Storage usage**: Track backup storage consumption
- **Recovery testing**: Regular recovery testing recommended

## Troubleshooting

### Common Issues

1. **High CPU utilization**: Check query performance and consider scaling
2. **Connection limits**: Monitor connection count and implement connection pooling
3. **Memory pressure**: Review query complexity and data access patterns
4. **Backup failures**: Check IAM permissions and storage availability

### Monitoring Resources
- **CloudWatch dashboards**: Create custom dashboards for Aurora metrics
- **Performance Insights**: Use for query-level performance analysis
- **Enhanced monitoring**: Detailed OS-level metrics available

## Dependencies

This module requires:
- VPC with database subnets (created by networking module)
- Security groups for database access (created by networking module)
- Proper IAM permissions for Aurora service operations

## Integration

The Aurora module integrates with:
- **Application services**: Provides database connectivity for log storage
- **Monitoring systems**: Exports metrics to CloudWatch
- **Backup systems**: Automated backup and recovery capabilities
- **Security systems**: Encrypted storage and secure access controls