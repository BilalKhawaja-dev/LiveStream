#!/bin/bash

echo "🔧 Force cleaning up conflicting AWS resources..."

# Set AWS region from terraform.tfvars
REGION=$(grep 'aws_region' terraform.tfvars | cut -d'"' -f2)
PROJECT=$(grep 'project_name' terraform.tfvars | cut -d'"' -f2)
ENVIRONMENT="dev"

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

echo "🗑️  Force cleaning up specific conflicting resources..."

# 1. Force delete JWT Secret (immediate deletion)
echo "Force deleting JWT Secret..."
SECRET_NAME="${PROJECT}-${ENVIRONMENT}-jwt-secret"
handle_aws_error "aws secretsmanager delete-secret --secret-id $SECRET_NAME --force-delete-without-recovery --region $REGION" "JWT Secret (force delete)"

# 2. Delete IAM Role and its policies
echo "Deleting IAM Role and policies..."
ROLE_NAME="${PROJECT}-${ENVIRONMENT}-presigned-url-generator-role"

# First detach managed policies
handle_aws_error "aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole --region $REGION" "Detach Basic Execution Policy"

# Delete inline policies
handle_aws_error "aws iam delete-role-policy --role-name $ROLE_NAME --policy-name ${PROJECT}-${ENVIRONMENT}-presigned-url-generator-s3-policy --region $REGION" "S3 Policy"

# Delete the role
handle_aws_error "aws iam delete-role --role-name $ROLE_NAME --region $REGION" "Presigned URL Generator Role"

# 3. Delete CloudWatch Log Groups
echo "Deleting CloudWatch Log Groups..."
LOG_GROUP_NAME="/aws/lambda/${PROJECT}-${ENVIRONMENT}-presigned-url-generator"
handle_aws_error "aws logs delete-log-group --log-group-name '$LOG_GROUP_NAME' --region $REGION" "Presigned URL Generator Log Group"

# Also clean up any other potentially conflicting log groups
OTHER_LOG_GROUPS=(
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-video-processor"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-analytics-processor"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-auth-handler"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-streaming-handler"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-support-handler"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-moderation-handler"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-payment-handler"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-content-analyzer"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-moderation-api"
    "/aws/lambda/${PROJECT}-${ENVIRONMENT}-jwt-middleware"
)

for log_group in "${OTHER_LOG_GROUPS[@]}"; do
    handle_aws_error "aws logs delete-log-group --log-group-name '$log_group' --region $REGION" "Log Group: $log_group"
done

# 4. Delete Lambda Functions that might be conflicting
echo "Deleting Lambda Functions..."
LAMBDA_FUNCTIONS=(
    "${PROJECT}-${ENVIRONMENT}-presigned-url-generator"
    "${PROJECT}-${ENVIRONMENT}-video-processor"
    "${PROJECT}-${ENVIRONMENT}-analytics-processor"
    "${PROJECT}-${ENVIRONMENT}-content-analyzer"
    "${PROJECT}-${ENVIRONMENT}-moderation-api"
    "${PROJECT}-${ENVIRONMENT}-jwt-middleware"
    "${PROJECT}-${ENVIRONMENT}-auth-handler"
    "${PROJECT}-${ENVIRONMENT}-streaming-handler"
    "${PROJECT}-${ENVIRONMENT}-support-handler"
    "${PROJECT}-${ENVIRONMENT}-moderation-handler"
)

for func in "${LAMBDA_FUNCTIONS[@]}"; do
    handle_aws_error "aws lambda delete-function --function-name $func --region $REGION" "Lambda Function: $func"
done

# 5. Delete any IAM roles that might conflict
echo "Deleting potentially conflicting IAM roles..."
IAM_ROLES=(
    "${PROJECT}-${ENVIRONMENT}-content-analyzer-role"
    "${PROJECT}-${ENVIRONMENT}-moderation-api-role"
    "${PROJECT}-${ENVIRONMENT}-lambda-analytics-role"
    "${PROJECT}-${ENVIRONMENT}-lambda-auth-role"
    "${PROJECT}-${ENVIRONMENT}-lambda-moderation-role"
    "${PROJECT}-${ENVIRONMENT}-lambda-streaming-role"
    "${PROJECT}-${ENVIRONMENT}-lambda-support-role"
    "${PROJECT}-${ENVIRONMENT}-ecs-task-role"
    "${PROJECT}-${ENVIRONMENT}-ecs-task-execution-role"
)

for role in "${IAM_ROLES[@]}"; do
    # First try to detach any managed policies
    handle_aws_error "aws iam detach-role-policy --role-name $role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole --region $REGION" "Detach VPC Policy from $role"
    handle_aws_error "aws iam detach-role-policy --role-name $role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole --region $REGION" "Detach Basic Policy from $role"
    handle_aws_error "aws iam detach-role-policy --role-name $role --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy --region $REGION" "Detach ECS Policy from $role"
    
    # Delete inline policies (try common names)
    handle_aws_error "aws iam delete-role-policy --role-name $role --policy-name ${role}-policy --region $REGION" "Inline Policy for $role"
    
    # Delete the role
    handle_aws_error "aws iam delete-role --role-name $role --region $REGION" "IAM Role: $role"
done

# 6. Wait for AWS to process deletions
echo "⏳ Waiting for AWS to process deletions..."
sleep 15

echo "✅ Force cleanup completed!"
echo ""
echo "🚀 Now running terraform plan to verify fixes..."

# Run terraform plan to check if conflicts are resolved
terraform plan -var-file=terraform.tfvars

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Terraform plan successful! All conflicts resolved."
    echo "You can now run: terraform apply -var-file=terraform.tfvars"
else
    echo ""
    echo "❌ There are still some issues. Check the plan output above."
    echo "You may need to run: terraform refresh -var-file=terraform.tfvars"
fi