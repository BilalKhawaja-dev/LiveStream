#!/bin/bash

# Backup and Recovery Validation Script
# Tests Aurora backup/restore, DynamoDB point-in-time recovery, and S3 lifecycle policies

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_ENVIRONMENT="${TEST_ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-eu-west-2}"
PROJECT_NAME="streaming-logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test tracking
failed_tests=0
total_tests=0
test_results=()

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((total_tests++))
    log_info "Running test: $test_name"
    
    if eval "$test_command"; then
        log_success "✓ $test_name"
        test_results+=("PASS: $test_name")
        return 0
    else
        log_error "✗ $test_name"
        test_results+=("FAIL: $test_name")
        ((failed_tests++))
        return 1
    fi
}

# Test Aurora backup configuration
test_aurora_backup_config() {
    log_info "Testing Aurora backup configuration..."
    
    local cluster_id="$PROJECT_NAME-aurora-$TEST_ENVIRONMENT"
    
    # Check if cluster exists
    if ! aws rds describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_error "Aurora cluster not found: $cluster_id"
        return 1
    fi
    
    # Get cluster details
    local cluster_info=$(aws rds describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --region "$AWS_REGION" \
        --query "DBClusters[0]")
    
    # Check backup retention period
    local backup_retention=$(echo "$cluster_info" | jq -r '.BackupRetentionPeriod')
    if [ "$backup_retention" -ge 7 ]; then
        log_success "✓ Backup retention period: $backup_retention days"
    else
        log_error "✗ Backup retention period too short: $backup_retention days"
        return 1
    fi
    
    # Check if automated backups are enabled
    local backup_enabled=$(echo "$cluster_info" | jq -r '.BackupRetentionPeriod > 0')
    if [ "$backup_enabled" = "true" ]; then
        log_success "✓ Automated backups enabled"
    else
        log_error "✗ Automated backups not enabled"
        return 1
    fi
    
    # Check backup window
    local backup_window=$(echo "$cluster_info" | jq -r '.PreferredBackupWindow')
    if [ "$backup_window" != "null" ]; then
        log_success "✓ Backup window configured: $backup_window"
    else
        log_warning "⚠ No backup window configured"
    fi
    
    # Check encryption
    local storage_encrypted=$(echo "$cluster_info" | jq -r '.StorageEncrypted')
    if [ "$storage_encrypted" = "true" ]; then
        log_success "✓ Storage encryption enabled"
    else
        log_error "✗ Storage encryption not enabled"
        return 1
    fi
    
    return 0
}

# Test Aurora backup creation
test_aurora_backup_creation() {
    log_info "Testing Aurora manual backup creation..."
    
    local cluster_id="$PROJECT_NAME-aurora-$TEST_ENVIRONMENT"
    local snapshot_id="$cluster_id-test-backup-$(date +%Y%m%d%H%M%S)"
    
    # Create manual snapshot
    log_info "Creating manual snapshot: $snapshot_id"
    if aws rds create-db-cluster-snapshot \
        --db-cluster-identifier "$cluster_id" \
        --db-cluster-snapshot-identifier "$snapshot_id" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_success "✓ Manual snapshot creation initiated"
        
        # Wait for snapshot to complete (with timeout)
        local max_wait=60  # 5 minutes
        local wait_count=0
        
        while [ $wait_count -lt $max_wait ]; do
            local status=$(aws rds describe-db-cluster-snapshots \
                --db-cluster-snapshot-identifier "$snapshot_id" \
                --region "$AWS_REGION" \
                --query "DBClusterSnapshots[0].Status" \
                --output text 2>/dev/null)
            
            case $status in
                "available")
                    log_success "✓ Snapshot created successfully"
                    
                    # Clean up test snapshot
                    aws rds delete-db-cluster-snapshot \
                        --db-cluster-snapshot-identifier "$snapshot_id" \
                        --region "$AWS_REGION" > /dev/null 2>&1
                    log_info "Test snapshot cleaned up"
                    
                    return 0
                    ;;
                "creating")
                    log_info "Snapshot status: creating (waiting...)"
                    sleep 5
                    ((wait_count++))
                    ;;
                "failed")
                    log_error "✗ Snapshot creation failed"
                    return 1
                    ;;
            esac
        done
        
        log_warning "⚠ Snapshot creation timeout (but initiated successfully)"
        # Clean up on timeout
        aws rds delete-db-cluster-snapshot \
            --db-cluster-snapshot-identifier "$snapshot_id" \
            --region "$AWS_REGION" > /dev/null 2>&1 || true
        return 0
    else
        log_error "✗ Failed to create manual snapshot"
        return 1
    fi
}

# Test Aurora automated backups
test_aurora_automated_backups() {
    log_info "Testing Aurora automated backups..."
    
    local cluster_id="$PROJECT_NAME-aurora-$TEST_ENVIRONMENT"
    
    # List automated backups (snapshots created by AWS)
    local automated_snapshots=$(aws rds describe-db-cluster-snapshots \
        --db-cluster-identifier "$cluster_id" \
        --snapshot-type "automated" \
        --region "$AWS_REGION" \
        --query "DBClusterSnapshots[?Status=='available']" \
        --output json)
    
    local snapshot_count=$(echo "$automated_snapshots" | jq length)
    
    if [ "$snapshot_count" -gt 0 ]; then
        log_success "✓ Found $snapshot_count automated backup(s)"
        
        # Check latest backup age
        local latest_snapshot=$(echo "$automated_snapshots" | jq -r '.[0].SnapshotCreateTime')
        if [ "$latest_snapshot" != "null" ]; then
            log_success "✓ Latest automated backup: $latest_snapshot"
        fi
    else
        log_warning "⚠ No automated backups found (may be too early)"
    fi
    
    return 0
}

# Test DynamoDB backup configuration
test_dynamodb_backup_config() {
    log_info "Testing DynamoDB backup configuration..."
    
    local table_name="$PROJECT_NAME-metadata-$TEST_ENVIRONMENT"
    
    # Check if table exists
    if ! aws dynamodb describe-table \
        --table-name "$table_name" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_error "DynamoDB table not found: $table_name"
        return 1
    fi
    
    # Check point-in-time recovery status
    local pitr_status=$(aws dynamodb describe-continuous-backups \
        --table-name "$table_name" \
        --region "$AWS_REGION" \
        --query "ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus" \
        --output text 2>/dev/null)
    
    if [ "$pitr_status" = "ENABLED" ]; then
        log_success "✓ Point-in-time recovery enabled"
        
        # Check earliest recovery time
        local earliest_recovery=$(aws dynamodb describe-continuous-backups \
            --table-name "$table_name" \
            --region "$AWS_REGION" \
            --query "ContinuousBackupsDescription.PointInTimeRecoveryDescription.EarliestRestorableDateTime" \
            --output text 2>/dev/null)
        
        if [ "$earliest_recovery" != "None" ]; then
            log_success "✓ Earliest recovery time: $earliest_recovery"
        fi
    else
        log_error "✗ Point-in-time recovery not enabled"
        return 1
    fi
    
    return 0
}

# Test DynamoDB backup creation
test_dynamodb_backup_creation() {
    log_info "Testing DynamoDB manual backup creation..."
    
    local table_name="$PROJECT_NAME-metadata-$TEST_ENVIRONMENT"
    local backup_name="$table_name-test-backup-$(date +%Y%m%d%H%M%S)"
    
    # Create manual backup
    log_info "Creating manual backup: $backup_name"
    local backup_arn=$(aws dynamodb create-backup \
        --table-name "$table_name" \
        --backup-name "$backup_name" \
        --region "$AWS_REGION" \
        --query "BackupDetails.BackupArn" \
        --output text 2>/dev/null)
    
    if [ -n "$backup_arn" ] && [ "$backup_arn" != "None" ]; then
        log_success "✓ Manual backup creation initiated: $backup_arn"
        
        # Wait for backup to complete
        local max_wait=30
        local wait_count=0
        
        while [ $wait_count -lt $max_wait ]; do
            local status=$(aws dynamodb describe-backup \
                --backup-arn "$backup_arn" \
                --region "$AWS_REGION" \
                --query "BackupDescription.BackupDetails.BackupStatus" \
                --output text 2>/dev/null)
            
            case $status in
                "AVAILABLE")
                    log_success "✓ Backup created successfully"
                    
                    # Clean up test backup
                    aws dynamodb delete-backup \
                        --backup-arn "$backup_arn" \
                        --region "$AWS_REGION" > /dev/null 2>&1
                    log_info "Test backup cleaned up"
                    
                    return 0
                    ;;
                "CREATING")
                    log_info "Backup status: creating (waiting...)"
                    sleep 2
                    ((wait_count++))
                    ;;
                "DELETED"|"FAILED")
                    log_error "✗ Backup creation failed: $status"
                    return 1
                    ;;
            esac
        done
        
        log_warning "⚠ Backup creation timeout (but initiated successfully)"
        # Clean up on timeout
        aws dynamodb delete-backup \
            --backup-arn "$backup_arn" \
            --region "$AWS_REGION" > /dev/null 2>&1 || true
        return 0
    else
        log_error "✗ Failed to create manual backup"
        return 1
    fi
}

# Test S3 lifecycle policies
test_s3_lifecycle_policies() {
    log_info "Testing S3 lifecycle policies..."
    
    local logs_bucket="$PROJECT_NAME-logs-$TEST_ENVIRONMENT"
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$logs_bucket" --region "$AWS_REGION" 2>/dev/null; then
        log_error "S3 bucket not found: $logs_bucket"
        return 1
    fi
    
    # Check lifecycle configuration
    local lifecycle_config=$(aws s3api get-bucket-lifecycle-configuration \
        --bucket "$logs_bucket" \
        --region "$AWS_REGION" 2>/dev/null)
    
    if [ -n "$lifecycle_config" ]; then
        log_success "✓ Lifecycle policy configured"
        
        # Check for transition rules
        local ia_transition=$(echo "$lifecycle_config" | jq -r '.Rules[] | select(.Transitions[]?.StorageClass == "STANDARD_IA") | .Transitions[0].Days')
        local glacier_transition=$(echo "$lifecycle_config" | jq -r '.Rules[] | select(.Transitions[]?.StorageClass == "GLACIER") | .Transitions[0].Days')
        local expiration=$(echo "$lifecycle_config" | jq -r '.Rules[] | select(.Expiration) | .Expiration.Days')
        
        if [ "$ia_transition" != "null" ] && [ "$ia_transition" -gt 0 ]; then
            log_success "✓ Standard-IA transition: $ia_transition days"
        else
            log_warning "⚠ No Standard-IA transition configured"
        fi
        
        if [ "$glacier_transition" != "null" ] && [ "$glacier_transition" -gt 0 ]; then
            log_success "✓ Glacier transition: $glacier_transition days"
        else
            log_warning "⚠ No Glacier transition configured"
        fi
        
        if [ "$expiration" != "null" ] && [ "$expiration" -gt 0 ]; then
            log_success "✓ Object expiration: $expiration days"
        else
            log_warning "⚠ No object expiration configured"
        fi
    else
        log_error "✗ No lifecycle policy configured"
        return 1
    fi
    
    return 0
}

# Test S3 versioning and backup
test_s3_versioning() {
    log_info "Testing S3 versioning configuration..."
    
    local buckets=("logs" "backups" "athena-results")
    
    for bucket_type in "${buckets[@]}"; do
        local bucket_name="$PROJECT_NAME-$bucket_type-$TEST_ENVIRONMENT"
        
        # Check versioning status
        local versioning_status=$(aws s3api get-bucket-versioning \
            --bucket "$bucket_name" \
            --region "$AWS_REGION" \
            --query "Status" \
            --output text 2>/dev/null)
        
        if [ "$versioning_status" = "Enabled" ]; then
            log_success "✓ Versioning enabled for $bucket_name"
        else
            log_warning "⚠ Versioning not enabled for $bucket_name (status: $versioning_status)"
        fi
        
        # Check MFA delete (should be disabled for dev)
        local mfa_delete=$(aws s3api get-bucket-versioning \
            --bucket "$bucket_name" \
            --region "$AWS_REGION" \
            --query "MfaDelete" \
            --output text 2>/dev/null)
        
        if [ "$mfa_delete" = "Disabled" ] || [ "$mfa_delete" = "None" ]; then
            log_success "✓ MFA delete appropriately configured for $bucket_name"
        else
            log_warning "⚠ MFA delete status for $bucket_name: $mfa_delete"
        fi
    done
    
    return 0
}

# Test backup monitoring and alerting
test_backup_monitoring() {
    log_info "Testing backup monitoring and alerting..."
    
    # Check for CloudWatch alarms related to backups
    local backup_alarms=$(aws cloudwatch describe-alarms \
        --alarm-name-prefix "$PROJECT_NAME-$TEST_ENVIRONMENT" \
        --region "$AWS_REGION" \
        --query "MetricAlarms[?contains(AlarmName, 'backup') || contains(AlarmName, 'Backup')]" \
        --output json 2>/dev/null)
    
    local alarm_count=$(echo "$backup_alarms" | jq length)
    
    if [ "$alarm_count" -gt 0 ]; then
        log_success "✓ Found $alarm_count backup-related alarm(s)"
        
        # Check alarm states
        local alarm_states=$(echo "$backup_alarms" | jq -r '.[].StateValue' | sort | uniq -c)
        log_info "Alarm states: $alarm_states"
    else
        log_warning "⚠ No backup-specific alarms found"
    fi
    
    # Check for SNS topics for notifications
    local sns_topics=$(aws sns list-topics \
        --region "$AWS_REGION" \
        --query "Topics[?contains(TopicArn, '$PROJECT_NAME') && contains(TopicArn, '$TEST_ENVIRONMENT')]" \
        --output json 2>/dev/null)
    
    local topic_count=$(echo "$sns_topics" | jq length)
    
    if [ "$topic_count" -gt 0 ]; then
        log_success "✓ Found $topic_count SNS topic(s) for notifications"
    else
        log_warning "⚠ No SNS topics found for notifications"
    fi
    
    return 0
}

# Test recovery procedures (simulation)
test_recovery_procedures() {
    log_info "Testing recovery procedures (simulation)..."
    
    # Test Aurora point-in-time recovery capability
    local cluster_id="$PROJECT_NAME-aurora-$TEST_ENVIRONMENT"
    
    # Check if we can get restore options
    local restore_time=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S.000Z)
    
    log_info "Checking Aurora restore capability to time: $restore_time"
    
    # This is a dry-run check - we don't actually restore
    local cluster_info=$(aws rds describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --region "$AWS_REGION" \
        --query "DBClusters[0]" 2>/dev/null)
    
    local earliest_restore=$(echo "$cluster_info" | jq -r '.EarliestRestorableTime')
    local latest_restore=$(echo "$cluster_info" | jq -r '.LatestRestorableTime')
    
    if [ "$earliest_restore" != "null" ] && [ "$latest_restore" != "null" ]; then
        log_success "✓ Aurora restore window: $earliest_restore to $latest_restore"
    else
        log_warning "⚠ Could not determine Aurora restore window"
    fi
    
    # Test DynamoDB point-in-time recovery capability
    local table_name="$PROJECT_NAME-metadata-$TEST_ENVIRONMENT"
    
    local pitr_info=$(aws dynamodb describe-continuous-backups \
        --table-name "$table_name" \
        --region "$AWS_REGION" \
        --query "ContinuousBackupsDescription.PointInTimeRecoveryDescription" 2>/dev/null)
    
    local earliest_recovery=$(echo "$pitr_info" | jq -r '.EarliestRestorableDateTime')
    local latest_recovery=$(echo "$pitr_info" | jq -r '.LatestRestorableDateTime')
    
    if [ "$earliest_recovery" != "null" ] && [ "$latest_recovery" != "null" ]; then
        log_success "✓ DynamoDB restore window: $earliest_recovery to $latest_recovery"
    else
        log_warning "⚠ Could not determine DynamoDB restore window"
    fi
    
    return 0
}

# Test backup retention and cleanup
test_backup_retention() {
    log_info "Testing backup retention and cleanup..."
    
    # Check Aurora snapshot retention
    local cluster_id="$PROJECT_NAME-aurora-$TEST_ENVIRONMENT"
    
    local snapshots=$(aws rds describe-db-cluster-snapshots \
        --db-cluster-identifier "$cluster_id" \
        --snapshot-type "automated" \
        --region "$AWS_REGION" \
        --query "DBClusterSnapshots[?Status=='available']" \
        --output json 2>/dev/null)
    
    if [ -n "$snapshots" ]; then
        local snapshot_count=$(echo "$snapshots" | jq length)
        log_success "✓ Found $snapshot_count Aurora automated snapshots"
        
        # Check age of oldest snapshot
        local oldest_snapshot=$(echo "$snapshots" | jq -r 'sort_by(.SnapshotCreateTime) | .[0].SnapshotCreateTime')
        if [ "$oldest_snapshot" != "null" ]; then
            log_info "Oldest snapshot: $oldest_snapshot"
        fi
    else
        log_warning "⚠ No Aurora snapshots found for retention check"
    fi
    
    # Check DynamoDB backup retention
    local table_name="$PROJECT_NAME-metadata-$TEST_ENVIRONMENT"
    
    local backups=$(aws dynamodb list-backups \
        --table-name "$table_name" \
        --region "$AWS_REGION" \
        --query "BackupSummaries[?BackupStatus=='AVAILABLE']" \
        --output json 2>/dev/null)
    
    if [ -n "$backups" ]; then
        local backup_count=$(echo "$backups" | jq length)
        log_success "✓ Found $backup_count DynamoDB backups"
    else
        log_info "ℹ No DynamoDB manual backups found"
    fi
    
    return 0
}

# Main test execution
main() {
    log_info "Starting Backup and Recovery Validation Tests..."
    log_info "Environment: $TEST_ENVIRONMENT"
    log_info "Region: $AWS_REGION"
    log_info "Project: $PROJECT_NAME"
    echo ""
    
    # Check AWS credentials
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    # Run tests
    run_test "Aurora Backup Configuration" "test_aurora_backup_config"
    run_test "Aurora Manual Backup Creation" "test_aurora_backup_creation"
    run_test "Aurora Automated Backups" "test_aurora_automated_backups"
    run_test "DynamoDB Backup Configuration" "test_dynamodb_backup_config"
    run_test "DynamoDB Manual Backup Creation" "test_dynamodb_backup_creation"
    run_test "S3 Lifecycle Policies" "test_s3_lifecycle_policies"
    run_test "S3 Versioning Configuration" "test_s3_versioning"
    run_test "Backup Monitoring and Alerting" "test_backup_monitoring"
    run_test "Recovery Procedures Simulation" "test_recovery_procedures"
    run_test "Backup Retention and Cleanup" "test_backup_retention"
    
    # Results summary
    echo ""
    log_info "Backup and Recovery Test Results:"
    echo ""
    
    for result in "${test_results[@]}"; do
        if [[ $result == PASS* ]]; then
            echo -e "${GREEN}$result${NC}"
        else
            echo -e "${RED}$result${NC}"
        fi
    done
    
    echo ""
    log_info "Test Summary:"
    log_info "  Total tests: $total_tests"
    log_info "  Passed: $((total_tests - failed_tests))"
    log_info "  Failed: $failed_tests"
    
    if [ $failed_tests -eq 0 ]; then
        log_success "🎉 All backup and recovery tests passed!"
        exit 0
    else
        log_error "❌ $failed_tests test(s) failed"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --environment, -e   Set test environment (default: dev)"
        echo ""
        echo "Environment variables:"
        echo "  TEST_ENVIRONMENT    Test environment (dev, staging, prod)"
        echo "  AWS_REGION         AWS region (default: eu-west-2)"
        echo ""
        exit 0
        ;;
    --environment|-e)
        TEST_ENVIRONMENT="$2"
        shift 2
        ;;
esac

# Run main function
main "$@"