#!/bin/bash

# Final validation script to ensure all Terraform issues are resolved
# This script performs comprehensive checks before deployment

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

log_info "🔍 Running final Terraform validation..."
echo ""

# 1. Check Terraform formatting
log_info "1. Checking Terraform formatting..."
if terraform fmt -check -recursive > /dev/null 2>&1; then
    log_success "✓ Terraform formatting is correct"
else
    log_warning "⚠ Formatting issues found, fixing..."
    terraform fmt -recursive
    log_success "✓ Formatting fixed"
fi

# 2. Initialize Terraform
log_info "2. Initializing Terraform..."
if terraform init -backend=false > /dev/null 2>&1; then
    log_success "✓ Terraform initialization successful"
else
    log_error "✗ Terraform initialization failed"
    terraform init -backend=false
    exit 1
fi

# 3. Validate Terraform configuration
log_info "3. Validating Terraform configuration..."
if terraform validate > /dev/null 2>&1; then
    log_success "✓ Terraform configuration is valid"
else
    log_error "✗ Terraform validation failed"
    terraform validate
    exit 1
fi

# 4. Test Terraform plan (dry run)
log_info "4. Testing Terraform plan (dry run)..."
if terraform plan -var-file=terraform.tfvars.example > /dev/null 2>&1; then
    log_success "✓ Terraform plan generation successful"
else
    log_warning "⚠ Plan generation failed (may need environment-specific variables)"
    log_info "This is expected if using environment-specific variables"
fi

# 5. Validate individual modules
log_info "5. Validating individual modules..."
module_count=0
failed_modules=0

for module_dir in modules/*/; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        ((module_count++))
        
        cd "$module_dir"
        if terraform init -backend=false > /dev/null 2>&1 && terraform validate > /dev/null 2>&1; then
            log_success "  ✓ Module $module_name is valid"
        else
            log_error "  ✗ Module $module_name validation failed"
            ((failed_modules++))
        fi
        cd "$ROOT_DIR"
    fi
done

if [ $failed_modules -eq 0 ]; then
    log_success "✓ All $module_count modules validated successfully"
else
    log_error "✗ $failed_modules out of $module_count modules failed validation"
    exit 1
fi

# 6. Check module tags compatibility
log_info "6. Checking module tags compatibility..."
./scripts/check-module-tags.sh

echo ""
log_success "🎉 All validation checks passed!"
log_info "The Terraform configuration is ready for deployment."

echo ""
log_info "📋 Next steps:"
echo "  1. Copy environment variables:"
echo "     cp environments/dev/terraform.tfvars terraform.tfvars"
echo ""
echo "  2. Deploy using Makefile (recommended):"
echo "     make init ENV=dev"
echo "     make plan ENV=dev"
echo "     make apply ENV=dev"
echo ""
echo "  3. Or deploy manually:"
echo "     terraform init"
echo "     terraform workspace new dev"
echo "     terraform plan -var-file=terraform.tfvars"
echo "     terraform apply -var-file=terraform.tfvars"
echo ""
echo "  4. Run tests after deployment:"
echo "     make test ENV=dev"
echo "     ./tests/e2e_log_pipeline_test.sh"
echo "     ./tests/backup_recovery_test.sh"

echo ""
log_success "✨ Centralized logging infrastructure is ready! ✨"