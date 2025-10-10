# Monitoring Module

This module creates comprehensive CloudWatch dashboards for infrastructure monitoring, cost tracking, and performance analysis of the streaming platform's centralized logging system.

## Features

### Dashboard Collection
- **Infrastructure Overview**: High-level system health and performance metrics
- **Log Pipeline Health**: End-to-end log processing pipeline monitoring
- **Cost Monitoring**: Resource usage and cost optimization tracking
- **Query Performance**: Athena and Glue performance analysis
- **Security Monitoring**: Authentication failures and access control events

### Monitoring Capabilities
- **Real-time metrics**: Live infrastructure performance data
- **Cost tracking**: S3 storage tiers, Athena queries, and database usage
- **Log analysis**: Pipeline throughput and error detection
- **Performance insights**: Query execution times and resource utilization
- **Security events**: Failed authentication and access denied events

### Visualization Features
- **Time series charts**: Trend analysis and historical data
- **Log insights queries**: Real-time log analysis and filtering
- **Stacked metrics**: Resource usage breakdown by service
- **Custom widgets**: Tailored monitoring for specific use cases

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name = "streaming-logs"
  environment  = "dev"
  
  # Resource identifiers
  s3_logs_bucket_name              = module.storage.streaming_logs_bucket_id
  s3_error_logs_bucket_name        = module.storage.error_logs_bucket_id
  s3_backups_bucket_name           = module.storage.backups_bucket_id
  s3_athena_results_bucket_name    = module.storage.athena_results_bucket_id
  aurora_cluster_id                = module.aurora.cluster_id
  dynamodb_log_metadata_table_name = module.dynamodb.log_metadata_table_name
  athena_workgroup_name            = module.athena.athena_workgroup_name
  glue_crawler_name                = module.glue_catalog.glue_crawler_name
  
  # Dashboard configuration
  enable_security_dashboard    = true
  enable_cost_dashboard       = true
  enable_performance_dashboard = true
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

### CloudWatch Dashboards
- `aws_cloudwatch_dashboard.infrastructure_overview` - Main system overview
- `aws_cloudwatch_dashboard.log_pipeline_health` - Log processing pipeline
- `aws_cloudwatch_dashboard.cost_monitoring` - Cost and usage tracking
- `aws_cloudwatch_dashboard.query_performance` - Query execution analysis
- `aws_cloudwatch_dashboard.security_monitoring` - Security event monitoring

## Dashboard Details

### 1. Infrastructure Overview Dashboard
**Purpose**: Provides a high-level view of system health and performance

**Widgets**:
- **Log Events by Service**: Incoming log volume from all streaming services
- **Kinesis Firehose Delivery**: Data delivery success rates and freshness
- **S3 Storage Usage**: Storage consumption across all buckets by tier
- **Aurora Performance**: Database CPU, connections, and memory usage
- **DynamoDB Performance**: Table capacity consumption and throttling

**Use Cases**:
- System health monitoring
- Capacity planning
- Performance troubleshooting
- Service availability tracking

### 2. Log Pipeline Health Dashboard
**Purpose**: Monitors the end-to-end log processing pipeline

**Widgets**:
- **Log Pipeline Throughput**: Events from CloudWatch Logs to S3
- **Delivery Success Rate**: Firehose delivery success and data freshness
- **Recent Pipeline Errors**: Real-time error log analysis

**Use Cases**:
- Pipeline reliability monitoring
- Data delivery validation
- Error detection and alerting
- Performance optimization

### 3. Cost Monitoring Dashboard
**Purpose**: Tracks resource usage and costs for optimization

**Widgets**:
- **S3 Storage Costs by Tier**: Storage usage across Standard, IA, and Glacier
- **Athena Query Costs**: Data scanned and query execution metrics
- **Aurora Serverless ACU Usage**: Database capacity unit consumption
- **DynamoDB Capacity Usage**: Read/write capacity utilization
- **Firehose Data Transfer**: Data processing volume and costs

**Use Cases**:
- Cost optimization
- Resource right-sizing
- Budget monitoring
- Usage trend analysis

### 4. Query Performance Dashboard
**Purpose**: Analyzes query execution performance and optimization

**Widgets**:
- **Athena Query Performance**: Execution time and data scanned
- **Glue Crawler Performance**: Task completion and failure rates
- **Failed Queries**: Real-time analysis of query failures

**Use Cases**:
- Query optimization
- Performance tuning
- Troubleshooting slow queries
- Data processing monitoring

### 5. Security Monitoring Dashboard
**Purpose**: Monitors security events and access control

**Widgets**:
- **Authentication Failures**: Failed login attempts from Cognito
- **Access Denied Events**: 401/403 errors from API Gateway
- **Security-Related Errors**: Database and system security events

**Use Cases**:
- Security incident detection
- Access pattern analysis
- Threat monitoring
- Compliance reporting

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | `"streaming-logs"` | no |
| environment | Environment name (dev, staging, prod) | `string` | `"dev"` | no |
| s3_logs_bucket_name | Name of the S3 logs bucket | `string` | n/a | yes |
| aurora_cluster_id | Aurora cluster identifier | `string` | n/a | yes |
| dynamodb_log_metadata_table_name | DynamoDB log metadata table name | `string` | n/a | yes |
| athena_workgroup_name | Athena workgroup name | `string` | n/a | yes |
| enable_security_dashboard | Enable security monitoring dashboard | `bool` | `true` | no |
| enable_cost_dashboard | Enable cost monitoring dashboard | `bool` | `true` | no |
| dashboard_refresh_interval | Dashboard refresh interval in seconds | `number` | `300` | no |

## Outputs

| Name | Description |
|------|-------------|
| dashboard_urls | Map of CloudWatch dashboard URLs |
| dashboard_names | Map of CloudWatch dashboard names |
| dashboard_arns | Map of CloudWatch dashboard ARNs |
| monitoring_configuration | Summary of monitoring configuration |

## Environment-Specific Configurations

### Development Environment
- **Refresh interval**: 5 minutes (300 seconds)
- **Security dashboard**: Enabled for testing
- **Cost monitoring**: Enabled for optimization
- **Custom metrics**: Optional for development

### Staging Environment
- **Refresh interval**: 5 minutes (300 seconds)
- **Security dashboard**: Enabled for validation
- **Cost monitoring**: Enabled for testing
- **Performance monitoring**: Full suite enabled

### Production Environment
- **Refresh interval**: 1 minute (60 seconds)
- **Security dashboard**: Enabled for compliance
- **Cost monitoring**: Enabled for optimization
- **Performance monitoring**: Full suite with alerting

## Monitoring Best Practices

### Dashboard Organization
- **Logical grouping**: Related metrics grouped in single widgets
- **Time alignment**: Consistent time ranges across widgets
- **Color coding**: Consistent colors for similar metrics
- **Clear titles**: Descriptive widget and dashboard names

### Metric Selection
- **Key performance indicators**: Focus on business-critical metrics
- **Leading indicators**: Metrics that predict issues
- **Actionable metrics**: Metrics that drive operational decisions
- **Cost-effective monitoring**: Balance detail with cost

### Alert Integration
- **Dashboard alarms**: Link dashboards to CloudWatch alarms
- **Notification routing**: Connect to SNS topics for alerting
- **Escalation paths**: Define clear escalation procedures
- **Documentation**: Maintain runbooks for common issues

## Cost Optimization

### Dashboard Costs
- **Widget efficiency**: Optimize number of metrics per widget
- **Refresh rates**: Balance freshness with API call costs
- **Log insights**: Use efficient queries to reduce scan costs
- **Retention**: Set appropriate log retention periods

### Monitoring ROI
- **Issue prevention**: Early detection reduces incident costs
- **Performance optimization**: Identify cost-saving opportunities
- **Capacity planning**: Right-size resources based on trends
- **Automated responses**: Reduce manual intervention costs

## Integration with Alerting

### CloudWatch Alarms
- **Metric alarms**: Based on dashboard metrics
- **Composite alarms**: Combine multiple conditions
- **Anomaly detection**: Machine learning-based alerting
- **Custom metrics**: Application-specific monitoring

### Notification Channels
- **SNS topics**: Email and SMS notifications
- **Slack integration**: Team collaboration channels
- **PagerDuty**: Incident management integration
- **Custom webhooks**: Integration with external systems

## Troubleshooting

### Common Issues

1. **Missing metrics**: Check resource names and regions
2. **Permission errors**: Verify CloudWatch permissions
3. **Empty widgets**: Confirm resources are generating metrics
4. **Slow loading**: Optimize queries and reduce time ranges

### Performance Optimization

1. **Widget efficiency**: Limit metrics per widget
2. **Query optimization**: Use efficient log insights queries
3. **Time range selection**: Balance detail with performance
4. **Caching**: Leverage CloudWatch metric caching

## Maintenance

### Regular Tasks
- **Review dashboard relevance**: Remove unused dashboards
- **Update resource references**: Keep resource IDs current
- **Optimize queries**: Improve log insights query performance
- **Cost analysis**: Monitor dashboard usage costs

### Dashboard Evolution
- **User feedback**: Incorporate operational team input
- **New metrics**: Add metrics for new services
- **Layout optimization**: Improve dashboard organization
- **Mobile compatibility**: Ensure dashboards work on mobile devices