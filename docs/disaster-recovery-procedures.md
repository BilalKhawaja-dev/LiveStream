# Disaster Recovery Procedures
## Centralized Logging Infrastructure

### Table of Contents
1. [Overview](#overview)
2. [Recovery Time Objectives](#recovery-time-objectives)
3. [Disaster Scenarios](#disaster-scenarios)
4. [Recovery Procedures](#recovery-procedures)
5. [Testing and Validation](#testing-and-validation)
6. [Communication Plan](#communication-plan)

---

## Overview

This document outlines disaster recovery procedures for the centralized logging infrastructure. The procedures are designed to restore service functionality within defined Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO).

### Key Components
- **Aurora Serverless v2 Database**
- **DynamoDB Tables**
- **S3 Storage Buckets**
- **CloudWatch Logs**
- **Kinesis Firehose**
- **Athena Workgroups**
- **Glue Data Catalog**

### Backup Strategy
- **Aurora:** Automated backups with 7-day retention, point-in-time recovery
- **DynamoDB:** Point-in-time recovery enabled, manual backups as needed
- **S3:** Versioning enabled, lifecycle policies for cost optimization
- **Infrastructure:** Terraform state stored in S3 with versioning

---

## Recovery Time Objectives

| Component | RTO (Production) | RTO (Development) | RPO |
|-----------|------------------|-------------------|-----|
| Aurora Database | 4 hours | 8 hours | 15 minutes |
| DynamoDB Tables | 2 hours | 4 hours | 1 minute |
| S3 Storage | 1 hour | 2 hours | 0 (versioned) |
| Log Pipeline | 2 hours | 4 hours | 5 minutes |
| Athena/Glue | 1 hour | 2 hours | 0 (metadata) |
| Full System | 6 hours | 12 hours | 15 minutes |

---

## Disaster Scenarios

### Scenario 1: Single AZ Failure

**Impact:** Partial service degradation  
**Probability:** Medium  
**Detection:** CloudWatch alarms, health checks

**Immediate Actions:**
1. Verify multi-AZ deployment is functioning
2. Check Aurora cluster status
3. Monitor application performance
4. No immediate action required if properly configured

**Recovery Steps:**
- Aurora automatically fails over to secondary AZ
- Monitor for complete recovery
- Verify all services are operational

### Scenario 2: Region-Wide Outage

**Impact:** Complete service outage  
**Probability:** Low  
**Detection:** AWS Service Health Dashboard, multiple service failures

**Immediate Actions:**
1. Activate disaster recovery team
2. Assess scope of outage
3. Communicate with stakeholders
4. Prepare for cross-region recovery

**Recovery Steps:**
1. **Infrastructure Recovery (2-4 hours):**
```bash
# Deploy infrastructure to backup region
cd terraform_live_stream
export AWS_DEFAULT_REGION=us-east-1

# Update backend configuration for DR region
terraform init -reconfigure \
  -backend-config="bucket=streaming-logs-terraform-state-dr" \
  -backend-config="region=us-east-1"

# Deploy infrastructure
terraform workspace select prod-dr || terraform workspace new prod-dr
terraform plan -var-file=environments/prod/terraform.tfvars -var="region=us-east-1"
terraform apply -var-file=environments/prod/terraform.tfvars -var="region=us-east-1"
```

2. **Database Recovery (1-2 hours):**
```bash
# Restore Aurora from cross-region backup
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier streaming-logs-aurora-prod-dr \
  --snapshot-identifier arn:aws:rds:us-east-1:ACCOUNT:cluster-snapshot:streaming-logs-aurora-prod-backup \
  --engine aurora-mysql \
  --region us-east-1

# Restore DynamoDB from backup
aws dynamodb restore-table-from-backup \
  --target-table-name streaming-logs-metadata-prod-dr \
  --backup-arn arn:aws:dynamodb:us-east-1:ACCOUNT:table/streaming-logs-metadata-prod/backup/BACKUP-ID \
  --region us-east-1
```

3. **Data Recovery (30 minutes - 2 hours):**
```bash
# Sync S3 data from backup region
aws s3 sync s3://streaming-logs-logs-prod-backup s3://streaming-logs-logs-prod-dr --region us-east-1

# Recreate Glue catalog
aws glue create-database --database-input Name=streaming-logs-prod-dr --region us-east-1
```

### Scenario 3: Data Corruption

**Impact:** Data integrity issues  
**Probability:** Medium  
**Detection:** Data validation checks, user reports

**Immediate Actions:**
1. Stop all write operations
2. Identify corruption scope
3. Preserve current state
4. Activate incident response

**Recovery Steps:**
1. **Assess Corruption Scope:**
```bash
# Check Aurora data integrity
mysql -h aurora-endpoint -u admin -p -e "CHECK TABLE logs;"

# Verify DynamoDB data
aws dynamodb scan --table-name streaming-logs-metadata-prod --select COUNT --region eu-west-2

# Check S3 object integrity
aws s3api head-object --bucket streaming-logs-logs-prod --key path/to/critical/file --region eu-west-2
```

2. **Point-in-Time Recovery:**
```bash
# Aurora point-in-time recovery
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier streaming-logs-aurora-prod \
  --db-cluster-identifier streaming-logs-aurora-recovery \
  --restore-to-time 2024-10-10T12:00:00.000Z \
  --region eu-west-2

# DynamoDB point-in-time recovery
aws dynamodb restore-table-to-point-in-time \
  --source-table-name streaming-logs-metadata-prod \
  --target-table-name streaming-logs-metadata-recovery \
  --restore-date-time 2024-10-10T12:00:00.000Z \
  --region eu-west-2
```

### Scenario 4: Security Breach

**Impact:** Potential data exposure, service compromise  
**Probability:** Low-Medium  
**Detection:** Security monitoring, anomaly detection

**Immediate Actions:**
1. Isolate affected systems
2. Preserve forensic evidence
3. Assess breach scope
4. Notify security team and compliance

**Recovery Steps:**
1. **Containment:**
```bash
# Disable compromised IAM users/roles
aws iam attach-user-policy --user-name compromised-user --policy-arn arn:aws:iam::aws:policy/AWSDenyAll

# Block suspicious IP addresses
aws ec2 create-security-group-rule \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 443 \
  --source-group SUSPICIOUS-IP/32 \
  --rule-action deny
```

2. **System Rebuild:**
```bash
# Rebuild infrastructure from clean state
terraform destroy -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars

# Restore data from pre-breach backups
# Follow data recovery procedures with verified clean backups
```

---

## Recovery Procedures

### Aurora Database Recovery

#### Automated Failover (Multi-AZ)
**RTO:** 2-5 minutes  
**RPO:** 0-1 minute

Aurora automatically handles failover between AZs. No manual intervention required.

**Monitoring:**
```bash
# Check cluster status
aws rds describe-db-clusters \
  --db-cluster-identifier streaming-logs-aurora-prod \
  --region eu-west-2 \
  --query 'DBClusters[0].[Status,MultiAZ,AvailabilityZones]'

# Monitor failover events
aws rds describe-events \
  --source-identifier streaming-logs-aurora-prod \
  --source-type db-cluster \
  --region eu-west-2
```

#### Point-in-Time Recovery
**RTO:** 1-2 hours  
**RPO:** 5 minutes

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
# Restore to specific time
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier streaming-logs-aurora-prod \
  --db-cluster-identifier streaming-logs-aurora-recovery \
  --restore-to-time 2024-10-10T12:00:00.000Z \
  --vpc-security-group-ids sg-12345678 \
  --db-subnet-group-name streaming-logs-subnet-group \
  --region eu-west-2
```

3. **Create Cluster Instances:**
```bash
# Create primary instance
aws rds create-db-instance \
  --db-instance-identifier streaming-logs-aurora-recovery-1 \
  --db-cluster-identifier streaming-logs-aurora-recovery \
  --db-instance-class db.serverless \
  --engine aurora-mysql \
  --region eu-west-2
```

4. **Verify Recovery:**
```bash
# Check cluster status
aws rds describe-db-clusters \
  --db-cluster-identifier streaming-logs-aurora-recovery \
  --region eu-west-2

# Test connectivity
mysql -h recovery-cluster-endpoint -u admin -p -e "SELECT COUNT(*) FROM logs;"
```

5. **Switch Applications:**
   - Update application configuration
   - Test functionality
   - Monitor performance
   - Update DNS if needed

### DynamoDB Recovery

#### Point-in-Time Recovery
**RTO:** 30 minutes - 2 hours  
**RPO:** 1 minute

**Steps:**
1. **Create Recovery Table:**
```bash
# Restore to specific time
aws dynamodb restore-table-to-point-in-time \
  --source-table-name streaming-logs-metadata-prod \
  --target-table-name streaming-logs-metadata-recovery \
  --restore-date-time 2024-10-10T12:00:00.000Z \
  --region eu-west-2
```

2. **Monitor Restoration:**
```bash
# Check table status
aws dynamodb describe-table \
  --table-name streaming-logs-metadata-recovery \
  --region eu-west-2 \
  --query 'Table.[TableStatus,ItemCount]'
```

3. **Verify Data:**
```bash
# Sample data verification
aws dynamodb scan \
  --table-name streaming-logs-metadata-recovery \
  --select COUNT \
  --region eu-west-2

# Compare with expected counts
aws dynamodb scan \
  --table-name streaming-logs-metadata-prod \
  --select COUNT \
  --region eu-west-2
```

4. **Switch Applications:**
   - Update table references in applications
   - Test CRUD operations
   - Monitor performance metrics

#### Backup Restoration
**RTO:** 1-4 hours  
**RPO:** Varies by backup age

**Steps:**
1. **List Available Backups:**
```bash
aws dynamodb list-backups \
  --table-name streaming-logs-metadata-prod \
  --region eu-west-2
```

2. **Restore from Backup:**
```bash
aws dynamodb restore-table-from-backup \
  --target-table-name streaming-logs-metadata-recovery \
  --backup-arn arn:aws:dynamodb:eu-west-2:ACCOUNT:table/streaming-logs-metadata-prod/backup/BACKUP-ID \
  --region eu-west-2
```

### S3 Data Recovery

#### Object Version Recovery
**RTO:** 15 minutes - 1 hour  
**RPO:** 0 (versioned)

**Steps:**
1. **List Object Versions:**
```bash
aws s3api list-object-versions \
  --bucket streaming-logs-logs-prod \
  --prefix "2024/10/10/" \
  --region eu-west-2
```

2. **Restore Previous Version:**
```bash
# Copy previous version as current
aws s3api copy-object \
  --copy-source "streaming-logs-logs-prod/path/to/object?versionId=VERSION_ID" \
  --bucket streaming-logs-logs-prod \
  --key "path/to/object" \
  --region eu-west-2
```

3. **Bulk Recovery:**
```bash
# Script for bulk recovery
#!/bin/bash
BUCKET="streaming-logs-logs-prod"
PREFIX="2024/10/10/"
CUTOFF_TIME="2024-10-10T12:00:00Z"

aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix "$PREFIX" \
  --query "Versions[?LastModified<'$CUTOFF_TIME'].[Key,VersionId]" \
  --output text | \
while read key version_id; do
  aws s3api copy-object \
    --copy-source "$BUCKET/$key?versionId=$version_id" \
    --bucket "$BUCKET" \
    --key "$key" \
    --region eu-west-2
done
```

#### Cross-Region Recovery
**RTO:** 2-8 hours  
**RPO:** Varies by replication lag

**Steps:**
1. **Sync from Backup Region:**
```bash
# Full sync from backup region
aws s3 sync s3://streaming-logs-logs-prod-backup s3://streaming-logs-logs-prod-recovery \
  --region us-east-1 \
  --source-region us-east-1

# Incremental sync with delete protection
aws s3 sync s3://streaming-logs-logs-prod-backup s3://streaming-logs-logs-prod-recovery \
  --region us-east-1 \
  --source-region us-east-1 \
  --exclude "*.tmp" \
  --include "*"
```

### Infrastructure Recovery

#### Complete Infrastructure Rebuild
**RTO:** 2-6 hours  
**RPO:** 0 (Infrastructure as Code)

**Steps:**
1. **Prepare Environment:**
```bash
cd terraform_live_stream
export AWS_DEFAULT_REGION=eu-west-2

# Ensure latest code
git pull origin main
```

2. **Initialize Terraform:**
```bash
# Initialize with existing state
terraform init

# Select production workspace
terraform workspace select prod
```

3. **Plan and Apply:**
```bash
# Generate plan
terraform plan -var-file=environments/prod/terraform.tfvars -out=recovery.tfplan

# Review plan carefully
terraform show recovery.tfplan

# Apply infrastructure
terraform apply recovery.tfplan
```

4. **Verify Deployment:**
```bash
# Run integration tests
./tests/integration_test.sh --environment prod

# Check service health
make check-health ENV=prod
```

---

## Testing and Validation

### Monthly DR Testing

**Schedule:** Third Saturday of each month, 2:00 AM UTC

#### Test Scenarios
1. **Aurora Failover Test:**
```bash
# Simulate failover
aws rds failover-db-cluster \
  --db-cluster-identifier streaming-logs-aurora-dev \
  --target-db-instance-identifier streaming-logs-aurora-dev-2 \
  --region eu-west-2

# Monitor failover time
start_time=$(date +%s)
while true; do
  status=$(aws rds describe-db-clusters \
    --db-cluster-identifier streaming-logs-aurora-dev \
    --region eu-west-2 \
    --query 'DBClusters[0].Status' \
    --output text)
  
  if [ "$status" = "available" ]; then
    end_time=$(date +%s)
    echo "Failover completed in $((end_time - start_time)) seconds"
    break
  fi
  
  sleep 5
done
```

2. **DynamoDB Recovery Test:**
```bash
# Create test backup
aws dynamodb create-backup \
  --table-name streaming-logs-metadata-dev \
  --backup-name dr-test-$(date +%Y%m%d) \
  --region eu-west-2

# Test point-in-time recovery
aws dynamodb restore-table-to-point-in-time \
  --source-table-name streaming-logs-metadata-dev \
  --target-table-name streaming-logs-metadata-dr-test \
  --restore-date-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S.000Z) \
  --region eu-west-2
```

3. **S3 Recovery Test:**
```bash
# Test object version recovery
test_key="dr-test/test-object-$(date +%Y%m%d).txt"
echo "Test data" | aws s3 cp - s3://streaming-logs-logs-dev/$test_key --region eu-west-2

# Create new version
echo "Modified data" | aws s3 cp - s3://streaming-logs-logs-dev/$test_key --region eu-west-2

# Recover previous version
version_id=$(aws s3api list-object-versions \
  --bucket streaming-logs-logs-dev \
  --prefix "$test_key" \
  --query 'Versions[1].VersionId' \
  --output text \
  --region eu-west-2)

aws s3api copy-object \
  --copy-source "streaming-logs-logs-dev/$test_key?versionId=$version_id" \
  --bucket streaming-logs-logs-dev \
  --key "$test_key" \
  --region eu-west-2
```

### Quarterly Full DR Test

**Schedule:** Last Saturday of quarter, 6:00 AM UTC

#### Complete System Recovery Test
1. **Simulate Regional Outage:**
   - Deploy infrastructure to backup region
   - Restore all data from backups
   - Test application functionality
   - Measure RTO/RPO compliance

2. **Validation Checklist:**
   - [ ] Infrastructure deployed successfully
   - [ ] Aurora cluster operational
   - [ ] DynamoDB tables accessible
   - [ ] S3 data available
   - [ ] Log pipeline functional
   - [ ] Athena queries working
   - [ ] Monitoring and alerting active
   - [ ] Applications connecting successfully

3. **Performance Validation:**
```bash
# Run comprehensive tests
./tests/e2e_log_pipeline_test.sh --environment dr-test
./tests/backup_recovery_test.sh --environment dr-test

# Load testing
# Generate test load and measure performance
```

---

## Communication Plan

### Stakeholder Matrix

| Role | Contact Method | Notification Timing |
|------|---------------|-------------------|
| Engineering Manager | Phone, Email, Slack | Immediate (P1), 1 hour (P2) |
| Operations Team | Slack, PagerDuty | Immediate |
| Security Team | Email, Phone | Immediate (security incidents) |
| Business Stakeholders | Email | 2 hours (P1), 4 hours (P2) |
| Customers | Status Page | 1 hour (customer impact) |

### Communication Templates

#### Initial Incident Notification
```
SUBJECT: [P1 INCIDENT] Centralized Logging Service Outage

We are currently experiencing an outage affecting the centralized logging service.

IMPACT: [Describe impact]
START TIME: [UTC timestamp]
ESTIMATED RESOLUTION: [Time estimate]
NEXT UPDATE: [Time for next update]

We are actively working to resolve this issue and will provide updates every 30 minutes.

Status Page: https://status.company.com
Incident Commander: [Name and contact]
```

#### Recovery Completion Notification
```
SUBJECT: [RESOLVED] Centralized Logging Service Restored

The centralized logging service has been fully restored.

RESOLUTION TIME: [UTC timestamp]
ROOT CAUSE: [Brief description]
IMPACT DURATION: [Total duration]

POST-INCIDENT REVIEW: Scheduled for [date/time]

Thank you for your patience during this incident.
```

### Escalation Procedures

#### Severity 1 (Complete Outage)
1. **0-15 minutes:** On-call engineer response
2. **15-30 minutes:** Engineering manager notification
3. **30-60 minutes:** Executive team notification
4. **1-2 hours:** Customer communication
5. **2+ hours:** External vendor engagement if needed

#### Communication Channels
- **Primary:** Slack #incidents channel
- **Secondary:** Email distribution lists
- **Emergency:** Phone tree activation
- **Customer:** Status page updates

---

## Recovery Validation Checklist

### Post-Recovery Verification

#### System Health Checks
- [ ] All AWS services operational
- [ ] Aurora cluster healthy and accessible
- [ ] DynamoDB tables responding normally
- [ ] S3 buckets accessible with correct permissions
- [ ] CloudWatch Logs ingesting properly
- [ ] Kinesis Firehose delivering to S3
- [ ] Athena queries executing successfully
- [ ] Glue catalog accessible

#### Data Integrity Checks
- [ ] Database record counts match expectations
- [ ] S3 object counts and sizes verified
- [ ] Log data continuity confirmed
- [ ] No data corruption detected
- [ ] Backup systems operational

#### Performance Validation
- [ ] Response times within normal ranges
- [ ] Throughput meeting requirements
- [ ] No error rate spikes
- [ ] Monitoring and alerting functional

#### Security Verification
- [ ] Access controls properly configured
- [ ] Encryption at rest and in transit verified
- [ ] IAM roles and policies correct
- [ ] Network security groups configured
- [ ] Audit logging enabled

### Documentation Updates

After each DR event:
1. Update recovery procedures based on lessons learned
2. Document any new issues encountered
3. Update RTO/RPO measurements
4. Revise communication templates if needed
5. Schedule post-incident review meeting

---

## Appendix

### Emergency Contact Information

**24/7 On-Call:** +1-555-0123  
**Incident Commander:** ops-lead@company.com  
**Engineering Manager:** eng-manager@company.com  
**Security Team:** security@company.com  

### Quick Reference Commands

```bash
# Health check
make check-health ENV=prod

# Aurora status
aws rds describe-db-clusters --region eu-west-2

# DynamoDB status
aws dynamodb list-tables --region eu-west-2

# S3 status
aws s3 ls --region eu-west-2

# Recent CloudTrail events
aws logs filter-log-events --log-group-name CloudTrail/streaming-logs --start-time $(date -d '1 hour ago' +%s)000

# Infrastructure deployment
terraform plan -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars
```

### Recovery Time Tracking

| Component | Target RTO | Actual RTO | Target RPO | Actual RPO | Last Tested |
|-----------|------------|------------|------------|------------|-------------|
| Aurora | 4 hours | - | 15 minutes | - | - |
| DynamoDB | 2 hours | - | 1 minute | - | - |
| S3 | 1 hour | - | 0 | - | - |
| Full System | 6 hours | - | 15 minutes | - | - |

*Update this table after each DR test or actual incident*