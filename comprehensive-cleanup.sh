#!/bin/bash
echo "🧹 Comprehensive cleanup of ALL conflicting AWS resources..."

# Function to check if command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ Failed: $1"
    fi
}

# 1. Delete the presigned URL generator IAM role (with all policies)
echo "👤 Cleaning up presigned URL generator IAM role..."
# List and detach managed policies
aws iam list-attached-role-policies \
    --role-name "stream-dev-presigned-url-generator-role" \
    --query 'AttachedPolicies[].PolicyArn' \
    --output text 2>/dev/null | xargs -I {} aws iam detach-role-policy \
    --role-name "stream-dev-presigned-url-generator-role" \
    --policy-arn {} 2>/dev/null

# Delete inline policies
aws iam list-role-policies \
    --role-name "stream-dev-presigned-url-generator-role" \
    --query 'PolicyNames[]' \
    --output text 2>/dev/null | xargs -I {} aws iam delete-role-policy \
    --role-name "stream-dev-presigned-url-generator-role" \
    --policy-name {} 2>/dev/null

# Delete the role
aws iam delete-role \
    --role-name "stream-dev-presigned-url-generator-role" 2>/dev/null
check_success "Presigned URL generator IAM role deletion"

# 2. Delete the presigned URL generator CloudWatch log group
echo "📊 Deleting presigned URL generator CloudWatch log group..."
aws logs delete-log-group \
    --log-group-name "/aws/lambda/stream-dev-presigned-url-generator" \
    --region us-east-1 2>/dev/null
check_success "Presigned URL generator CloudWatch log group deletion"

# 3. Check for and clean up any other potential conflicts
echo "🔍 Checking for other potential conflicts..."

# Check for Lambda functions that might conflict
echo "Lambda functions with stream-dev-presigned-url-generator:"
aws lambda list-functions \
    --region us-east-1 \
    --query 'Functions[?contains(FunctionName, `stream-dev-presigned-url-generator`)].FunctionName' \
    --output table

# Delete the Lambda function if it exists
aws lambda delete-function \
    --function-name "stream-dev-presigned-url-generator" \
    --region us-east-1 2>/dev/null
check_success "Lambda function deletion (if existed)"

# 4. Check for any remaining secrets
echo "🔐 Checking for any remaining secrets..."
aws secretsmanager list-secrets \
    --region us-east-1 \
    --query 'SecretList[?contains(Name, `stream-dev`)].Name' \
    --output table

# 5. Check for any other IAM roles that might conflict
echo "👥 Checking for other potentially conflicting IAM roles..."
aws iam list-roles \
    --query 'Roles[?contains(RoleName, `stream-dev-presigned`)].RoleName' \
    --output table

# 6. Check for any other log groups that might conflict
echo "📋 Checking for other potentially conflicting log groups..."
aws logs describe-log-groups \
    --log-group-name-prefix "/aws/lambda/stream-dev-presigned" \
    --region us-east-1 \
    --output table

echo "🎯 Comprehensive cleanup completed!"
echo "You can now retry: terraform apply -var-file=terraform.tfvars -auto-approve"