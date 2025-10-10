#!/bin/bash

# Secrets Manager for Terraform Variables
# This script helps manage sensitive variables using AWS Secrets Manager

set -e

# Configuration
PROJECT_NAME="streaming-logs"
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
Secrets Manager for Terraform Variables

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    create-secret [env] [key] [value]    Create a new secret
    get-secret [env] [key]               Retrieve a secret value
    update-secret [env] [key] [value]    Update an existing secret
    delete-secret [env] [key]            Delete a secret
    list-secrets [env]                   List all secrets for environment
    export-env [env]                     Export secrets as environment variables
    import-secrets [env] [file]          Import secrets from JSON file
    rotate-secret [env] [key]            Rotate a secret (generate new value)
    help                                 Show this help message

Environments:
    dev                 Development environment
    staging             Staging environment  
    prod                Production environment

Examples:
    $0 create-secret dev database_password "my-secure-password"
    $0 get-secret prod api_key
    $0 export-env staging > .env
    $0 list-secrets dev

Secret Naming Convention:
    /${PROJECT_NAME}/{environment}/{key}

Environment Variables:
    AWS_PROFILE        AWS profile to use
    AWS_REGION         AWS region (default: eu-west-2)

EOF
}

# Check prerequisites
check_prerequisites() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found"
        log_info "Please install AWS CLI and try again"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq not found"
        log_info "Please install jq and try again"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        log_info "Please configure AWS credentials using 'aws configure' or environment variables"
        exit 1
    fi
}

# Validate environment
validate_environment() {
    local env=$1
    local valid_envs=("dev" "staging" "prod")
    
    if [[ ! " ${valid_envs[@]} " =~ " ${env} " ]]; then
        log_error "Invalid environment: $env"
        log_info "Valid environments: ${valid_envs[*]}"
        exit 1
    fi
}

# Get secret name
get_secret_name() {
    local env=$1
    local key=$2
    echo "/${PROJECT_NAME}/${env}/${key}"
}

# Create secret
create_secret() {
    local env=$1
    local key=$2
    local value=$3
    
    validate_environment "$env"
    
    if [ -z "$key" ] || [ -z "$value" ]; then
        log_error "Key and value are required"
        exit 1
    fi
    
    local secret_name=$(get_secret_name "$env" "$key")
    
    log_info "Creating secret: $secret_name"
    
    if aws secretsmanager describe-secret --secret-id "$secret_name" &> /dev/null; then
        log_error "Secret already exists: $secret_name"
        log_info "Use 'update-secret' to modify existing secrets"
        exit 1
    fi
    
    aws secretsmanager create-secret \
        --name "$secret_name" \
        --description "Terraform variable for ${PROJECT_NAME} ${env} environment" \
        --secret-string "$value" \
        --tags '[
            {"Key": "Project", "Value": "'$PROJECT_NAME'"},
            {"Key": "Environment", "Value": "'$env'"},
            {"Key": "ManagedBy", "Value": "terraform-secrets-manager"},
            {"Key": "SecretType", "Value": "terraform-variable"}
        ]' > /dev/null
    
    log_success "Secret created: $secret_name"
}

# Get secret
get_secret() {
    local env=$1
    local key=$2
    
    validate_environment "$env"
    
    if [ -z "$key" ]; then
        log_error "Key is required"
        exit 1
    fi
    
    local secret_name=$(get_secret_name "$env" "$key")
    
    local value=$(aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --query 'SecretString' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$value"
    else
        log_error "Secret not found: $secret_name"
        exit 1
    fi
}

# Update secret
update_secret() {
    local env=$1
    local key=$2
    local value=$3
    
    validate_environment "$env"
    
    if [ -z "$key" ] || [ -z "$value" ]; then
        log_error "Key and value are required"
        exit 1
    fi
    
    local secret_name=$(get_secret_name "$env" "$key")
    
    log_info "Updating secret: $secret_name"
    
    aws secretsmanager update-secret \
        --secret-id "$secret_name" \
        --secret-string "$value" > /dev/null
    
    log_success "Secret updated: $secret_name"
}

# Delete secret
delete_secret() {
    local env=$1
    local key=$2
    
    validate_environment "$env"
    
    if [ -z "$key" ]; then
        log_error "Key is required"
        exit 1
    fi
    
    local secret_name=$(get_secret_name "$env" "$key")
    
    log_warning "You are about to delete secret: $secret_name"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Delete cancelled"
        exit 0
    fi
    
    aws secretsmanager delete-secret \
        --secret-id "$secret_name" \
        --force-delete-without-recovery > /dev/null
    
    log_success "Secret deleted: $secret_name"
}

# List secrets
list_secrets() {
    local env=$1
    
    validate_environment "$env"
    
    local prefix="/${PROJECT_NAME}/${env}/"
    
    log_info "Secrets for environment: $env"
    
    aws secretsmanager list-secrets \
        --query "SecretList[?starts_with(Name, '$prefix')].{Name:Name,Description:Description,LastChanged:LastChangedDate}" \
        --output table
}

# Export environment variables
export_env() {
    local env=$1
    
    validate_environment "$env"
    
    local prefix="/${PROJECT_NAME}/${env}/"
    
    # Get all secrets for the environment
    local secrets=$(aws secretsmanager list-secrets \
        --query "SecretList[?starts_with(Name, '$prefix')].Name" \
        --output text)
    
    if [ -z "$secrets" ]; then
        log_warning "No secrets found for environment: $env"
        return
    fi
    
    echo "# Terraform environment variables for $env"
    echo "# Generated on $(date)"
    echo ""
    
    for secret_name in $secrets; do
        local key=$(basename "$secret_name")
        local tf_var_name="TF_VAR_${key}"
        
        local value=$(aws secretsmanager get-secret-value \
            --secret-id "$secret_name" \
            --query 'SecretString' \
            --output text 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo "export ${tf_var_name}=\"${value}\""
        else
            log_error "Failed to retrieve secret: $secret_name" >&2
        fi
    done
}

# Import secrets from JSON file
import_secrets() {
    local env=$1
    local file=$2
    
    validate_environment "$env"
    
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        log_error "Valid JSON file is required"
        exit 1
    fi
    
    log_info "Importing secrets from: $file"
    
    # Validate JSON
    if ! jq empty "$file" 2>/dev/null; then
        log_error "Invalid JSON file: $file"
        exit 1
    fi
    
    # Import each key-value pair
    local count=0
    while IFS="=" read -r key value; do
        if [ -n "$key" ] && [ -n "$value" ]; then
            local secret_name=$(get_secret_name "$env" "$key")
            
            # Check if secret exists
            if aws secretsmanager describe-secret --secret-id "$secret_name" &> /dev/null; then
                log_warning "Secret exists, updating: $secret_name"
                update_secret "$env" "$key" "$value"
            else
                create_secret "$env" "$key" "$value"
            fi
            
            ((count++))
        fi
    done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$file")
    
    log_success "Imported $count secrets for environment: $env"
}

# Rotate secret (generate new password)
rotate_secret() {
    local env=$1
    local key=$2
    
    validate_environment "$env"
    
    if [ -z "$key" ]; then
        log_error "Key is required"
        exit 1
    fi
    
    local secret_name=$(get_secret_name "$env" "$key")
    
    # Check if secret exists
    if ! aws secretsmanager describe-secret --secret-id "$secret_name" &> /dev/null; then
        log_error "Secret not found: $secret_name"
        exit 1
    fi
    
    log_info "Rotating secret: $secret_name"
    
    # Generate new password (32 characters, alphanumeric + special chars)
    local new_value=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    log_warning "New password will be: $new_value"
    read -p "Continue with rotation? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Rotation cancelled"
        exit 0
    fi
    
    update_secret "$env" "$key" "$new_value"
    log_success "Secret rotated: $secret_name"
}

# Generate secure password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-$length
}

# Main function
main() {
    local command=${1:-help}
    
    case $command in
        create-secret)
            check_prerequisites
            create_secret "$2" "$3" "$4"
            ;;
        get-secret)
            check_prerequisites
            get_secret "$2" "$3"
            ;;
        update-secret)
            check_prerequisites
            update_secret "$2" "$3" "$4"
            ;;
        delete-secret)
            check_prerequisites
            delete_secret "$2" "$3"
            ;;
        list-secrets)
            check_prerequisites
            list_secrets "$2"
            ;;
        export-env)
            check_prerequisites
            export_env "$2"
            ;;
        import-secrets)
            check_prerequisites
            import_secrets "$2" "$3"
            ;;
        rotate-secret)
            check_prerequisites
            rotate_secret "$2" "$3"
            ;;
        generate-password)
            generate_password "$2"
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