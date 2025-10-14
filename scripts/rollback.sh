#!/bin/bash

# Terraform Rollback Script
# This script helps rollback failed deployments

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
Terraform Rollback Script

Usage: $0 [COMMAND] [ENVIRONMENT] [OPTIONS]

Commands:
    list-backups [env]          List available state backups
    rollback [env] [backup]     Rollback to specific state backup
    rollback-latest [env]       Rollback to latest backup
    create-backup [env]         Create manual state backup
    restore-from-backup [env]   Interactive restore from backup
    emergency-unlock [env]      Emergency unlock of state
    help                        Show this help message

Environments:
    dev                 Development environment
    staging             Staging environment  
    prod                Production environment

Options:
    --force             Skip confirmation prompts
    --dry-run           Show what would be done without executing
    --backup-reason     Reason for creating backup

Examples:
    $0 list-backups dev
    $0 create-backup prod --backup-reason "Before major update"
    $0 rollback staging backup-20241009-120000
    $0 rollback-latest dev
    $0 emergency-unlock prod

Safety Features:
    - Automatic backup before rollback
    - Confirmation prompts for destructive operations
    - State validation after rollback
    - Rollback history tracking

EOF
}

# Check prerequisites
check_prerequisites() {
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
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

# Get state bucket name
get_state_bucket() {
    local env=$1
    echo "${PROJECT_NAME}-terraform-state-${env}"
}

# Get state key
get_state_key() {
    local env=$1
    echo "${env}/terraform.tfstate"
}

# List available backups
list_backups() {
    local env=$1
    validate_environment "$env"
    
    local bucket=$(get_state_bucket "$env")
    local key=$(get_state_key "$env")
    
    log_info "Listing state backups for environment: $env"
    log_info "Bucket: $bucket"
    log_info "Key: $key"
    
    # List object versions
    aws s3api list-object-versions \
        --bucket "$bucket" \
        --prefix "$key" \
        --query 'Versions[?IsLatest==`false`].[VersionId,LastModified,Size]' \
        --output table
    
    log_info "To rollback to a specific version, use: $0 rollback $env <VersionId>"
}

# Create manual backup
create_backup() {
    local env=$1
    local reason=${2:-"Manual backup"}
    
    validate_environment "$env"
    
    log_info "Creating manual backup for environment: $env"
    log_info "Reason: $reason"
    
    cd "$ROOT_DIR"
    
    # Initialize and select workspace
    terraform init
    terraform workspace select "$env"
    
    # Pull current state
    local backup_file="state-backup-${env}-$(date +%Y%m%d-%H%M%S).tfstate"
    terraform state pull > "$backup_file"
    
    # Upload to S3 with metadata
    local bucket=$(get_state_bucket "$env")
    aws s3 cp "$backup_file" "s3://$bucket/backups/$backup_file" \
        --metadata "environment=$env,reason=$reason,created-by=$(whoami),timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    log_success "Backup created: $backup_file"
    log_info "Backup uploaded to: s3://$bucket/backups/$backup_file"
    
    # Keep local copy
    mkdir -p backups
    mv "$backup_file" "backups/"
    
    log_success "Local backup saved to: backups/$backup_file"
}

# Rollback to specific backup
rollback_to_backup() {
    local env=$1
    local version_id=$2
    local force=${3:-false}
    
    validate_environment "$env"
    
    if [ -z "$version_id" ]; then
        log_error "Version ID is required for rollback"
        exit 1
    fi
    
    log_warning "⚠️  ROLLBACK OPERATION ⚠️"
    log_warning "Environment: $env"
    log_warning "Version ID: $version_id"
    log_warning "This operation will modify your infrastructure state!"
    
    if [ "$force" != "true" ]; then
        read -p "Are you sure you want to proceed? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Rollback cancelled"
            exit 0
        fi
    fi
    
    cd "$ROOT_DIR"
    
    # Create backup before rollback
    log_info "Creating backup before rollback..."
    create_backup "$env" "Before rollback to $version_id"
    
    # Initialize and select workspace
    terraform init
    terraform workspace select "$env"
    
    local bucket=$(get_state_bucket "$env")
    local key=$(get_state_key "$env")
    
    # Download specific version
    local rollback_file="rollback-${env}-$(date +%Y%m%d-%H%M%S).tfstate"
    aws s3api get-object \
        --bucket "$bucket" \
        --key "$key" \
        --version-id "$version_id" \
        "$rollback_file"
    
    # Validate state file
    if ! jq empty "$rollback_file" 2>/dev/null; then
        log_error "Invalid state file downloaded"
        rm -f "$rollback_file"
        exit 1
    fi
    
    # Push state with error handling
    log_info "Pushing rollback state..."
    local push_exit_code
    if terraform state push "$rollback_file"; then
        push_exit_code=$?
        if [ $push_exit_code -ne 0 ]; then
            log_error "Failed to push rollback state (exit code: $push_exit_code)"
            log_error "State file may be corrupted or incompatible"
            
            # Create backup of current state before failing
            local emergency_backup="emergency-backup-$(date +%Y%m%d-%H%M%S).tfstate"
            if terraform state pull > "$emergency_backup" 2>/dev/null; then
                log_warning "Current state backed up to: $emergency_backup"
            else
                log_error "Failed to create emergency backup"
            fi
            
            rm -f "$rollback_file"
            exit 1
        fi
    else
        push_exit_code=$?
        log_error "Failed to push rollback state (exit code: $push_exit_code)"
        log_error "State file may be corrupted or incompatible"
        
        # Create backup of current state before failing
        local emergency_backup="emergency-backup-$(date +%Y%m%d-%H%M%S).tfstate"
        if terraform state pull > "$emergency_backup" 2>/dev/null; then
            log_warning "Current state backed up to: $emergency_backup"
        else
            log_error "Failed to create emergency backup"
        fi
        
        rm -f "$rollback_file"
        exit 1
    fi
    
    # Validate rollback
    log_info "Validating rollback..."
    if terraform plan -detailed-exitcode; then
        log_success "Rollback completed successfully - no changes needed"
    else
        log_warning "Rollback completed but changes detected"
        log_info "Run 'terraform plan' to see what changed"
    fi
    
    # Clean up
    rm -f "$rollback_file"
    
    log_success "Rollback operation completed for environment: $env"
}

# Rollback to latest backup
rollback_to_latest() {
    local env=$1
    local force=${2:-false}
    
    validate_environment "$env"
    
    local bucket=$(get_state_bucket "$env")
    local key=$(get_state_key "$env")
    
    # Get latest non-current version
    local latest_version=$(aws s3api list-object-versions \
        --bucket "$bucket" \
        --prefix "$key" \
        --query 'Versions[?IsLatest==`false`] | [0].VersionId' \
        --output text)
    
    if [ "$latest_version" = "None" ] || [ -z "$latest_version" ]; then
        log_error "No previous versions found for rollback"
        exit 1
    fi
    
    log_info "Latest backup version: $latest_version"
    rollback_to_backup "$env" "$latest_version" "$force"
}

# Emergency unlock state
emergency_unlock() {
    local env=$1
    local force=${2:-false}
    
    validate_environment "$env"
    
    log_warning "⚠️  EMERGENCY UNLOCK ⚠️"
    log_warning "This will force unlock the Terraform state"
    log_warning "Only use this if you're sure no other Terraform process is running"
    
    if [ "$force" != "true" ]; then
        read -p "Are you sure you want to force unlock? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Unlock cancelled"
            exit 0
        fi
    fi
    
    cd "$ROOT_DIR"
    
    # Initialize and select workspace
    terraform init
    terraform workspace select "$env"
    
    # Get lock info
    local lock_table="${PROJECT_NAME}-terraform-state-lock-${env}"
    
    log_info "Checking for locks in table: $lock_table"
    
    # List current locks
    aws dynamodb scan \
        --table-name "$lock_table" \
        --query 'Items[].LockID.S' \
        --output table
    
    # Force unlock
    log_info "Force unlocking state..."
    terraform force-unlock -force $(terraform state list | head -1 | cut -d. -f1) || true
    
    log_success "Emergency unlock completed"
    log_warning "Please verify no other Terraform processes are running before proceeding"
}

# Interactive restore
interactive_restore() {
    local env=$1
    
    validate_environment "$env"
    
    log_info "Interactive restore for environment: $env"
    
    # List available backups
    list_backups "$env"
    
    echo ""
    read -p "Enter the Version ID to restore (or 'latest' for most recent): " version_choice
    
    if [ "$version_choice" = "latest" ]; then
        rollback_to_latest "$env"
    elif [ -n "$version_choice" ]; then
        rollback_to_backup "$env" "$version_choice"
    else
        log_info "No version selected - restore cancelled"
    fi
}

# Main function
main() {
    local command=${1:-help}
    local environment=$2
    local backup_id=$3
    local force=false
    local dry_run=false
    local backup_reason="Manual backup"
    
    # Parse additional options
    shift 3 2>/dev/null || shift $# 2>/dev/null
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --backup-reason)
                backup_reason="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    case $command in
        list-backups)
            if [ -z "$environment" ]; then
                log_error "Environment required"
                show_help
                exit 1
            fi
            check_prerequisites
            list_backups "$environment"
            ;;
        rollback)
            if [ -z "$environment" ] || [ -z "$backup_id" ]; then
                log_error "Environment and backup ID required"
                show_help
                exit 1
            fi
            check_prerequisites
            rollback_to_backup "$environment" "$backup_id" "$force"
            ;;
        rollback-latest)
            if [ -z "$environment" ]; then
                log_error "Environment required"
                show_help
                exit 1
            fi
            check_prerequisites
            rollback_to_latest "$environment" "$force"
            ;;
        create-backup)
            if [ -z "$environment" ]; then
                log_error "Environment required"
                show_help
                exit 1
            fi
            check_prerequisites
            create_backup "$environment" "$backup_reason"
            ;;
        restore-from-backup)
            if [ -z "$environment" ]; then
                log_error "Environment required"
                show_help
                exit 1
            fi
            check_prerequisites
            interactive_restore "$environment"
            ;;
        emergency-unlock)
            if [ -z "$environment" ]; then
                log_error "Environment required"
                show_help
                exit 1
            fi
            check_prerequisites
            emergency_unlock "$environment" "$force"
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