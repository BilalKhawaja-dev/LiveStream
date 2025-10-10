#!/bin/bash

# Terraform Validation and Testing Pipeline
# This script validates Terraform configuration and runs tests

set -e

# Configuration
PROJECT_NAME="streaming-logs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENVIRONMENTS=("dev" "staging" "prod")

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

# Help function
show_help() {
    cat << EOF
Terraform Validation and Testing Pipeline

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    validate            Validate Terraform configuration
    format              Check and fix Terraform formatting
    security            Run security checks with tfsec
    lint                Run Terraform linting with tflint
    plan-all            Run terraform plan for all environments
    test                Run integration tests
    full                Run full validation pipeline
    help                Show this help message

Options:
    --fix               Fix issues automatically where possible
    --environment ENV   Run tests for specific environment only
    --verbose           Enable verbose output
    --no-color          Disable colored output

Examples:
    $0 validate         Validate configuration
    $0 format --fix     Format and fix files
    $0 security         Run security checks
    $0 full             Run complete validation pipeline
    $0 test --environment dev    Test specific environment

EOF
}

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v tflint &> /dev/null; then
        log_warning "tflint not found - linting will be skipped"
    fi
    
    if ! command -v tfsec &> /dev/null; then
        log_warning "tfsec not found - security checks will be skipped"
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again"
        exit 1
    fi
    
    # Check Terraform version
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_info "Using Terraform version: $tf_version"
}

# Validate Terraform configuration
validate_terraform() {
    log_info "Validating Terraform configuration..."
    
    cd "$ROOT_DIR"
    
    # Initialize without backend for validation
    log_info "Initializing Terraform for validation..."
    terraform init -backend=false
    
    # Validate configuration
    log_info "Running terraform validate..."
    if terraform validate; then
        log_success "Terraform configuration is valid"
        return 0
    else
        log_error "Terraform validation failed"
        return 1
    fi
}

# Check and fix formatting
check_format() {
    local fix_format=${1:-false}
    
    log_info "Checking Terraform formatting..."
    
    cd "$ROOT_DIR"
    
    if [ "$fix_format" = "true" ]; then
        log_info "Formatting Terraform files..."
        terraform fmt -recursive
        log_success "Files formatted successfully"
    else
        log_info "Checking format without fixing..."
        if terraform fmt -check -recursive; then
            log_success "All files are properly formatted"
            return 0
        else
            log_error "Some files are not properly formatted"
            log_info "Run with --fix to automatically format files"
            return 1
        fi
    fi
}

# Run security checks
run_security_checks() {
    if ! command -v tfsec &> /dev/null; then
        log_warning "tfsec not installed - skipping security checks"
        return 0
    fi
    
    log_info "Running security checks with tfsec..."
    
    cd "$ROOT_DIR"
    
    # Run tfsec with custom configuration
    if tfsec . --format json --out tfsec-results.json; then
        log_success "Security checks passed"
        
        # Show summary
        local issues=$(jq '.results | length' tfsec-results.json 2>/dev/null || echo "0")
        log_info "Security scan completed: $issues issues found"
        
        if [ "$issues" -gt 0 ]; then
            log_warning "Security issues found - check tfsec-results.json for details"
            return 1
        fi
        
        return 0
    else
        log_error "Security checks failed"
        return 1
    fi
}

# Run linting
run_linting() {
    if ! command -v tflint &> /dev/null; then
        log_warning "tflint not installed - skipping linting"
        return 0
    fi
    
    log_info "Running Terraform linting with tflint..."
    
    cd "$ROOT_DIR"
    
    # Initialize tflint
    tflint --init
    
    # Run linting
    if tflint --format json > tflint-results.json; then
        log_success "Linting checks passed"
        
        # Show summary
        local issues=$(jq '.issues | length' tflint-results.json 2>/dev/null || echo "0")
        log_info "Linting completed: $issues issues found"
        
        if [ "$issues" -gt 0 ]; then
            log_warning "Linting issues found - check tflint-results.json for details"
            return 1
        fi
        
        return 0
    else
        log_error "Linting failed"
        return 1
    fi
}

# Plan for all environments
plan_all_environments() {
    local target_env=${1:-""}
    local environments_to_test=()
    
    if [ -n "$target_env" ]; then
        environments_to_test=("$target_env")
    else
        environments_to_test=("${ENVIRONMENTS[@]}")
    fi
    
    log_info "Running terraform plan for environments: ${environments_to_test[*]}"
    
    cd "$ROOT_DIR"
    
    local failed_envs=()
    
    for env in "${environments_to_test[@]}"; do
        log_info "Planning for environment: $env"
        
        # Copy environment variables
        if [ -f "environments/$env/terraform.tfvars" ]; then
            cp "environments/$env/terraform.tfvars" "terraform.tfvars"
        else
            log_warning "No terraform.tfvars found for $env"
            continue
        fi
        
        # Initialize with backend
        if ! terraform init; then
            log_error "Failed to initialize Terraform for $env"
            failed_envs+=("$env")
            continue
        fi
        
        # Select workspace
        if terraform workspace list | grep -q "$env"; then
            terraform workspace select "$env"
        else
            log_warning "Workspace $env does not exist - creating it"
            terraform workspace new "$env"
        fi
        
        # Run plan
        if terraform plan -var-file="terraform.tfvars" -out="$env.tfplan"; then
            log_success "Plan successful for environment: $env"
        else
            log_error "Plan failed for environment: $env"
            failed_envs+=("$env")
        fi
    done
    
    # Clean up
    rm -f terraform.tfvars
    
    if [ ${#failed_envs[@]} -eq 0 ]; then
        log_success "All environment plans completed successfully"
        return 0
    else
        log_error "Plan failed for environments: ${failed_envs[*]}"
        return 1
    fi
}

# Run integration tests
run_integration_tests() {
    local target_env=${1:-"dev"}
    
    log_info "Running integration tests for environment: $target_env"
    
    cd "$ROOT_DIR"
    
    # Test module validation
    log_info "Testing individual modules..."
    
    local modules_dir="modules"
    local failed_modules=()
    
    for module_dir in "$modules_dir"/*; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            log_info "Testing module: $module_name"
            
            cd "$module_dir"
            
            # Initialize and validate module
            if terraform init -backend=false && terraform validate; then
                log_success "Module $module_name validation passed"
            else
                log_error "Module $module_name validation failed"
                failed_modules+=("$module_name")
            fi
            
            cd "$ROOT_DIR"
        fi
    done
    
    if [ ${#failed_modules[@]} -gt 0 ]; then
        log_error "Module validation failed for: ${failed_modules[*]}"
        return 1
    fi
    
    # Test storage module specifically (has tests)
    if [ -d "modules/storage/tests" ]; then
        log_info "Running storage module tests..."
        cd "modules/storage/tests"
        
        if [ -f "test_storage_module.sh" ]; then
            chmod +x test_storage_module.sh
            if ./test_storage_module.sh; then
                log_success "Storage module tests passed"
            else
                log_error "Storage module tests failed"
                cd "$ROOT_DIR"
                return 1
            fi
        fi
        
        cd "$ROOT_DIR"
    fi
    
    log_success "Integration tests completed successfully"
    return 0
}

# Generate test report
generate_report() {
    log_info "Generating validation report..."
    
    cd "$ROOT_DIR"
    
    local report_file="validation-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project": "$PROJECT_NAME",
  "validation_results": {
    "terraform_validate": $([ -f ".terraform/terraform.tfstate" ] && echo "true" || echo "false"),
    "format_check": $(terraform fmt -check -recursive &>/dev/null && echo "true" || echo "false"),
    "security_scan": $([ -f "tfsec-results.json" ] && echo "true" || echo "false"),
    "linting": $([ -f "tflint-results.json" ] && echo "true" || echo "false")
  },
  "environment_plans": {
EOF
    
    local first=true
    for env in "${ENVIRONMENTS[@]}"; do
        if [ "$first" = false ]; then
            echo "," >> "$report_file"
        fi
        first=false
        
        local plan_status="false"
        if [ -f "$env.tfplan" ]; then
            plan_status="true"
        fi
        
        echo "    \"$env\": $plan_status" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
  },
  "summary": {
    "total_checks": 4,
    "passed_checks": 0,
    "failed_checks": 0
  }
}
EOF
    
    log_success "Validation report generated: $report_file"
}

# Run full validation pipeline
run_full_pipeline() {
    local fix_issues=${1:-false}
    local target_env=${2:-""}
    
    log_info "Running full validation pipeline..."
    
    local failed_checks=0
    local total_checks=0
    
    # 1. Format check
    ((total_checks++))
    if check_format "$fix_issues"; then
        log_success "✓ Format check passed"
    else
        log_error "✗ Format check failed"
        ((failed_checks++))
    fi
    
    # 2. Terraform validation
    ((total_checks++))
    if validate_terraform; then
        log_success "✓ Terraform validation passed"
    else
        log_error "✗ Terraform validation failed"
        ((failed_checks++))
    fi
    
    # 3. Security checks
    ((total_checks++))
    if run_security_checks; then
        log_success "✓ Security checks passed"
    else
        log_error "✗ Security checks failed"
        ((failed_checks++))
    fi
    
    # 4. Linting
    ((total_checks++))
    if run_linting; then
        log_success "✓ Linting passed"
    else
        log_error "✗ Linting failed"
        ((failed_checks++))
    fi
    
    # 5. Plan validation
    ((total_checks++))
    if plan_all_environments "$target_env"; then
        log_success "✓ Plan validation passed"
    else
        log_error "✗ Plan validation failed"
        ((failed_checks++))
    fi
    
    # 6. Integration tests
    ((total_checks++))
    if run_integration_tests "$target_env"; then
        log_success "✓ Integration tests passed"
    else
        log_error "✗ Integration tests failed"
        ((failed_checks++))
    fi
    
    # Generate report
    generate_report
    
    # Summary
    local passed_checks=$((total_checks - failed_checks))
    log_info "Validation Summary: $passed_checks/$total_checks checks passed"
    
    if [ $failed_checks -eq 0 ]; then
        log_success "🎉 All validation checks passed!"
        return 0
    else
        log_error "❌ $failed_checks validation checks failed"
        return 1
    fi
}

# Clean up temporary files
cleanup() {
    cd "$ROOT_DIR"
    
    log_info "Cleaning up temporary files..."
    
    # Remove plan files
    rm -f *.tfplan
    
    # Remove temporary terraform.tfvars
    if [ -f "terraform.tfvars" ] && [ -f "terraform.tfvars.example" ]; then
        rm -f "terraform.tfvars"
    fi
    
    # Remove test results (keep for CI/CD)
    # rm -f tfsec-results.json tflint-results.json
    
    log_success "Cleanup completed"
}

# Main function
main() {
    local command=${1:-help}
    local fix_issues=false
    local target_env=""
    local verbose=false
    
    # Parse options
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fix)
                fix_issues=true
                shift
                ;;
            --environment)
                target_env="$2"
                shift 2
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --no-color)
                RED=''
                GREEN=''
                YELLOW=''
                BLUE=''
                NC=''
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set up trap for cleanup
    trap cleanup EXIT
    
    case $command in
        validate)
            check_prerequisites
            validate_terraform
            ;;
        format)
            check_format "$fix_issues"
            ;;
        security)
            check_prerequisites
            run_security_checks
            ;;
        lint)
            check_prerequisites
            run_linting
            ;;
        plan-all)
            check_prerequisites
            plan_all_environments "$target_env"
            ;;
        test)
            check_prerequisites
            run_integration_tests "$target_env"
            ;;
        full)
            check_prerequisites
            run_full_pipeline "$fix_issues" "$target_env"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"