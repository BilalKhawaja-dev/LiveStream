#!/bin/bash

# Quick validation script to check Terraform syntax
# This script validates the Terraform configuration after fixes

set -e

# Configuration
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

cd "$ROOT_DIR"

log_info "Running Terraform validation checks..."

# 1. Check Terraform formatting
log_info "Checking Terraform formatting..."
if terraform fmt -check -recursive; then
    log_success "✓ Terraform formatting is correct"
else
    log_warning "⚠ Formatting issues found, running terraform fmt..."
    terraform fmt -recursive
    log_success "✓ Formatting fixed"
fi

# 2. Validate Terraform configuration
log_info "Validating Terraform configuration..."
if terraform init -backend=false > /dev/null 2>&1; then
    log_success "✓ Terraform initialization successful"
else
    log_error "✗ Terraform initialization failed"
    terraform init -backend=false
    exit 1
fi

if terraform validate; then
    log_success "✓ Terraform configuration is valid"
else
    log_error "✗ Terraform validation failed"
    exit 1
fi

# 3. Validate individual modules
log_info "Validating individual modules..."
for module_dir in modules/*/; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        log_info "Validating module: $module_name"
        
        cd "$module_dir"
        if terraform init -backend=false > /dev/null 2>&1 && terraform validate > /dev/null 2>&1; then
            log_success "✓ Module $module_name is valid"
        else
            log_error "✗ Module $module_name validation failed"
            cd "$ROOT_DIR"
            exit 1
        fi
        cd "$ROOT_DIR"
    fi
done

log_success "🎉 All Terraform validation checks passed!"
log_info "The configuration is ready for deployment."

# 4. Quick syntax check with terraform init
log_info "Running final syntax validation..."
if terraform init -backend=false > /dev/null 2>&1; then
    log_success "✓ Final validation passed - no duplicate resources or syntax errors"
else
    log_error "✗ Final validation failed"
    terraform init -backend=false
    exit 1
fi

echo ""
log_info "Next steps:"
echo "  1. Copy environment variables: cp environments/dev/terraform.tfvars terraform.tfvars"
echo "  2. Initialize Terraform: terraform init"
echo "  3. Create workspace: terraform workspace new dev"
echo "  4. Plan deployment: terraform plan -var-file=terraform.tfvars"
echo "  5. Apply changes: terraform apply -var-file=terraform.tfvars"
echo ""
log_info "Or use the Makefile for simplified commands:"
echo "  make init ENV=dev"
echo "  make plan ENV=dev"
echo "  make apply ENV=dev"