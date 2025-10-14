#!/bin/bash

# Terraform Workspace Manager
# This script helps manage Terraform workspaces for different environments

set -e

# Configuration
PROJECT_NAME="streaming-logs"
ENVIRONMENTS=("dev" "staging" "prod")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

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
Terraform Workspace Manager for ${PROJECT_NAME}

Usage: $0 [COMMAND] [ENVIRONMENT]

Commands:
    init [env]          Initialize Terraform for environment (dev/staging/prod)
    plan [env]          Run terraform plan for environment
    apply [env]         Run terraform apply for environment
    destroy [env]       Run terraform destroy for environment
    workspace [env]     Switch to workspace for environment
    list                List all workspaces
    status              Show current workspace and status
    validate            Validate Terraform configuration
    format              Format Terraform files
    clean               Clean up temporary files
    help                Show this help message

Environments:
    dev                 Development environment
    staging             Staging environment  
    prod                Production environment

Examples:
    $0 init dev         Initialize development environment
    $0 plan staging     Plan changes for staging
    $0 apply prod       Apply changes to production
    $0 workspace dev    Switch to development workspace
    $0 status           Show current status

Environment Variables:
    TF_VAR_*           Terraform variables
    AWS_PROFILE        AWS profile to use
    AWS_REGION         AWS region (default: eu-west-2)

EOF
}

# Validate environment
validate_environment() {
    local env=$1
    if [[ ! " ${ENVIRONMENTS[@]} " =~ " ${env} " ]]; then
        log_error "Invalid environment: $env"
        log_info "Valid environments: ${ENVIRONMENTS[*]}"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
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
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        log_info "Please configure AWS credentials using 'aws configure' or environment variables"
        exit 1
    fi
    
    local aws_identity=$(aws sts get-caller-identity)
    local account_id=$(echo "$aws_identity" | jq -r '.Account')
    local user_arn=$(echo "$aws_identity" | jq -r '.Arn')
    log_info "Using AWS Account: $account_id"
    log_info "AWS Identity: $user_arn"
}

# Initialize Terraform for environment
init_environment() {
    local env=$1
    validate_environment "$env"
    
    log_info "Initializing Terraform for environment: $env"
    
    cd "$ROOT_DIR"
    
    # Copy environment-specific variables
    if [ -f "environments/$env/terraform.tfvars" ]; then
        log_info "Using variables from environments/$env/terraform.tfvars"
        cp "environments/$env/terraform.tfvars" "terraform.tfvars"
    else
        log_warning "No environment-specific variables found for $env"
        log_info "Using terraform.tfvars.example as template"
        cp "terraform.tfvars.example" "terraform.tfvars"
    fi
    
    # Initialize Terraform with error handling
    log_info "Running terraform init..."
    if ! terraform init; then
        log_error "Terraform initialization failed for environment: $env"
        log_error "Please check your backend configuration and AWS credentials"
        exit 1
    fi
    
    # Create or select workspace
    if terraform workspace list | grep -q "$env"; then
        log_info "Switching to existing workspace: $env"
        terraform workspace select "$env"
    else
        log_info "Creating new workspace: $env"
        terraform workspace new "$env"
    fi
    
    log_success "Environment $env initialized successfully"
}

# Plan changes
plan_environment() {
    local env=$1
    validate_environment "$env"
    
    log_info "Planning changes for environment: $env"
    
    cd "$ROOT_DIR"
    
    # Ensure we're in the right workspace
    terraform workspace select "$env"
    
    # Copy environment variables
    if [ -f "environments/$env/terraform.tfvars" ]; then
        cp "environments/$env/terraform.tfvars" "terraform.tfvars"
    fi
    
    # Run plan with error handling
    log_info "Running terraform plan..."
    local plan_output
    local plan_exit_code
    
    if plan_output=$(terraform plan -var-file="terraform.tfvars" -out="$env.tfplan" 2>&1); then
        plan_exit_code=$?
        if [ $plan_exit_code -eq 0 ]; then
            log_success "Plan completed successfully"
        else
            log_error "Plan completed with warnings or errors (exit code: $plan_exit_code)"
            echo "$plan_output" | grep -E "(Error|Warning):" || true
            exit 1
        fi
    else
        plan_exit_code=$?
        log_error "Terraform plan failed for environment: $env (exit code: $plan_exit_code)"
        echo "$plan_output"
        exit 1
    fi
    
    log_success "Plan completed for environment: $env"
    log_info "Plan saved to: $env.tfplan"
}

# Apply changes
apply_environment() {
    local env=$1
    validate_environment "$env"
    
    log_info "Applying changes for environment: $env"
    
    cd "$ROOT_DIR"
    
    # Ensure we're in the right workspace
    terraform workspace select "$env"
    
    # Check if plan file exists
    if [ -f "$env.tfplan" ]; then
        log_info "Using existing plan file: $env.tfplan"
        
        # Confirm before applying
        if [ "$env" = "prod" ]; then
            log_warning "You are about to apply changes to PRODUCTION environment!"
            read -p "Are you sure you want to continue? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                log_info "Apply cancelled"
                exit 0
            fi
        fi
        
        local apply_exit_code
        if terraform apply "$env.tfplan"; then
            apply_exit_code=$?
            if [ $apply_exit_code -eq 0 ]; then
                log_success "Apply completed successfully"
                rm -f "$env.tfplan"
            else
                log_error "Terraform apply failed for environment: $env (exit code: $apply_exit_code)"
                log_error "Plan file preserved for investigation: $env.tfplan"
                exit 1
            fi
        else
            apply_exit_code=$?
            log_error "Terraform apply failed for environment: $env (exit code: $apply_exit_code)"
            log_error "Plan file preserved for investigation: $env.tfplan"
            exit 1
        fi
    else
        log_warning "No plan file found. Running plan and apply..."
        
        # Copy environment variables
        if [ -f "environments/$env/terraform.tfvars" ]; then
            cp "environments/$env/terraform.tfvars" "terraform.tfvars"
        fi
        
        # Confirm before applying
        if [ "$env" = "prod" ]; then
            log_warning "You are about to apply changes to PRODUCTION environment!"
            read -p "Are you sure you want to continue? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                log_info "Apply cancelled"
                exit 0
            fi
        fi
        
        if terraform apply -var-file="terraform.tfvars"; then
            log_success "Apply completed successfully"
        else
            log_error "Terraform apply failed for environment: $env"
            exit 1
        fi
    fi
    
    log_success "Changes applied successfully to environment: $env"
}

# Destroy environment
destroy_environment() {
    local env=$1
    validate_environment "$env"
    
    log_warning "You are about to DESTROY environment: $env"
    log_warning "This action cannot be undone!"
    
    read -p "Type 'destroy' to confirm: " confirm
    if [ "$confirm" != "destroy" ]; then
        log_info "Destroy cancelled"
        exit 0
    fi
    
    cd "$ROOT_DIR"
    
    # Ensure we're in the right workspace
    terraform workspace select "$env"
    
    # Copy environment variables
    if [ -f "environments/$env/terraform.tfvars" ]; then
        cp "environments/$env/terraform.tfvars" "terraform.tfvars"
    fi
    
    # Run destroy
    log_info "Running terraform destroy..."
    terraform destroy -var-file="terraform.tfvars"
    
    log_success "Environment $env destroyed successfully"
}

# Switch workspace
switch_workspace() {
    local env=$1
    validate_environment "$env"
    
    cd "$ROOT_DIR"
    
    if terraform workspace list | grep -q "$env"; then
        terraform workspace select "$env"
        log_success "Switched to workspace: $env"
    else
        log_error "Workspace $env does not exist"
        log_info "Run '$0 init $env' to create it"
        exit 1
    fi
}

# List workspaces
list_workspaces() {
    cd "$ROOT_DIR"
    
    log_info "Available workspaces:"
    terraform workspace list
}

# Show status
show_status() {
    cd "$ROOT_DIR"
    
    local current_workspace=$(terraform workspace show)
    log_info "Current workspace: $current_workspace"
    
    if [ -f "terraform.tfvars" ]; then
        local env_from_vars=$(grep '^environment' terraform.tfvars | cut -d'"' -f2)
        log_info "Environment from terraform.tfvars: $env_from_vars"
        
        if [ "$current_workspace" != "$env_from_vars" ]; then
            log_warning "Workspace and terraform.tfvars environment don't match!"
        fi
    fi
    
    # Show AWS identity
    local aws_identity=$(aws sts get-caller-identity 2>/dev/null || echo "Not configured")
    if [ "$aws_identity" != "Not configured" ]; then
        local account_id=$(echo "$aws_identity" | jq -r '.Account')
        log_info "AWS Account: $account_id"
    else
        log_warning "AWS credentials not configured"
    fi
}

# Validate configuration
validate_config() {
    cd "$ROOT_DIR"
    
    log_info "Validating Terraform configuration..."
    terraform validate
    
    log_info "Checking format..."
    terraform fmt -check -recursive
    
    log_success "Configuration is valid"
}

# Format files
format_files() {
    cd "$ROOT_DIR"
    
    log_info "Formatting Terraform files..."
    terraform fmt -recursive
    
    log_success "Files formatted successfully"
}

# Clean up
clean_up() {
    cd "$ROOT_DIR"
    
    log_info "Cleaning up temporary files..."
    
    # Remove plan files
    rm -f *.tfplan
    
    # Remove terraform.tfvars (keep example)
    if [ -f "terraform.tfvars" ] && [ -f "terraform.tfvars.example" ]; then
        rm -f "terraform.tfvars"
        log_info "Removed terraform.tfvars (kept terraform.tfvars.example)"
    fi
    
    log_success "Cleanup completed"
}

# Main function
main() {
    local command=${1:-help}
    local environment=$2
    
    case $command in
        init)
            if [ -z "$environment" ]; then
                log_error "Environment required for init command"
                show_help
                exit 1
            fi
            check_prerequisites
            init_environment "$environment"
            ;;
        plan)
            if [ -z "$environment" ]; then
                log_error "Environment required for plan command"
                show_help
                exit 1
            fi
            check_prerequisites
            plan_environment "$environment"
            ;;
        apply)
            if [ -z "$environment" ]; then
                log_error "Environment required for apply command"
                show_help
                exit 1
            fi
            check_prerequisites
            apply_environment "$environment"
            ;;
        destroy)
            if [ -z "$environment" ]; then
                log_error "Environment required for destroy command"
                show_help
                exit 1
            fi
            check_prerequisites
            destroy_environment "$environment"
            ;;
        workspace)
            if [ -z "$environment" ]; then
                log_error "Environment required for workspace command"
                show_help
                exit 1
            fi
            switch_workspace "$environment"
            ;;
        list)
            list_workspaces
            ;;
        status)
            show_status
            ;;
        validate)
            validate_config
            ;;
        format)
            format_files
            ;;
        clean)
            clean_up
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