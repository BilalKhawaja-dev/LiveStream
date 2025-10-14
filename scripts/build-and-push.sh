#!/bin/bash
set -euo pipefail

# Build and push Docker images to ECR
# Usage: ./build-and-push.sh [app-name] [environment] [tag]

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-2}"
PROJECT_NAME="${PROJECT_NAME:-streaming-logs}"
ENVIRONMENT="${1:-dev}"
APP_NAME="${2:-all}"
TAG="${3:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Applications to build
APPLICATIONS=(
    "viewer-portal"
    "creator-dashboard"
    "admin-portal"
    "support-system"
    "analytics-dashboard"
    "developer-console"
)

# Functions
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get ECR login token
ecr_login() {
    log_info "Logging into ECR..."
    
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin \
        "$account_id.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    log_success "ECR login successful"
}

# Create ECR repository if it doesn't exist
create_ecr_repo() {
    local app_name="$1"
    local repo_name="$PROJECT_NAME-$app_name"
    
    log_info "Checking ECR repository: $repo_name"
    
    if ! aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" &> /dev/null; then
        log_info "Creating ECR repository: $repo_name"
        aws ecr create-repository \
            --repository-name "$repo_name" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
        log_success "ECR repository created: $repo_name"
    else
        log_info "ECR repository already exists: $repo_name"
    fi
}

# Build Docker image
build_image() {
    local app_name="$1"
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    
    local image_name="$account_id.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME-$app_name:$TAG"
    
    log_info "Building Docker image for $app_name..."
    
    cd streaming-platform-frontend
    
    # Build the image with build args
    docker build \
        --build-arg APP_NAME="$app_name" \
        --build-arg NODE_ENV="$ENVIRONMENT" \
        -t "$image_name" \
        -f Dockerfile .
    
    cd ..
    
    log_success "Built image: $image_name"
    echo "$image_name"
}

# Push Docker image
push_image() {
    local image_name="$1"
    
    log_info "Pushing image: $image_name"
    
    docker push "$image_name"
    
    log_success "Pushed image: $image_name"
}

# Build and push single application
build_and_push_app() {
    local app_name="$1"
    
    log_info "Processing application: $app_name"
    
    # Check if application directory exists
    if [[ ! -d "streaming-platform-frontend/packages/$app_name" ]]; then
        log_error "Application directory not found: streaming-platform-frontend/packages/$app_name"
        return 1
    fi
    
    # Create ECR repository
    create_ecr_repo "$app_name"
    
    # Build image
    local image_name
    image_name=$(build_image "$app_name")
    
    # Push image
    push_image "$image_name"
    
    log_success "Completed processing: $app_name"
}

# Main function
main() {
    log_info "Starting build and push process..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Tag: $TAG"
    log_info "AWS Region: $AWS_REGION"
    
    # Check prerequisites
    check_prerequisites
    
    # ECR login
    ecr_login
    
    # Build and push applications
    if [[ "$APP_NAME" == "all" ]]; then
        log_info "Building all applications..."
        for app in "${APPLICATIONS[@]}"; do
            build_and_push_app "$app"
        done
    else
        # Check if specified app is valid
        if [[ ! " ${APPLICATIONS[*]} " =~ " $APP_NAME " ]]; then
            log_error "Invalid application name: $APP_NAME"
            log_info "Valid applications: ${APPLICATIONS[*]}"
            exit 1
        fi
        
        build_and_push_app "$APP_NAME"
    fi
    
    log_success "Build and push process completed successfully!"
}

# Help function
show_help() {
    cat << EOF
Build and Push Docker Images to ECR

Usage: $0 [environment] [app-name] [tag]

Arguments:
  environment    Environment (dev, staging, prod) [default: dev]
  app-name       Application name or 'all' [default: all]
  tag           Docker image tag [default: latest]

Applications:
  ${APPLICATIONS[*]}

Examples:
  $0                           # Build all apps for dev with latest tag
  $0 prod                      # Build all apps for prod with latest tag
  $0 dev viewer-portal         # Build viewer-portal for dev with latest tag
  $0 prod admin-portal v1.0.0  # Build admin-portal for prod with v1.0.0 tag

Environment Variables:
  AWS_REGION     AWS region [default: eu-west-2]
  PROJECT_NAME   Project name [default: streaming-logs]

EOF
}

# Handle help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# Run main function
main "$@"