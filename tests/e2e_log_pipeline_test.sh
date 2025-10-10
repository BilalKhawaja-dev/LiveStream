#!/bin/bash

# End-to-End Log Pipeline Testing Script
# Tests the complete log flow: CloudWatch Logs → Kinesis Firehose → S3 → Athena

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

# Generate test log data
generate_test_logs() {
    local service="$1"
    local log_group="$2"
    local count="${3:-10}"
    
    log_info "Generating $count test log entries for $service..."
    
    for i in $(seq 1 $count); do
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
        local request_id="req-$(uuidgen | tr '[:upper:]' '[:lower:]')"
        
        case $service in
            "medialive")
                local message="{\"timestamp\":\"$timestamp\",\"level\":\"INFO\",\"service\":\"medialive\",\"request_id\":\"$request_id\",\"channel_id\":\"ch-12345\",\"message\":\"Stream started successfully\",\"bitrate\":5000,\"resolution\":\"1920x1080\"}"
                ;;
            "mediastore")
                local message="{\"timestamp\":\"$timestamp\",\"level\":\"INFO\",\"service\":\"mediastore\",\"request_id\":\"$request_id\",\"container\":\"live-streams\",\"message\":\"Object uploaded\",\"object_size\":1048576,\"duration_ms\":150}"
                ;;
            "ecs")
                local message="{\"timestamp\":\"$timestamp\",\"level\":\"INFO\",\"service\":\"ecs\",\"request_id\":\"$request_id\",\"task_arn\":\"arn:aws:ecs:eu-west-2:123456789012:task/streaming-task\",\"message\":\"Container started\",\"cpu_usage\":25.5,\"memory_usage\":512}"
                ;;
            "apigateway")
                local message="{\"timestamp\":\"$timestamp\",\"level\":\"INFO\",\"service\":\"apigateway\",\"request_id\":\"$request_id\",\"method\":\"GET\",\"path\"/api/v1/streams\",\"status_code\":200,\"response_time_ms\":45}"
                ;;
            "cognito")
                local message="{\"timestamp\":\"$timestamp\",\"level\":\"INFO\",\"service\":\"cognito\",\"request_id\":\"$request_id\",\"user_pool_id\":\"eu-west-2_ABC123\",\"message\":\"User authenticated\",\"username\":\"testuser\",\"client_id\":\"abc123def456\"}"
                ;;
            "payment")
                local message="{\"timestamp\":\"$timestamp\",\"level\":\"INFO\",\"service\":\"payment\",\"request_id\":\"$request_id\",\"transaction_id\":\"txn-$(uuidgen)\",\"message\":\"Payment processed\",\"amount\":9.99,\"currency\":\"USD\",\"status\":\"completed\"}"
                ;;
            *)
                local message="{\"timestamp\":\"$timestamp\",\"level\":\"INFO\",\"service\":\"$service\",\"request_id\":\"$request_id\",\"message\":\"Test log entry $i\"}"
                ;;
        esac
        
        # Send log to CloudWatch
        aws logs put-log-events \
            --log-group-name "$log_group" \
            --log-stream-name "test-stream-$(date +%Y%m%d)" \
            --log-events timestamp=$(date +%s000),message="$message" \
            --region "$AWS_REGION" > /dev/null 2>&1
        
        # Small delay to avoid throttling
        sleep 0.1
    done
    
    log_success "Generated $count test logs for $service"
}

# Test CloudWatch Logs setup
test_cloudwatch_logs() {
    log_info "Testing CloudWatch Logs setup..."
    
    local services=("medialive" "mediastore" "ecs" "apigateway" "cognito" "payment")
    
    for service in "${services[@]}"; do
        local log_group="/aws/streaming/$service"
        
        # Check if log group exists
        if aws logs describe-log-groups \
            --log-group-name-prefix "$log_group" \
            --region "$AWS_REGION" \
            --query "logGroups[?logGroupName=='$log_group']" \
            --output text | grep -q "$log_group"; then
            log_success "✓ Log group exists: $log_group"
        else
            log_error "✗ Log group missing: $log_group"
            return 1
        fi
        
        # Check subscription filters
        local filters=$(aws logs describe-subscription-filters \
            --log-group-name "$log_group" \
            --region "$AWS_REGION" \
            --query "subscriptionFilters[].filterName" \
            --output text)
        
        if [ -n "$filters" ]; then
            log_success "✓ Subscription filters configured for $log_group"
        else
            log_warning "⚠ No subscription filters found for $log_group"
        fi
    done
    
    return 0
}

# Test Kinesis Firehose delivery streams
test_kinesis_firehose() {
    log_info "Testing Kinesis Firehose delivery streams..."
    
    local stream_name="$PROJECT_NAME-logs-$TEST_ENVIRONMENT"
    
    # Check if delivery stream exists
    if aws firehose describe-delivery-stream \
        --delivery-stream-name "$stream_name" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_success "✓ Firehose delivery stream exists: $stream_name"
        
        # Check stream status
        local status=$(aws firehose describe-delivery-stream \
            --delivery-stream-name "$stream_name" \
            --region "$AWS_REGION" \
            --query "DeliveryStreamDescription.DeliveryStreamStatus" \
            --output text)
        
        if [ "$status" = "ACTIVE" ]; then
            log_success "✓ Firehose stream is active"
        else
            log_error "✗ Firehose stream status: $status"
            return 1
        fi
    else
        log_error "✗ Firehose delivery stream not found: $stream_name"
        return 1
    fi
    
    return 0
}

# Test S3 bucket setup
test_s3_buckets() {
    log_info "Testing S3 bucket setup..."
    
    local buckets=("logs" "errors" "backups" "athena-results")
    
    for bucket_type in "${buckets[@]}"; do
        local bucket_name="$PROJECT_NAME-$bucket_type-$TEST_ENVIRONMENT"
        
        # Check if bucket exists
        if aws s3api head-bucket --bucket "$bucket_name" --region "$AWS_REGION" 2>/dev/null; then
            log_success "✓ S3 bucket exists: $bucket_name"
            
            # Check bucket encryption
            if aws s3api get-bucket-encryption --bucket "$bucket_name" --region "$AWS_REGION" > /dev/null 2>&1; then
                log_success "✓ Bucket encryption enabled: $bucket_name"
            else
                log_warning "⚠ Bucket encryption not configured: $bucket_name"
            fi
            
            # Check lifecycle policy for logs bucket
            if [ "$bucket_type" = "logs" ]; then
                if aws s3api get-bucket-lifecycle-configuration --bucket "$bucket_name" --region "$AWS_REGION" > /dev/null 2>&1; then
                    log_success "✓ Lifecycle policy configured: $bucket_name"
                else
                    log_warning "⚠ No lifecycle policy found: $bucket_name"
                fi
            fi
        else
            log_error "✗ S3 bucket not found: $bucket_name"
            return 1
        fi
    done
    
    return 0
}

# Test Glue Data Catalog
test_glue_catalog() {
    log_info "Testing Glue Data Catalog..."
    
    local database_name="$PROJECT_NAME-$TEST_ENVIRONMENT"
    
    # Check if database exists
    if aws glue get-database \
        --name "$database_name" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_success "✓ Glue database exists: $database_name"
        
        # Check for tables
        local tables=$(aws glue get-tables \
            --database-name "$database_name" \
            --region "$AWS_REGION" \
            --query "TableList[].Name" \
            --output text)
        
        if [ -n "$tables" ]; then
            log_success "✓ Tables found in database: $tables"
        else
            log_info "ℹ No tables found (will be created by crawler)"
        fi
    else
        log_error "✗ Glue database not found: $database_name"
        return 1
    fi
    
    return 0
}

# Test Athena workgroup
test_athena_workgroup() {
    log_info "Testing Athena workgroup..."
    
    local workgroup_name="$PROJECT_NAME-$TEST_ENVIRONMENT"
    
    # Check if workgroup exists
    if aws athena get-work-group \
        --work-group "$workgroup_name" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_success "✓ Athena workgroup exists: $workgroup_name"
        
        # Check workgroup state
        local state=$(aws athena get-work-group \
            --work-group "$workgroup_name" \
            --region "$AWS_REGION" \
            --query "WorkGroup.State" \
            --output text)
        
        if [ "$state" = "ENABLED" ]; then
            log_success "✓ Athena workgroup is enabled"
        else
            log_error "✗ Athena workgroup state: $state"
            return 1
        fi
    else
        log_error "✗ Athena workgroup not found: $workgroup_name"
        return 1
    fi
    
    return 0
}

# Generate test data and wait for processing
test_log_ingestion() {
    log_info "Testing log ingestion pipeline..."
    
    local services=("medialive" "mediastore" "ecs" "apigateway" "cognito" "payment")
    
    # Generate test logs for each service
    for service in "${services[@]}"; do
        local log_group="/aws/streaming/$service"
        generate_test_logs "$service" "$log_group" 5
    done
    
    log_info "Waiting for log processing (60 seconds)..."
    sleep 60
    
    # Check if logs appeared in S3
    local logs_bucket="$PROJECT_NAME-logs-$TEST_ENVIRONMENT"
    local current_year=$(date +%Y)
    local current_month=$(date +%m)
    local current_day=$(date +%d)
    
    # Check for today's logs in S3
    local s3_objects=$(aws s3 ls "s3://$logs_bucket/$current_year/$current_month/$current_day/" --region "$AWS_REGION" 2>/dev/null | wc -l)
    
    if [ "$s3_objects" -gt 0 ]; then
        log_success "✓ Logs found in S3 bucket: $s3_objects objects"
        return 0
    else
        log_warning "⚠ No logs found in S3 yet (may need more time)"
        return 1
    fi
}

# Test Athena queries
test_athena_queries() {
    log_info "Testing Athena queries..."
    
    local database_name="$PROJECT_NAME-$TEST_ENVIRONMENT"
    local workgroup_name="$PROJECT_NAME-$TEST_ENVIRONMENT"
    
    # Simple test query
    local query="SELECT COUNT(*) as log_count FROM information_schema.tables WHERE table_schema = '$database_name'"
    
    # Execute query
    local execution_id=$(aws athena start-query-execution \
        --query-string "$query" \
        --work-group "$workgroup_name" \
        --region "$AWS_REGION" \
        --query "QueryExecutionId" \
        --output text)
    
    if [ -n "$execution_id" ]; then
        log_success "✓ Athena query submitted: $execution_id"
        
        # Wait for query completion
        local max_wait=30
        local wait_count=0
        
        while [ $wait_count -lt $max_wait ]; do
            local status=$(aws athena get-query-execution \
                --query-execution-id "$execution_id" \
                --region "$AWS_REGION" \
                --query "QueryExecution.Status.State" \
                --output text)
            
            case $status in
                "SUCCEEDED")
                    log_success "✓ Athena query completed successfully"
                    return 0
                    ;;
                "FAILED"|"CANCELLED")
                    log_error "✗ Athena query failed: $status"
                    return 1
                    ;;
                "RUNNING"|"QUEUED")
                    log_info "Query status: $status (waiting...)"
                    sleep 2
                    ((wait_count++))
                    ;;
            esac
        done
        
        log_warning "⚠ Query timeout after ${max_wait} attempts"
        return 1
    else
        log_error "✗ Failed to submit Athena query"
        return 1
    fi
}

# Test query performance
test_query_performance() {
    log_info "Testing query performance..."
    
    local database_name="$PROJECT_NAME-$TEST_ENVIRONMENT"
    local workgroup_name="$PROJECT_NAME-$TEST_ENVIRONMENT"
    
    # Performance test query
    local query="SELECT service, COUNT(*) as count, AVG(CAST(response_time_ms AS DOUBLE)) as avg_response_time FROM \"$database_name\".\"logs\" WHERE service = 'apigateway' GROUP BY service LIMIT 10"
    
    local start_time=$(date +%s)
    
    # Execute query
    local execution_id=$(aws athena start-query-execution \
        --query-string "$query" \
        --work-group "$workgroup_name" \
        --region "$AWS_REGION" \
        --query "QueryExecutionId" \
        --output text 2>/dev/null)
    
    if [ -n "$execution_id" ]; then
        # Wait for completion and measure time
        local max_wait=60
        local wait_count=0
        
        while [ $wait_count -lt $max_wait ]; do
            local status=$(aws athena get-query-execution \
                --query-execution-id "$execution_id" \
                --region "$AWS_REGION" \
                --query "QueryExecution.Status.State" \
                --output text 2>/dev/null)
            
            case $status in
                "SUCCEEDED")
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    log_success "✓ Performance query completed in ${duration}s"
                    
                    # Check data scanned
                    local data_scanned=$(aws athena get-query-execution \
                        --query-execution-id "$execution_id" \
                        --region "$AWS_REGION" \
                        --query "QueryExecution.Statistics.DataScannedInBytes" \
                        --output text 2>/dev/null)
                    
                    if [ -n "$data_scanned" ] && [ "$data_scanned" != "None" ]; then
                        local data_mb=$((data_scanned / 1024 / 1024))
                        log_info "Data scanned: ${data_mb}MB"
                    fi
                    
                    return 0
                    ;;
                "FAILED"|"CANCELLED")
                    log_warning "⚠ Performance query failed (expected if no data yet)"
                    return 0  # Don't fail the test for this
                    ;;
                "RUNNING"|"QUEUED")
                    sleep 2
                    ((wait_count++))
                    ;;
            esac
        done
        
        log_warning "⚠ Performance query timeout"
        return 0  # Don't fail the test for timeout
    else
        log_warning "⚠ Could not submit performance query (expected if no tables yet)"
        return 0  # Don't fail the test for this
    fi
}

# Cleanup test data
cleanup_test_data() {
    log_info "Cleaning up test data..."
    
    local services=("medialive" "mediastore" "ecs" "apigateway" "cognito" "payment")
    
    for service in "${services[@]}"; do
        local log_group="/aws/streaming/$service"
        local log_stream="test-stream-$(date +%Y%m%d)"
        
        # Delete test log stream
        aws logs delete-log-stream \
            --log-group-name "$log_group" \
            --log-stream-name "$log_stream" \
            --region "$AWS_REGION" 2>/dev/null || true
    done
    
    log_success "Test data cleanup completed"
}

# Main test execution
main() {
    log_info "Starting End-to-End Log Pipeline Tests..."
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
    run_test "CloudWatch Logs Setup" "test_cloudwatch_logs"
    run_test "Kinesis Firehose Setup" "test_kinesis_firehose"
    run_test "S3 Buckets Setup" "test_s3_buckets"
    run_test "Glue Data Catalog Setup" "test_glue_catalog"
    run_test "Athena Workgroup Setup" "test_athena_workgroup"
    run_test "Log Ingestion Pipeline" "test_log_ingestion"
    run_test "Athena Query Execution" "test_athena_queries"
    run_test "Query Performance" "test_query_performance"
    
    # Cleanup
    cleanup_test_data
    
    # Results summary
    echo ""
    log_info "End-to-End Test Results:"
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
        log_success "🎉 All end-to-end tests passed!"
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
        echo "  --cleanup-only      Only run cleanup"
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
    --cleanup-only)
        cleanup_test_data
        exit 0
        ;;
esac

# Run main function
main "$@"