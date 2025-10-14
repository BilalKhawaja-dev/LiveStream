#!/bin/bash

# Comprehensive Security Scan Script
# This script performs a complete security audit of the streaming platform

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_FILE="$ROOT_DIR/SECURITY_SCAN_REPORT_$(date +%Y%m%d_%H%M%S).md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_CHECKS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_CHECKS++))
}

# Initialize report
init_report() {
    cat > "$REPORT_FILE" << EOF
# 🔒 Comprehensive Security Scan Report

**Date**: $(date)
**Scan Duration**: [TO BE UPDATED]
**Total Checks**: [TO BE UPDATED]

## 📋 Executive Summary

[TO BE UPDATED]

## 🔍 Detailed Findings

EOF
}

# Check for script injection vulnerabilities
check_script_injection() {
    log_info "Checking for script injection vulnerabilities..."
    ((TOTAL_CHECKS++))
    
    local issues=0
    
    # Check GitHub Actions workflows
    if grep -r "github\\.event\\." "$ROOT_DIR/.github/workflows/" | grep -v "allowedEnvironments\\|validation"; then
        log_error "Potential script injection in GitHub Actions workflows"
        ((issues++))
    fi
    
    # Check shell scripts for unsafe variable usage
    if find "$ROOT_DIR/scripts" -name "*.sh" -exec grep -l '\$[A-Z_]*[^}]' {} \; | head -5; then
        log_warning "Shell scripts may have unquoted variables"
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "No script injection vulnerabilities found"
    fi
}

# Check for log injection vulnerabilities
check_log_injection() {
    log_info "Checking for log injection vulnerabilities..."
    ((TOTAL_CHECKS++))
    
    local issues=0
    
    # Check for unsafe console logging
    if find "$ROOT_DIR/streaming-platform-frontend" -name "*.tsx" -o -name "*.ts" | xargs grep -l "console\\." | head -5; then
        # Check if they're using secure logging
        if ! grep -r "secureLogger" "$ROOT_DIR/streaming-platform-frontend/packages/shared/src/utils/"; then
            log_error "Unsafe console logging found without secure logger"
            ((issues++))
        else
            log_success "Secure logging implementation found"
        fi
    else
        log_success "No unsafe console logging found"
    fi
}

# Check for path traversal vulnerabilities
check_path_traversal() {
    log_info "Checking for path traversal vulnerabilities..."
    ((TOTAL_CHECKS++))
    
    local issues=0
    
    # Check for unsafe path handling
    if find "$ROOT_DIR/streaming-platform-frontend" -name "*.tsx" -o -name "*.ts" | xargs grep -l "error\\.stack\\|componentStack" | head -5; then
        # Check if paths are sanitized
        if grep -r "sanitizePath\\|replace.*\\\\\\\\" "$ROOT_DIR/streaming-platform-frontend/packages/ui/src/components/ErrorBoundary/"; then
            log_success "Path sanitization found in ErrorBoundary"
        else
            log_error "Potential path traversal vulnerability in error handling"
            ((issues++))
        fi
    else
        log_success "No path traversal vulnerabilities found"
    fi
}

# Check S3 bucket naming security
check_s3_security() {
    log_info "Checking S3 bucket naming security..."
    ((TOTAL_CHECKS++))
    
    local issues=0
    
    # Check for hardcoded bucket names
    if find "$ROOT_DIR" -name "*.tf" | xargs grep -l "bucket.*=" | xargs grep "bucket.*=" | grep -v "account_id\\|random_id"; then
        log_warning "Some bucket names may not include account ID suffix"
    fi
    
    # Check documentation for hardcoded names
    if find "$ROOT_DIR/docs" -name "*.md" | xargs grep -l "streaming-logs-" | head -3; then
        log_warning "Documentation contains hardcoded resource names"
    fi
    
    # Check if buckets use account ID
    if find "$ROOT_DIR/modules/storage" -name "*.tf" | xargs grep "account_id"; then
        log_success "S3 buckets use account ID suffix"
    else
        log_error "S3 buckets may be vulnerable to bucket sniping"
        ((issues++))
    fi
}

# Check Terraform security
check_terraform_security() {
    log_info "Checking Terraform security configurations..."
    ((TOTAL_CHECKS++))
    
    cd "$ROOT_DIR"
    
    # Check for terraform validation
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        log_success "Terraform formatting is correct"
    else
        log_error "Terraform formatting issues found"
    fi
    
    # Check for security configurations
    if grep -r "enable_deletion_protection.*true" modules/; then
        log_success "Deletion protection enabled"
    else
        log_warning "Some resources may not have deletion protection"
    fi
    
    # Check for encryption
    if grep -r "kms_key\\|encryption" modules/ | head -5 > /dev/null; then
        log_success "Encryption configurations found"
    else
        log_warning "Encryption may not be properly configured"
    fi
}

# Check shell script security
check_shell_security() {
    log_info "Checking shell script security..."
    ((TOTAL_CHECKS++))
    
    local issues=0
    
    # Check for set -e usage
    if find "$ROOT_DIR/scripts" -name "*.sh" | xargs grep -L "set -e"; then
        log_warning "Some scripts don't use 'set -e' for error handling"
    fi
    
    # Check for proper error handling
    if find "$ROOT_DIR/scripts" -name "*.sh" | xargs grep -l "terraform.*apply" | xargs grep -L "if.*terraform"; then
        log_warning "Some scripts may have inadequate error handling"
    fi
    
    # Check for executable permissions
    if find "$ROOT_DIR/scripts" -name "*.sh" ! -executable; then
        log_error "Some scripts are not executable"
        ((issues++))
    else
        log_success "All scripts have proper permissions"
    fi
}

# Check authentication and authorization
check_auth_security() {
    log_info "Checking authentication and authorization..."
    ((TOTAL_CHECKS++))
    
    # Check for IAM configurations
    if find "$ROOT_DIR/modules/iam" -name "*.tf" | xargs grep -l "aws_iam_role\\|aws_iam_policy"; then
        log_success "IAM configurations found"
    else
        log_error "IAM configurations missing"
    fi
    
    # Check for Lambda function URLs with authentication
    if find "$ROOT_DIR/modules" -name "*.tf" | xargs grep -l "aws_lambda_function_url"; then
        if find "$ROOT_DIR/modules" -name "*.tf" | xargs grep "authorization_type.*AWS_IAM"; then
            log_success "Lambda function URLs use IAM authentication"
        else
            log_error "Lambda function URLs may lack proper authentication"
        fi
    fi
}

# Generate final report
generate_report() {
    local scan_duration=$1
    
    cat >> "$REPORT_FILE" << EOF

## 📊 Scan Results Summary

| Category | Status |
|----------|--------|
| **Total Checks** | $TOTAL_CHECKS |
| **Passed** | $PASSED_CHECKS |
| **Failed** | $FAILED_CHECKS |
| **Warnings** | $WARNINGS |
| **Success Rate** | $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))% |

## 🎯 Security Score

EOF

    local score=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    
    if [ $score -ge 90 ]; then
        echo "**Security Score: $score/100 - EXCELLENT** ✅" >> "$REPORT_FILE"
    elif [ $score -ge 80 ]; then
        echo "**Security Score: $score/100 - GOOD** ⚠️" >> "$REPORT_FILE"
    elif [ $score -ge 70 ]; then
        echo "**Security Score: $score/100 - FAIR** ⚠️" >> "$REPORT_FILE"
    else
        echo "**Security Score: $score/100 - POOR** ❌" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF

## 🚀 Recommendations

### Immediate Actions Required
- Address all FAILED checks immediately
- Review and resolve WARNING items
- Implement additional security measures as needed

### Long-term Improvements
- Regular security audits (monthly)
- Automated security scanning in CI/CD
- Security training for development team
- Penetration testing (quarterly)

---

**Report Generated**: $(date)
**Scan Duration**: ${scan_duration}s
**Next Scan Recommended**: $(date -d '+1 month')

EOF
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    log_info "Starting comprehensive security scan..."
    log_info "Report will be saved to: $REPORT_FILE"
    
    init_report
    
    # Run all security checks
    check_script_injection
    check_log_injection
    check_path_traversal
    check_s3_security
    check_terraform_security
    check_shell_security
    check_auth_security
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Generate final report
    generate_report $duration
    
    # Update report header
    sed -i "s/\\[TO BE UPDATED\\].*Scan Duration.*/Scan Duration: ${duration}s/" "$REPORT_FILE"
    sed -i "s/\\[TO BE UPDATED\\].*Total Checks.*/Total Checks: $TOTAL_CHECKS/" "$REPORT_FILE"
    
    # Summary
    echo ""
    log_info "Security scan completed in ${duration}s"
    log_info "Report saved to: $REPORT_FILE"
    echo ""
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        log_success "✅ All critical security checks passed!"
        echo -e "${GREEN}Security Status: APPROVED FOR PRODUCTION${NC}"
    else
        log_error "❌ $FAILED_CHECKS critical security issues found"
        echo -e "${RED}Security Status: REQUIRES IMMEDIATE ATTENTION${NC}"
        exit 1
    fi
    
    echo ""
    echo "📊 Final Score: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))/100"
    echo "📋 Passed: $PASSED_CHECKS | Failed: $FAILED_CHECKS | Warnings: $WARNINGS"
}

# Run main function
main "$@"