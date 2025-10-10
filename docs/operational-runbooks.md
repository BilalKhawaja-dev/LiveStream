# Operational Runbooks
## Centralized Logging Infrastructure

### Table of Contents
1. [Daily Operations](#daily-operations)
2. [Monitoring and Alerting](#monitoring-and-alerting)
3. [Incident Response](#incident-response)
4. [Backup and Recovery](#backup-and-recovery)
5. [Cost Management](#cost-management)
6. [Maintenance Procedures](#maintenance-procedures)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Emergency Procedures](#emergency-procedures)

---

## Daily Operations

### Morning Health Check (5 minutes)

**Frequency:** Daily at 9:00 AM  
**Owner:** Operations Team  
**Duration:** ~5 minutes

#### Checklist:
- [ ] Check CloudWatch Dashboard for overnight alerts
- [ ] Verify log ingestion rates are within normal ranges
- [ ] Check S3 storage growth trends
- [ ] Review cost alerts and budget status
- [ ] Verify backup completion status

#### Commands:
```bash
# Quick health check
make check-health ENV=prod

# Check recent alerts
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --region eu-west-2 \
  --query 'MetricAlarms[?StateUpdatedTimestamp>=`2024-10-10T00:00:00Z`]'

# Check log ingestion (last 24h)
aws logs describe-log-groups \
  --log-group-name-prefix /aws/streaming \
  --region eu-west-2
```

#### Expected Results:
- All services showing green status
- Log ingestion rate: 100-1000 events/minute
- No critical alarms
- Daily costs within budget

#### Escalation:
If any critical issues found, follow [Incident Response](#incident-response) procedures.

---

### Weekly Operations Review (30 minutes)

**Frequency:** Every Monday at 10:00 AM  
**Owner:** Operations Team  
**Duration:** ~30 minutes

#### Checklist:
- [ ] Review weekly cost trends and optimization opportunities
- [ ] Check backup success rates and retention compliance
- [ ] Review security scan results
- [ ] Analyze query performance trends
- [ ] Update capacity planning projections

#### Commands:
```bash
# Weekly cost analysis
aws ce get-cost-and-usage \
  --time-period Start=2024-10-03,End=2024-10-10 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Backup status check
./tests/backup_recovery_test.sh --environment prod

# Security scan
make security
```

---

## Monitoring and Alerting

### Key Metrics to Monitor

#### Log Pipeline Health
- **CloudWatch Logs Ingestion Rate**
  - Metric: `IncomingLogEvents`
  - Threshold: < 50 events/minute (warning), < 10 events/minute (critical)
  - Action: Check service health, verify subscription filters

- **Kinesis Firehose Delivery Success Rate**
  - Metric: `DeliveryToS3.Success`
  - Threshold: < 95% (warning), < 90% (critical)
  - Action: Check S3 permissions, verify delivery stream configuration

- **S3 Storage Growth Rate**
  - Metric: `BucketSizeBytes`
  - Threshold: > 20% daily growth (warning)
  - Action: Review log volume, check lifecycle policies

#### Database Health
- **Aurora Connection Count**
  - Metric: `DatabaseConnections`
  - Threshold: > 80% of max (warning), > 95% of max (critical)
  - Action: Check application connection pooling, scale if needed

- **DynamoDB Throttling**
  - Metric: `ThrottledRequests`
  - Threshold: > 0 (warning)
  - Action: Review capacity settings, check access patterns

#### Cost Monitoring
- **Daily Spend**
  - Metric: Custom billing metric
  - Threshold: > 120% of budget (warning), > 150% of budget (critical)
  - Action: Review resource usage, implement cost controls

### Alert Response Procedures

#### High Priority Alerts (P1)
**Response Time:** 15 minutes  
**Examples:** Service outage, data loss, security breach

1. **Immediate Actions:**
   - Acknowledge alert in monitoring system
   - Join incident bridge/channel
   - Assess impact and scope
   - Implement immediate mitigation if available

2. **Investigation:**
   - Check service status dashboard
   - Review recent deployments
   - Analyze logs and metrics
   - Identify root cause

3. **Resolution:**
   - Apply fix or rollback
   - Verify service restoration
   - Update stakeholders
   - Schedule post-incident review

#### Medium Priority Alerts (P2)
**Response Time:** 1 hour  
**Examples:** Performance degradation, capacity warnings

1. **Assessment:**
   - Review alert details and trends
   - Check related metrics
   - Determine if immediate action needed

2. **Action:**
   - Implement temporary mitigation if needed
   - Schedule permanent fix
   - Monitor for escalation

#### Low Priority Alerts (P3)
**Response Time:** Next business day  
**Examples:** Cost warnings, maintenance reminders

1. **Review:**
   - Analyze trend data
   - Plan optimization actions
   - Schedule maintenance windows

---

## Incident Response

### Incident Classification

#### Severity 1 (Critical)
- Complete service outage
- Data loss or corruption
- Security breach
- **Response Time:** 15 minutes
- **Communication:** Immediate stakeholder notification

#### Severity 2 (High)
- Partial service degradation
- Performance issues affecting users
- Failed backups
- **Response Time:** 1 hour
- **Communication:** Hourly updates

#### Severity 3 (Medium)
- Minor performance issues
- Non-critical component failures
- **Response Time:** 4 hours
- **Communication:** Daily updates

#### Severity 4 (Low)
- Cosmetic issues
- Documentation updates needed
- **Response Time:** Next business day
- **Communication:** Weekly updates

### Incident Response Playbooks

#### Log Pipeline Failure

**Symptoms:**
- No logs appearing in S3
- Kinesis Firehose delivery failures
- CloudWatch subscription filter errors

**Investigation Steps:**
1. Check CloudWatch Logs subscription filters:
```bash
aws logs describe-subscription-filters \
  --log-group-name /aws/streaming/medialive \
  --region eu-west-2
```

2. Verify Kinesis Firehose stream status:
```bash
aws firehose describe-delivery-stream \
  --delivery-stream-name streaming-logs-logs-prod \
  --region eu-west-2
```

3. Check S3 bucket permissions and policies:
```bash
aws s3api get-bucket-policy \
  --bucket streaming-logs-logs-prod \
  --region eu-west-2
```

**Resolution Steps:**
1. Restart failed Firehose delivery stream
2. Recreate subscription filters if corrupted
3. Verify IAM permissions
4. Test with sample log events

#### Database Connection Issues

**Symptoms:**
- High connection count alerts
- Application timeout errors
- Slow query performance

**Investigation Steps:**
1. Check Aurora cluster status:
```bash
aws rds describe-db-clusters \
  --db-cluster-identifier streaming-logs-aurora-prod \
  --region eu-west-2
```

2. Review connection metrics:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=streaming-logs-aurora-prod \
  --start-time 2024-10-10T00:00:00Z \
  --end-time 2024-10-10T23:59:59Z \
  --period 300 \
  --statistics Average,Maximum
```

**Resolution Steps:**
1. Scale Aurora cluster if needed
2. Review application connection pooling
3. Kill long-running queries if necessary
4. Restart application services if required

#### Cost Spike Investigation

**Symptoms:**
- Unexpected billing alerts
- Budget threshold exceeded
- Unusual resource usage patterns

**Investigation Steps:**
1. Analyze cost breakdown by service:
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-10-09,End=2024-10-10 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

2. Check S3 storage usage:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=streaming-logs-logs-prod Name=StorageType,Value=StandardStorage \
  --start-time 2024-10-09T00:00:00Z \
  --end-time 2024-10-10T00:00:00Z \
  --period 86400 \
  --statistics Average
```

**Resolution Steps:**
1. Identify cost drivers
2. Implement immediate cost controls
3. Review and adjust lifecycle policies
4. Scale down non-essential resources

---

## Backup and Recovery

### Backup Verification Procedures

#### Daily Backup Checks (Automated)
```bash
# Run automated backup validation
./tests/backup_recovery_test.sh --environment prod

# Check Aurora automated backups
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier streaming-logs-aurora-prod \
  --snapshot-type automated \
  --region eu-west-2

# Verify DynamoDB point-in-time recovery
aws dynamodb describe-continuous-backups \
  --table-name streaming-logs-metadata-prod \
  --region eu-west-2
```

#### Weekly Backup Testing
1. **Aurora Backup Test:**
```bash
# Create test snapshot
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier streaming-logs-aurora-prod \
  --db-cluster-snapshot-identifier test-restore-$(date +%Y%m%d) \
  --region eu-west-2

# Verify snapshot creation
aws rds describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier test-restore-$(date +%Y%m%d) \
  --region eu-west-2
```

2. **DynamoDB Backup Test:**
```bash
# Create manual backup
aws dynamodb create-backup \
  --table-name streaming-logs-metadata-prod \
  --backup-name test-backup-$(date +%Y%m%d) \
  --region eu-west-2
```

### Recovery Procedures

#### Aurora Point-in-Time Recovery

**Use Case:** Recover from data corruption or accidental deletion

**Steps:**
1. **Identify Recovery Point:**
```bash
# Get available recovery window
aws rds describe-db-clusters \
  --db-cluster-identifier streaming-logs-aurora-prod \
  --region eu-west-2 \
  --query 'DBClusters[0].[EarliestRestorableTime,LatestRestorableTime]'
```

2. **Create Recovery Cluster:**
```bash
# Restore to specific point in time
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier streaming-logs-aurora-prod \
  --db-cluster-identifier streaming-logs-aurora-recovery \
  --restore-to-time 2024-10-10T12:00:00.000Z \
  --region eu-west-2
```

3. **Verify Recovery:**
```bash
# Check cluster status
aws rds describe-db-clusters \
  --db-cluster-identifier streaming-logs-aurora-recovery \
  --region eu-west-2
```

4. **Switch Traffic:**
   - Update application configuration
   - Test connectivity
   - Monitor for issues

#### DynamoDB Point-in-Time Recovery

**Use Case:** Recover from data corruption

**Steps:**
1. **Create Recovery Table:**
```bash
# Restore to specific point in time
aws dynamodb restore-table-to-point-in-time \
  --source-table-name streaming-logs-metadata-prod \
  --target-table-name streaming-logs-metadata-recovery \
  --restore-date-time 2024-10-10T12:00:00.000Z \
  --region eu-west-2
```

2. **Verify Data:**
```bash
# Check table status
aws dynamodb describe-table \
  --table-name streaming-logs-metadata-recovery \
  --region eu-west-2
```

3. **Switch Applications:**
   - Update table references
   - Test functionality
   - Monitor performance

#### S3 Data Recovery

**Use Case:** Recover accidentally deleted objects

**Steps:**
1. **Check Versioning:**
```bash
# List object versions
aws s3api list-object-versions \
  --bucket streaming-logs-logs-prod \
  --prefix "2024/10/10/" \
  --region eu-west-2
```

2. **Restore Previous Version:**
```bash
# Copy previous version
aws s3api copy-object \
  --copy-source streaming-logs-logs-prod/path/to/object?versionId=VERSION_ID \
  --bucket streaming-logs-logs-prod \
  --key path/to/object \
  --region eu-west-2
```

---

## Cost Management

### Daily Cost Monitoring

#### Cost Tracking Commands
```bash
# Get yesterday's costs by service
aws ce get-cost-and-usage \
  --time-period Start=$(date -d yesterday +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Check current month spend
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost
```

#### Cost Optimization Actions

**S3 Storage Optimization:**
```bash
# Check storage class distribution
aws s3api list-objects-v2 \
  --bucket streaming-logs-logs-prod \
  --query 'Contents[?StorageClass!=`STANDARD`]' \
  --output table

# Force lifecycle transition for old objects
aws s3api put-object \
  --bucket streaming-logs-logs-prod \
  --key lifecycle-test \
  --storage-class STANDARD_IA
```

**Athena Query Optimization:**
```bash
# Check query costs
aws athena list-query-executions \
  --work-group streaming-logs-prod \
  --region eu-west-2

# Get query statistics
aws athena get-query-execution \
  --query-execution-id EXECUTION_ID \
  --region eu-west-2 \
  --query 'QueryExecution.Statistics'
```

### Weekly Cost Review

#### Cost Analysis Report
1. **Generate Cost Report:**
```bash
# Weekly cost breakdown
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output table
```

2. **Identify Cost Drivers:**
   - S3 storage growth rate
   - Athena query frequency and data scanned
   - Aurora compute usage
   - Data transfer costs

3. **Optimization Recommendations:**
   - Adjust S3 lifecycle policies
   - Optimize Athena queries
   - Right-size Aurora instances
   - Review data retention policies

---

## Maintenance Procedures

### Monthly Maintenance Tasks

#### Security Updates
**Schedule:** First Saturday of each month, 2:00 AM UTC

1. **Update Terraform Providers:**
```bash
cd terraform_live_stream
terraform init -upgrade
terraform plan -var-file=environments/prod/terraform.tfvars
```

2. **Security Scan:**
```bash
make security
tfsec . --format json --out security-report.json
```

3. **Update Dependencies:**
```bash
# Update pre-commit hooks
pre-commit autoupdate

# Update CI/CD pipeline dependencies
# Review and update GitHub Actions versions
```

#### Performance Optimization
**Schedule:** Second Saturday of each month, 2:00 AM UTC

1. **Aurora Performance Review:**
```bash
# Check slow query log
aws rds describe-db-log-files \
  --db-instance-identifier streaming-logs-aurora-prod-instance-1 \
  --region eu-west-2

# Download and analyze slow query log
aws rds download-db-log-file-portion \
  --db-instance-identifier streaming-logs-aurora-prod-instance-1 \
  --log-file-name slowquery/mysql-slowquery.log \
  --region eu-west-2
```

2. **S3 Performance Optimization:**
```bash
# Check request metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name AllRequests \
  --dimensions Name=BucketName,Value=streaming-logs-logs-prod \
  --start-time $(date -d '30 days ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 \
  --statistics Sum
```

3. **Athena Query Optimization:**
```bash
# Review most expensive queries
aws athena list-query-executions \
  --work-group streaming-logs-prod \
  --region eu-west-2 \
  --max-results 50

# Analyze query performance
for execution_id in $(aws athena list-query-executions --work-group streaming-logs-prod --region eu-west-2 --query 'QueryExecutionIds[0:10]' --output text); do
  aws athena get-query-execution --query-execution-id $execution_id --region eu-west-2 --query 'QueryExecution.Statistics'
done
```

### Quarterly Maintenance Tasks

#### Capacity Planning Review
**Schedule:** Last Saturday of quarter, 2:00 AM UTC

1. **Storage Growth Analysis:**
```bash
# 90-day storage trend
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=streaming-logs-logs-prod Name=StorageType,Value=StandardStorage \
  --start-time $(date -d '90 days ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 \
  --statistics Average
```

2. **Database Capacity Review:**
```bash
# Aurora CPU and memory trends
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=streaming-logs-aurora-prod \
  --start-time $(date -d '90 days ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 \
  --statistics Average,Maximum
```

3. **Cost Projection:**
```bash
# Quarterly cost analysis
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '90 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue: High Log Ingestion Latency

**Symptoms:**
- Logs appearing in S3 with significant delay
- CloudWatch metrics showing processing lag

**Diagnosis:**
```bash
# Check Firehose buffer settings
aws firehose describe-delivery-stream \
  --delivery-stream-name streaming-logs-logs-prod \
  --region eu-west-2 \
  --query 'DeliveryStreamDescription.Destinations[0].S3DestinationDescription.BufferingHints'

# Check error records
aws firehose describe-delivery-stream \
  --delivery-stream-name streaming-logs-logs-prod \
  --region eu-west-2 \
  --query 'DeliveryStreamDescription.Destinations[0].S3DestinationDescription.ProcessingConfiguration'
```

**Solutions:**
1. Reduce buffer size for faster delivery
2. Check S3 permissions and policies
3. Verify network connectivity
4. Scale Firehose if needed

#### Issue: Athena Query Performance Problems

**Symptoms:**
- Slow query execution
- High data scan costs
- Query timeouts

**Diagnosis:**
```bash
# Check query execution details
aws athena get-query-execution \
  --query-execution-id EXECUTION_ID \
  --region eu-west-2

# Review table partitioning
aws glue get-partitions \
  --database-name streaming-logs-prod \
  --table-name logs \
  --region eu-west-2
```

**Solutions:**
1. Add partition projection
2. Use columnar formats (Parquet)
3. Optimize query WHERE clauses
4. Use LIMIT clauses for testing

#### Issue: Aurora Connection Pool Exhaustion

**Symptoms:**
- Connection timeout errors
- High connection count metrics
- Application errors

**Diagnosis:**
```bash
# Check current connections
aws rds describe-db-clusters \
  --db-cluster-identifier streaming-logs-aurora-prod \
  --region eu-west-2 \
  --query 'DBClusters[0].DatabaseName'

# Monitor connection metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=streaming-logs-aurora-prod \
  --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average,Maximum
```

**Solutions:**
1. Increase max_connections parameter
2. Optimize application connection pooling
3. Scale Aurora cluster
4. Kill long-running queries

#### Issue: S3 Lifecycle Policy Not Working

**Symptoms:**
- Objects not transitioning to IA/Glacier
- Unexpected storage costs
- Objects not being deleted

**Diagnosis:**
```bash
# Check lifecycle configuration
aws s3api get-bucket-lifecycle-configuration \
  --bucket streaming-logs-logs-prod \
  --region eu-west-2

# Check object ages and storage classes
aws s3api list-objects-v2 \
  --bucket streaming-logs-logs-prod \
  --prefix "2024/09/" \
  --query 'Contents[?StorageClass!=`STANDARD`]'
```

**Solutions:**
1. Verify lifecycle rule syntax
2. Check object prefixes and filters
3. Ensure minimum object size requirements
4. Wait for policy application (can take 24-48 hours)

---

## Emergency Procedures

### Complete Service Outage

**Immediate Actions (0-15 minutes):**
1. **Assess Impact:**
   - Check service status dashboard
   - Identify affected components
   - Estimate user impact

2. **Communicate:**
   - Notify stakeholders
   - Update status page
   - Join incident bridge

3. **Initial Mitigation:**
   - Check for recent deployments
   - Verify AWS service status
   - Implement immediate fixes if available

**Investigation Phase (15-60 minutes):**
1. **Root Cause Analysis:**
```bash
# Check recent CloudTrail events
aws logs filter-log-events \
  --log-group-name CloudTrail/streaming-logs \
  --start-time $(date -d '2 hours ago' +%s)000 \
  --region eu-west-2

# Review recent deployments
git log --oneline --since="2 hours ago"

# Check infrastructure status
make check-health ENV=prod
```

2. **Service Recovery:**
   - Apply fixes or rollback changes
   - Restart failed services
   - Verify service restoration

**Recovery Phase (1-4 hours):**
1. **Full Service Verification:**
```bash
# Run comprehensive tests
./tests/e2e_log_pipeline_test.sh --environment prod
./tests/backup_recovery_test.sh --environment prod
```

2. **Post-Incident:**
   - Document timeline and actions
   - Schedule post-mortem meeting
   - Implement preventive measures

### Data Loss Emergency

**Immediate Actions:**
1. **Stop Further Data Loss:**
   - Disable automatic cleanup processes
   - Prevent additional writes if necessary
   - Preserve current state

2. **Assess Scope:**
```bash
# Check backup availability
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier streaming-logs-aurora-prod \
  --region eu-west-2

# Verify S3 object versions
aws s3api list-object-versions \
  --bucket streaming-logs-logs-prod \
  --region eu-west-2
```

3. **Recovery Actions:**
   - Follow backup recovery procedures
   - Restore from most recent valid backup
   - Verify data integrity

### Security Incident

**Immediate Actions:**
1. **Contain Threat:**
   - Disable compromised accounts
   - Block suspicious IP addresses
   - Isolate affected resources

2. **Assess Impact:**
```bash
# Check CloudTrail for suspicious activity
aws logs filter-log-events \
  --log-group-name CloudTrail/streaming-logs \
  --filter-pattern "{ $.errorCode = \"*UnauthorizedOperation\" || $.errorCode = \"AccessDenied*\" }" \
  --start-time $(date -d '24 hours ago' +%s)000 \
  --region eu-west-2
```

3. **Notify Authorities:**
   - Contact security team
   - Notify compliance officer
   - Document all actions

---

## Contact Information

### Escalation Matrix

| Severity | Primary Contact | Secondary Contact | Manager |
|----------|----------------|-------------------|---------|
| P1 (Critical) | On-call Engineer | Backup On-call | Engineering Manager |
| P2 (High) | Team Lead | Senior Engineer | Engineering Manager |
| P3 (Medium) | Assigned Engineer | Team Lead | - |
| P4 (Low) | Assigned Engineer | - | - |

### Key Contacts

- **Operations Team:** ops-team@company.com
- **Security Team:** security@company.com
- **Engineering Manager:** eng-manager@company.com
- **On-call Phone:** +1-555-0123 (24/7)

### External Contacts

- **AWS Support:** Enterprise Support Case
- **Vendor Support:** As needed for third-party tools

---

## Appendix

### Useful Commands Reference

```bash
# Health checks
make check-health ENV=prod
./tests/integration_test.sh --environment prod

# Cost analysis
aws ce get-cost-and-usage --time-period Start=2024-10-01,End=2024-10-10 --granularity DAILY --metrics BlendedCost

# Backup verification
./tests/backup_recovery_test.sh --environment prod

# Security scan
make security

# Performance monitoring
aws cloudwatch get-metric-statistics --namespace AWS/S3 --metric-name BucketSizeBytes

# Log analysis
aws logs filter-log-events --log-group-name /aws/streaming/medialive --start-time $(date -d '1 hour ago' +%s)000
```

### Emergency Contact Card

**Print and keep accessible:**

```
EMERGENCY CONTACTS
==================
On-call: +1-555-0123
Ops Team: ops-team@company.com
Security: security@company.com

QUICK COMMANDS
==============
Health Check: make check-health ENV=prod
Rollback: ./scripts/rollback.sh --environment prod
Status: aws rds describe-db-clusters --region eu-west-2
```