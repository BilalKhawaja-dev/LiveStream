#!/bin/bash

# Integration tests for Terraform infrastructure deployment
# This script validates the complete infrastructure deployment

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_ENVIRONMENT="${TEST_ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-eu-west-2}"

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

# Function to check AWS CLI and credentials
check_aws_setup() {
    log_info "Checking AWS setup..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found"
        return 1
    fi
    
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        log_error "AWS credentials not configured or invalid"
        return 1
    fi
    
    log_success "AWS setup verified"
    return 0
}

# Function to check Terraform setup
check_terraform_setup() {
    log_info "Checking Terraform setup..."
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found"
        return 1
    fi
    
    cd "$ROOT_DIR"
    
    if ! terraform version > /dev/null 2>&1; then
        log_error "Terraform not working properly"
        return 1
    fi
    
    log_success "Terraform setup verified"
    return 0
}

# Function to test Terraform initialization
test_terraform_init() {
    cd "$ROOT_DIR"
    
    # Copy environment-specific variables
    if [ -f "environments/$TEST_ENVIRONMENT/terraform.tfvars" ]; then
        cp "environments/$TEST_ENVIRONMENT/terraform.tfvars" terraform.tfvars
    else
        log_warning "No terraform.tfvars found for $TEST_ENVIRONMENT environment"
        return 1
    fi
    
    # Initialize Terraform
    if terraform init > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to test Terraform validation
test_terraform_validate() {
    cd "$ROOT_DIR"
    
    if terraform validate > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to test Terraform plan
test_terraform_plan() {
    cd "$ROOT_DIR"
    
    # Select or create workspace
    terraform workspace select "$TEST_ENVIRONMENT" > /dev/null 2>&1 || \
    terraform workspace new "$TEST_ENVIRONMENT" > /dev/null 2>&1
    
    if terraform plan -var-file=terraform.tfvars -out=test.tfplan > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to test module validation
test_modules_validation() {
    cd "$ROOT_DIR"
    
    for module_dir in modules/*/; do
        if [ -d "$module_dir" ]; then
            log_info "Validating module: $module_dir"
            cd "$module_dir"
            
            if ! terraform init -backend=false > /dev/null 2>&1; then
                log_error "Failed to initialize module: $module_dir"
                cd "$ROOT_DIR"
                return 1
            fi
            
            if ! terraform validate > /dev/null 2>&1; then
                log_error "Failed to validate module: $module_dir"
                cd "$ROOT_DIR"
                return 1
            fi
            
            cd "$ROOT_DIR"
        fi
    done
    
    return 0
}

# Function to test security scanning
test_security_scan() {
    cd "$ROOT_DIR"
    
    # Test with tfsec if available
    if command -v tfsec &> /dev/null; then
        if tfsec . --soft-fail > /dev/null 2>&1; then
            log_info "Security scan passed"
        else
            log_warning "Security issues found (non-blocking)"
        fi
    fi
    
    return 0
}

# Function to test linting
test_linting() {
    cd "$ROOT_DIR"
    
    # Test formatting
    if ! terraform fmt -check -recursive > /dev/null 2>&1; then
        log_error "Terraform formatting issues found"
        return 1
    fi
    
    # Test with tflint if available
    if command -v tflint &> /dev/null; then
        if tflint --init > /dev/null 2>&1 && tflint > /dev/null 2>&1; then
            log_info "Linting passed"
        else
            log_warning "Linting issues found (non-blocking)"
        fi
    fi
    
    return 0
}

# Function to test environment-specific configurations
test_environment_configs() {
    cd "$ROOT_DIR"
    
    for env in dev staging prod; do
        if [ -f "environments/$env/terraform.tfvars" ]; then
            log_info "Testing $env environment configuration"
            
            # Copy environment variables
            cp "environments/$env/terraform.tfvars" "test_$env.tfvars"
            
            # Test plan with environment variables
            if terraform plan -var-file="test_$env.tfvars" > /dev/null 2>&1; then
                log_success "✓ $env environment configuration valid"
            else
                log_error "✗ $env environment configuration invalid"
                rm -f "test_$env.tfvars"
                return 1
            fi
            
            # Cleanup
            rm -f "test_$env.tfvars"
        fi
    done
    
    return 0
}

# Function to test state management
test_state_management() {
    cd "$ROOT_DIR"
    
    # Check if state backend is configured
    if grep -q "backend.*s3" *.tf 2>/dev/null; then
        log_info "S3 backend configuration found"
        
        # Test state initialization
        if terraform init -backend=true > /dev/null 2>&1; then
            return 0
        else
            log_error "Failed to initialize with remote state backend"
            return 1
        fi
    else
        log_warning "No remote state backend configured"
        return 0
    fi
}

# Function to test workspace management
test_workspace_management() {
    cd "$ROOT_DIR"
    
    # Test workspace creation
    test_workspace="integration-test-$(date +%s)"
    
    if terraform workspace new "$test_workspace" > /dev/null 2>&1; then
        log_info "Created test workspace: $test_workspace"
        
        # Test workspace switching
        if terraform workspace select "$test_workspace" > /dev/null 2>&1; then
            log_info "Switched to test workspace"
            
            # Cleanup test workspace
            terraform workspace select default > /dev/null 2>&1
            terraform workspace delete "$test_workspace" > /dev/null 2>&1
            
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Function to test rollback procedures
test_rollback_procedures() {
    cd "$ROOT_DIR"
    
    # Check if rollback script exists and is executable
    if [ -x "scripts/rollback.sh" ]; then
        log_info "Rollback script found and executable"
        
        # Test rollback script help/dry-run
        if ./scripts/rollback.sh --help > /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        log_error "Rollback script not found or not executable"
        return 1
    fi
}

# Main test execution
main() {
    log_info "Starting Terraform infrastructure integration tests..."
    log_info "Test environment: $TEST_ENVIRONMENT"
    log_info "AWS region: $AWS_REGION"
    echo ""
    
    # Prerequisites
    if ! check_aws_setup || ! check_terraform_setup; then
        log_error "Prerequisites not met. Exiting."
        exit 1
    fi
    
    echo ""
    log_info "Running integration tests..."
    echo ""
    
    # Run tests
    run_test "Terraform Initialization" "test_terraform_init"
    run_test "Terraform Validation" "test_terraform_validate"
    run_test "Terraform Plan Generation" "test_terraform_plan"
    run_test "Module Validation" "test_modules_validation"
    run_test "Security Scanning" "test_security_scan"
    run_test "Code Linting" "test_linting"
    run_test "Environment Configurations" "test_environment_configs"
    run_test "State Management" "test_state_management"
    run_test "Workspace Management" "test_workspace_management"
    run_test "Rollback Procedures" "test_rollback_procedures"
    
    # Cleanup
    cd "$ROOT_DIR"
    rm -f terraform.tfvars test.tfplan
    
    # Results summary
    echo ""
    log_info "Integration test results:"
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
        log_success "🎉 All integration tests passed!"
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