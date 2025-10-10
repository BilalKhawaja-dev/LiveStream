#!/bin/bash

# Pre-commit hooks for Terraform
# This script runs validation checks before commits

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

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository"
    exit 1
fi

cd "$ROOT_DIR"

log_info "Running pre-commit hooks for Terraform..."

# Get list of changed files
changed_files=$(git diff --cached --name-only --diff-filter=ACM)
terraform_files=$(echo "$changed_files" | grep -E '\.(tf|tfvars)$' || true)

if [ -z "$terraform_files" ]; then
    log_info "No Terraform files changed, skipping validation"
    exit 0
fi

log_info "Changed Terraform files:"
echo "$terraform_files" | sed 's/^/  - /'

# Initialize variables for tracking failures
failed_checks=0
total_checks=0

# 1. Check Terraform formatting
((total_checks++))
log_info "Checking Terraform formatting..."
if terraform fmt -check -recursive; then
    log_success "✓ Terraform formatting is correct"
else
    log_error "✗ Terraform formatting issues found"
    log_info "Run 'terraform fmt -recursive' to fix formatting"
    ((failed_checks++))
fi

# 2. Validate Terraform configuration
((total_checks++))
log_info "Validating Terraform configuration..."
if terraform init -backend=false > /dev/null 2>&1 && terraform validate > /dev/null 2>&1; then
    log_success "✓ Terraform configuration is valid"
else
    log_error "✗ Terraform validation failed"
    terraform validate
    ((failed_checks++))
fi

# 3. Check for sensitive data
((total_checks++))
log_info "Checking for sensitive data..."
sensitive_patterns=(
    "password\s*=\s*\"[^\"]+\""
    "secret\s*=\s*\"[^\"]+\""
    "token\s*=\s*\"[^\"]+\""
    "key\s*=\s*\"[^\"]+\""
    "AKIA[0-9A-Z]{16}"
    "[0-9a-zA-Z/+]{40}"
)

sensitive_found=false
for pattern in "${sensitive_patterns[@]}"; do
    if echo "$terraform_files" | xargs grep -l -E "$pattern" 2>/dev/null; then
        log_error "✗ Potential sensitive data found matching pattern: $pattern"
        sensitive_found=true
    fi
done

if [ "$sensitive_found" = false ]; then
    log_success "✓ No sensitive data patterns detected"
else
    log_error "✗ Sensitive data patterns found - please review"
    ((failed_checks++))
fi

# 4. Check for hardcoded values that should be variables
((total_checks++))
log_info "Checking for hardcoded values..."
hardcoded_patterns=(
    "ami-[0-9a-f]{8,17}"
    "subnet-[0-9a-f]{8,17}"
    "vpc-[0-9a-f]{8,17}"
    "sg-[0-9a-f]{8,17}"
    "[0-9]{12}"  # AWS Account IDs
)

hardcoded_found=false
for pattern in "${hardcoded_patterns[@]}"; do
    if echo "$terraform_files" | xargs grep -l -E "$pattern" 2>/dev/null; then
        log_warning "⚠ Potential hardcoded value found matching pattern: $pattern"
        hardcoded_found=true
    fi
done

if [ "$hardcoded_found" = false ]; then
    log_success "✓ No obvious hardcoded values detected"
else
    log_warning "⚠ Potential hardcoded values found - consider using variables"
    # Don't fail the commit for this, just warn
fi

# 5. Check for TODO/FIXME comments
((total_checks++))
log_info "Checking for TODO/FIXME comments..."
todo_comments=$(echo "$terraform_files" | xargs grep -n -E "(TODO|FIXME|XXX|HACK)" 2>/dev/null || true)

if [ -z "$todo_comments" ]; then
    log_success "✓ No TODO/FIXME comments found"
else
    log_warning "⚠ TODO/FIXME comments found:"
    echo "$todo_comments" | sed 's/^/    /'
    # Don't fail the commit for this, just warn
fi

# 6. Check file sizes
((total_checks++))
log_info "Checking file sizes..."
large_files=$(echo "$terraform_files" | xargs ls -la | awk '$5 > 10240 {print $9 " (" $5 " bytes)"}' || true)

if [ -z "$large_files" ]; then
    log_success "✓ All files are reasonably sized"
else
    log_warning "⚠ Large files detected (>10KB):"
    echo "$large_files" | sed 's/^/    /'
    # Don't fail the commit for this, just warn
fi

# 7. Run tfsec if available
if command -v tfsec &> /dev/null; then
    ((total_checks++))
    log_info "Running security checks with tfsec..."
    if tfsec . --soft-fail > /dev/null 2>&1; then
        log_success "✓ Security checks passed"
    else
        log_warning "⚠ Security issues found - run 'tfsec .' for details"
        # Don't fail the commit for security issues, just warn
    fi
fi

# 8. Run tflint if available
if command -v tflint &> /dev/null; then
    ((total_checks++))
    log_info "Running linting checks with tflint..."
    if tflint --init > /dev/null 2>&1 && tflint > /dev/null 2>&1; then
        log_success "✓ Linting checks passed"
    else
        log_warning "⚠ Linting issues found - run 'tflint' for details"
        # Don't fail the commit for linting issues, just warn
    fi
fi

# Summary
echo ""
log_info "Pre-commit validation summary:"
log_info "  Total checks: $total_checks"
log_info "  Failed checks: $failed_checks"
log_info "  Passed checks: $((total_checks - failed_checks))"

if [ $failed_checks -eq 0 ]; then
    log_success "🎉 All critical checks passed! Commit can proceed."
    exit 0
else
    log_error "❌ $failed_checks critical check(s) failed. Please fix the issues before committing."
    log_info ""
    log_info "Common fixes:"
    log_info "  - Run 'terraform fmt -recursive' to fix formatting"
    log_info "  - Run 'terraform validate' to check configuration"
    log_info "  - Review and remove any sensitive data from files"
    log_info ""
    exit 1
fi