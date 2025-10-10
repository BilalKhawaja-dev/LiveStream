# Athena Queries for Centralized Logging Analysis

This directory contains sample Athena SQL queries for analyzing logs from the streaming platform. These queries are optimized for cost efficiency and cover common analysis patterns.

## Query Categories

1. **Error Rate Analysis** - Monitor and analyze error patterns across services
2. **Performance Metrics** - Track latency, resource usage, and system performance
3. **User Activity** - Analyze user behavior, stream usage, and engagement
4. **Security Events** - Monitor authentication, authorization, and security incidents
5. **System Changes** - Track configuration updates and deployments

## Cost Optimization Techniques

### Partition Pruning
- Always include partition columns (year, month, day, hour) in WHERE clauses
- Use specific date ranges to limit data scanned
- Example: `WHERE year = '2024' AND month = '10' AND day = '09'`

### Column Selection
- Select only required columns instead of using `SELECT *`
- Use column pruning to reduce data transfer costs
- Example: `SELECT timestamp, service, level, message` instead of `SELECT *`

### Data Compression
- Queries automatically benefit from GZIP compression in S3
- Use columnar formats (Parquet) when possible for better compression

### Query Result Caching
- Athena caches query results for 24 hours
- Reuse cached results when possible to avoid re-scanning data
- Use consistent query patterns to maximize cache hits

### Workgroup Limits
- Configure query timeout limits in workgroup settings
- Set data scanned limits to prevent runaway costs
- Use query result lifecycle policies to manage storage costs

## Usage Instructions

1. Ensure your Athena workgroup is configured with proper cost controls
2. Replace `{database_name}` with your actual Glue database name
3. Replace `{table_name}` with your actual log table name
4. Adjust date ranges in partition filters based on your analysis needs
5. Monitor query costs using CloudWatch metrics

## Table Schema Reference

The queries assume the following log event schema:
```sql
CREATE EXTERNAL TABLE streaming_logs (
  timestamp string,
  service string,
  category string,
  level string,
  message string,
  metadata struct<
    request_id: string,
    user_id: string,
    session_id: string,
    ip_address: string,
    user_agent: string
  >,
  metrics struct<
    latency_ms: bigint,
    memory_usage_mb: bigint,
    cpu_usage_percent: double
  >
)
PARTITIONED BY (
  year string,
  month string,
  day string,
  hour string
)
STORED AS PARQUET
LOCATION 's3://streaming-logs-dev-{account-id}/'
```