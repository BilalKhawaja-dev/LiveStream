# Athena Query Execution Guide

## Prerequisites

Before running these queries, ensure the following setup is complete:

1. **Glue Data Catalog**: Database and table schema are created
2. **S3 Data**: Log data is available in the expected S3 location
3. **Athena Workgroup**: Configured with appropriate cost controls
4. **IAM Permissions**: Query execution permissions for Athena, S3, and Glue

## Query Categories and Usage

### 1. Error Rate Analysis (`error_rate_analysis.sql`)

**Purpose**: Monitor and analyze error patterns across streaming services

**Key Queries**:
- Overall error rate by service (last 24 hours)
- Error trends over time with hourly breakdown
- Top error messages by frequency
- Critical error patterns and cascading failures

**Usage Example**:
```sql
-- Replace date values with your target analysis date
-- Modify the WHERE clause dates based on your needs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
```

**Cost Optimization Tips**:
- Always specify exact date ranges in partition columns
- Use LIMIT clauses for exploratory analysis
- Focus on specific services when possible

### 2. Performance Metrics (`performance_metrics.sql`)

**Purpose**: Track latency, resource usage, and system performance

**Key Queries**:
- Service performance overview with percentile analysis
- Performance trends over time
- High latency request analysis
- Resource usage patterns and SLA monitoring

**Usage Example**:
```sql
-- Adjust latency thresholds based on your SLA requirements
WHERE metrics.latency_ms > 5000  -- Requests over 5 seconds
```

**Cost Optimization Tips**:
- Use APPROX_PERCENTILE for large datasets
- Filter on metrics columns early in WHERE clause
- Aggregate data when possible to reduce result size

### 3. User Activity Analysis (`user_activity_analysis.sql`)

**Purpose**: Analyze user behavior, stream usage, and engagement patterns

**Key Queries**:
- Daily active users and stream activity
- User session analysis with engagement metrics
- Stream engagement patterns by hour
- Payment event analysis and user cohorts

**Usage Example**:
```sql
-- Customize user segmentation thresholds
CASE 
    WHEN total_streams <= 5 THEN 'Light Streamer'
    WHEN total_streams <= 20 THEN 'Regular Streamer'
    ELSE 'Heavy Streamer'
END as streamer_segment
```

**Cost Optimization Tips**:
- Use COUNT DISTINCT efficiently for user metrics
- Filter out inactive users/sessions early
- Use window functions for cohort analysis

### 4. Security Events Analysis (`security_events_analysis.sql`)

**Purpose**: Monitor authentication, authorization, and security incidents

**Key Queries**:
- Authentication events overview
- Suspicious authentication patterns
- Permission changes and authorization events
- Brute force attack detection

**Usage Example**:
```sql
-- Adjust thresholds for suspicious activity detection
HAVING COUNT(*) >= 10  -- 10+ failed attempts for brute force detection
```

**Cost Optimization Tips**:
- Filter to security category early
- Use time windows for correlation analysis
- Limit result sets for security investigations

### 5. System Changes Analysis (`system_changes_analysis.sql`)

**Purpose**: Track configuration updates, deployments, and system modifications

**Key Queries**:
- Deployment and configuration change overview
- Deployment timeline and success rates
- Configuration change impact analysis
- Change rollback and recovery analysis

**Usage Example**:
```sql
-- Customize change impact analysis time window
AND CAST(e.error_time AS timestamp) <= CAST(c.change_time AS timestamp) + INTERVAL '1' HOUR
```

**Cost Optimization Tips**:
- Focus on specific change types when possible
- Use correlation windows efficiently
- Aggregate change events by time periods

### 6. Cost Optimization Queries (`cost_optimization_queries.sql`)

**Purpose**: Analyze data patterns and query performance for cost management

**Key Queries**:
- Data volume and storage cost analysis
- Partition effectiveness validation
- Log level distribution for retention optimization
- Query result caching opportunities

## Query Customization Guidelines

### Date Range Modification

All queries use partition pruning with date filters. Modify these based on your analysis needs:

```sql
-- Single day analysis
WHERE year = '2024' AND month = '10' AND day = '09'

-- Multi-day range
WHERE year = '2024' AND month = '10' AND day BETWEEN '07' AND '09'

-- Specific hour range
WHERE year = '2024' AND month = '10' AND day = '09' AND hour >= '12'
```

### Service Filtering

Focus queries on specific services to reduce costs:

```sql
-- Streaming-specific services
AND service IN ('medialive', 'mediastore', 'ecs')

-- User-facing services
AND service IN ('apigateway', 'cognito', 'payment')

-- Security-relevant services
AND service IN ('cognito', 'apigateway', 'auth-service')
```

### Performance Thresholds

Adjust performance and alerting thresholds based on your requirements:

```sql
-- Latency thresholds
WHERE metrics.latency_ms > 5000  -- 5 seconds
WHERE metrics.latency_ms > 1000  -- 1 second

-- Error rate thresholds
HAVING error_rate_percent > 5.0  -- 5% error rate

-- Activity thresholds
HAVING COUNT(*) >= 10  -- Minimum activity level
```

## Cost Control Best Practices

### 1. Workgroup Configuration

Set up your Athena workgroup with cost controls:

```sql
-- Example workgroup settings
Data scanned limit: 1 GB per query
Query timeout: 30 minutes
Results retention: 7 days
```

### 2. Query Result Lifecycle

Configure S3 lifecycle policies for query results:

```sql
-- Transition to IA after 30 days
-- Delete after 90 days for development
```

### 3. Monitoring Query Costs

Track query costs using CloudWatch metrics:

- `DataScannedInBytes`
- `QueryExecutionTime`
- `ProcessedBytes`

### 4. Query Optimization Checklist

Before running queries, verify:

- [ ] Partition columns included in WHERE clause
- [ ] Specific date ranges defined
- [ ] Only required columns selected
- [ ] LIMIT clause used for exploration
- [ ] Aggregation used to reduce result size
- [ ] Service filters applied when appropriate

## Troubleshooting Common Issues

### 1. High Query Costs

**Problem**: Query scanning too much data
**Solution**: 
- Add more specific partition filters
- Reduce date range
- Use column pruning
- Add service filters

### 2. Slow Query Performance

**Problem**: Query taking too long to execute
**Solution**:
- Use LIMIT for initial testing
- Add more WHERE clause filters
- Use approximate functions for large datasets
- Consider pre-aggregated views

### 3. Schema Evolution Issues

**Problem**: Queries failing due to schema changes
**Solution**:
- Use Glue Crawler to update schema
- Handle missing columns with COALESCE
- Use schema versioning in table names

### 4. Partition Not Found Errors

**Problem**: Queries failing on missing partitions
**Solution**:
- Verify data exists for specified dates
- Check partition naming conventions
- Use MSCK REPAIR TABLE if needed

## Example Execution Workflow

1. **Start with Cost Optimization Queries**
   - Analyze data volume and patterns
   - Validate partition effectiveness

2. **Run Service-Specific Analysis**
   - Focus on one service at a time
   - Use appropriate date ranges

3. **Investigate Issues**
   - Use error analysis for problems
   - Correlate with performance metrics

4. **Monitor Trends**
   - Run regular performance queries
   - Track user activity patterns

5. **Security Review**
   - Weekly security event analysis
   - Monitor authentication patterns

Remember to always test queries with LIMIT clauses first and monitor your query costs through the Athena console and CloudWatch metrics.