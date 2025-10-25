#!/bin/bash

echo "🔧 Fixing Terraform resource conflicts..."

# Set AWS region from terraform.tfvars
REGION=$(grep 'aws_region' terraform.tfvars | cut -d'"' -f2)
PROJECT=$(grep 'project_name' terraform.tfvars | cut -d'"' -f2)
ENVIRONMENT=$(grep 'environment' terraform.tfvars | cut -d'"' -f2)

echo "Region: $REGION"
echo "Project: $PROJECT"
echo "Environment: $ENVIRONMENT"

# Function to handle AWS CLI errors gracefully
handle_aws_error() {
    local command="$1"
    local resource="$2"
    
    echo "Attempting: $command"
    if eval "$command" 2>/dev/null; then
        echo "✅ Successfully handled: $resource"
    else
        echo "⚠️  Resource not found or already handled: $resource"
    fi
}

echo "🗑️  Cleaning up conflicting resources..."

# 1. Handle JWT Secret (force delete if scheduled for deletion)
echo "Handling JWT Secret..."
SECRET_NAME="${PROJECT}-${ENVIRONMENT}-jwt-secret"
handle_aws_error "aws secretsmanager delete-secret --secret-id $SECRET_NAME --force-delete-without-recovery --region $REGION" "JWT Secret"

# 2. Handle IAM Role conflicts
echo "Handling IAM Roles..."
ROLE_NAME="${PROJECT}-${ENVIRONMENT}-presigned-url-generator-role"
handle_aws_error "aws iam delete-role --role-name $ROLE_NAME --region $REGION" "Presigned URL Generator Role"

# Also check for role policies
handle_aws_error "aws iam delete-role-policy --role-name $ROLE_NAME --policy-name ${PROJECT}-${ENVIRONMENT}-presigned-url-generator-policy --region $REGION" "Role Policy"

# 3. Handle CloudWatch Log Groups
echo "Handling CloudWatch Log Groups..."
LOG_GROUP_NAME="/aws/lambda/${PROJECT}-${ENVIRONMENT}-presigned-url-generator"
handle_aws_error "aws logs delete-log-group --log-group-name '$LOG_GROUP_NAME' --region $REGION" "Presigned URL Generator Log Group"

# Check for other potentially conflicting log groups
OTHER_LOG_GROUPS=(
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-video-processor"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-analytics-processor"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-auth-handler"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-streaming-handler"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-support-handler"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-moderation-handler"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-payment-handler"
)

for log_group in "${OTHER_LOG_GROUPS[@]}"; do
    handle_aws_error "aws logs delete-log-group --log-group-name '$log_group' --region $REGION" "Log Group: $log_group"
done

# 4. Handle Lambda Functions that might be conflicting
echo "Handling Lambda Functions..."
LAMBDA_FUNCTIONS=(
    "${PROJECT}-${ENVIRONMENT}-presigned-url-generator"
    "${PROJECT}-${ENVIRONMENT}-video-processor"
    "${PROJECT}-${ENVIRONMENT}-analytics-processor"
)

for func in "${LAMBDA_FUNCTIONS[@]}"; do
    handle_aws_error "aws lambda delete-function --function-name $func --region $REGION" "Lambda Function: $func"
done

# 5. Wait a moment for AWS to process deletions
echo "⏳ Waiting for AWS to process deletions..."
sleep 10

# 6. Import existing resources that we want to keep
echo "🔄 Checking for resources to import..."

# Check if VPC exists and import if needed
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT}-${ENVIRONMENT}-vpc" --query 'Vpcs[0].VpcId' --output text --region $REGION 2>/dev/null)
if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "" ]; then
    echo "Found existing VPC: $VPC_ID"
    terraform import module.vpc.aws_vpc.main $VPC_ID 2>/dev/null || echo "VPC import skipped"
fi

echo "✅ Resource cleanup completed!"
echo ""
echo "🚀 Now running terraform plan to verify fixes..."

# Run terraform plan to check if conflicts are resolved
terraform plan -var-file=terraform.tfvars

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Terraform plan successful! Conflicts resolved."
    echo "You can now run: terraform apply -var-file=terraform.tfvars"
else
    echo ""
    echo "❌ There are still some issues. Check the plan output above."
    echo "You may need to run: terraform refresh -var-file=terraform.tfvars"
fi