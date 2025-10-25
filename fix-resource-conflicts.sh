#!/bin/bash

# Fix Resource Conflicts Script
# This script handles common Terraform resource conflicts during deployment

set -e

echo "🔧 Fixing Terraform resource conflicts..."

# Function to check if AWS CLI is available
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
}

# Function to force delete secrets that are scheduled for deletion
fix_secrets_manager() {
    echo "🔐 Checking Secrets Manager conflicts..."
    
    # List of secrets that might be scheduled for deletion
    SECRETS=(
        "stream-dev-jwt-secret"
        "stream-dev-aurora-master-password"
        "stream-dev-stripe-secret-key"
    )
    
    for secret in "${SECRETS[@]}"; do
        echo "Checking secret: $secret"
        
        # Check if secret exists and is scheduled for deletion
        if aws secretsmanager describe-secret --secret-id "$secret" --query 'DeletedDate' --output text 2>/dev/null | grep -q "None"; then
            echo "✅ Secret $secret is active, no action needed"
        elif aws secretsmanager describe-secret --secret-id "$secret" 2>/dev/null; then
            echo "🗑️ Secret $secret is scheduled for deletion, forcing immediate deletion..."
            aws secretsmanager delete-secret --secret-id "$secret" --force-delete-without-recovery || true
            echo "✅ Forced deletion of $secret"
        else
            echo "✅ Secret $secret doesn't exist, no action needed"
        fi
    done
}

# Function to remove conflicting IAM roles
fix_iam_roles() {
    echo "👤 Checking IAM role conflicts..."
    
    # List of roles that might conflict
    ROLES=(
        "stream-dev-presigned-url-generator-role"
        "stream-dev-media-processor-role"
        "stream-dev-video-processor-role"
    )
    
    for role in "${ROLES[@]}"; do
        echo "Checking role: $role"
        
        if aws iam get-role --role-name "$role" 2>/dev/null; then
            echo "🗑️ Role $role exists, removing..."
            
            # Detach all policies first
            echo "Detaching policies from $role..."
            aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text | while read -r policy_arn; do
                if [ -n "$policy_arn" ] && [ "$policy_arn" != "None" ]; then
                    aws iam detach-role-policy --role-name "$role" --policy-arn "$policy_arn" || true
                fi
            done
            
            # Delete inline policies
            aws iam list-role-policies --role-name "$role" --query 'PolicyNames' --output text | while read -r policy_name; do
                if [ -n "$policy_name" ] && [ "$policy_name" != "None" ]; then
                    aws iam delete-role-policy --role-name "$role" --policy-name "$policy_name" || true
                fi
            done
            
            # Delete the role
            aws iam delete-role --role-name "$role" || true
            echo "✅ Removed role $role"
        else
            echo "✅ Role $role doesn't exist, no action needed"
        fi
    done
}

# Function to remove conflicting CloudWatch log groups
fix_cloudwatch_logs() {
    echo "📊 Checking CloudWatch log group conflicts..."
    
    # List of log groups that might conflict
    LOG_GROUPS=(
        "/aws/lambda/stream-dev-presigned-url-generator"
        "/aws/lambda/stream-dev-media-processor"
        "/aws/lambda/stream-dev-video-processor"
        "/aws/lambda/stream-dev-auth-handler"
        "/aws/lambda/stream-dev-streaming-handler"
    )
    
    for log_group in "${LOG_GROUPS[@]}"; do
        echo "Checking log group: $log_group"
        
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
            echo "🗑️ Log group $log_group exists, removing..."
            aws logs delete-log-group --log-group-name "$log_group" || true
            echo "✅ Removed log group $log_group"
        else
            echo "✅ Log group $log_group doesn't exist, no action needed"
        fi
    done
}

# Function to clean up Lambda functions that might conflict
fix_lambda_functions() {
    echo "⚡ Checking Lambda function conflicts..."
    
    # List of functions that might conflict
    FUNCTIONS=(
        "stream-dev-presigned-url-generator"
        "stream-dev-media-processor"
        "stream-dev-video-processor"
    )
    
    for function in "${FUNCTIONS[@]}"; do
        echo "Checking function: $function"
        
        if aws lambda get-function --function-name "$function" 2>/dev/null; then
            echo "🗑️ Function $function exists, removing..."
            aws lambda delete-function --function-name "$function" || true
            echo "✅ Removed function $function"
        else
            echo "✅ Function $function doesn't exist, no action needed"
        fi
    done
}

# Main execution
main() {
    echo "🚀 Starting resource conflict resolution..."
    
    check_aws_cli
    
    echo "Current AWS identity:"
    aws sts get-caller-identity
    
    echo ""
    echo "⚠️  This script will remove conflicting AWS resources."
    echo "Make sure you're working in the correct AWS account and region."
    echo ""
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted by user"
        exit 1
    fi
    
    fix_secrets_manager
    echo ""
    
    fix_iam_roles
    echo ""
    
    fix_cloudwatch_logs
    echo ""
    
    fix_lambda_functions
    echo ""
    
    echo "✅ Resource conflict resolution completed!"
    echo ""
    echo "You can now run 'terraform apply' to deploy your infrastructure."
    echo "If you still encounter conflicts, wait a few minutes for AWS to propagate the deletions."
}

# Run main function
main "$@"