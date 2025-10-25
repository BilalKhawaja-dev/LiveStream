#!/bin/bash

echo "=== FIXING WHITE PAGE SERVICES ==="
echo "This script will rebuild and redeploy the non-working frontend services"
echo

# Services that need fixing (excluding viewer-portal which works)
BROKEN_SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

# Get AWS account details
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
AWS_REGION=$(aws configure get region 2>/dev/null || echo "eu-west-2")

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    echo "❌ Cannot get AWS Account ID. Please check AWS credentials."
    exit 1
fi

ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
echo "ECR URI: $ECR_URI"
echo "AWS Region: $AWS_REGION"
echo

# Login to ECR
echo "=== 1. LOGGING INTO ECR ==="
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URI"
if [[ $? -ne 0 ]]; then
    echo "❌ ECR login failed"
    exit 1
fi
echo "✅ ECR login successful"
echo

cd streaming-platform-frontend

# Build and push each broken service
for service in "${BROKEN_SERVICES[@]}"; do
    echo "=== 2. REBUILDING $service ==="
    
    # Navigate to service directory
    cd "packages/$service"
    
    # Clean any existing build
    rm -rf dist/
    
    # Build the Docker image
    IMAGE_NAME="stream-$service"
    TAG="fix-$(date +%Y%m%d-%H%M%S)"
    
    echo "Building Docker image: $IMAGE_NAME:$TAG"
    docker build -t "$IMAGE_NAME:$TAG" -f Dockerfile ../../
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Docker build successful for $service"
        
        # Tag for ECR
        docker tag "$IMAGE_NAME:$TAG" "$ECR_URI/$IMAGE_NAME:$TAG"
        docker tag "$IMAGE_NAME:$TAG" "$ECR_URI/$IMAGE_NAME:latest"
        
        # Push to ECR
        echo "Pushing to ECR..."
        docker push "$ECR_URI/$IMAGE_NAME:$TAG"
        docker push "$ECR_URI/$IMAGE_NAME:latest"
        
        if [[ $? -eq 0 ]]; then
            echo "✅ Successfully pushed $service to ECR"
            
            # Update ECS service to use new image
            echo "Updating ECS service..."
            aws ecs update-service \
                --cluster stream-dev-cluster \
                --service "stream-dev-$service" \
                --force-new-deployment \
                --query 'service.serviceName' \
                --output text
            
            if [[ $? -eq 0 ]]; then
                echo "✅ ECS service update initiated for $service"
            else
                echo "❌ Failed to update ECS service for $service"
            fi
        else
            echo "❌ Failed to push $service to ECR"
        fi
    else
        echo "❌ Docker build failed for $service"
    fi
    
    # Go back to frontend root
    cd ../../
    echo
done

cd ..

echo "=== 3. DEPLOYMENT STATUS ==="
echo "All services have been rebuilt and deployment initiated."
echo "Wait 5-10 minutes for deployments to complete."
echo
echo "Monitor deployment progress:"
for service in "${BROKEN_SERVICES[@]}"; do
    echo "aws ecs describe-services --cluster stream-dev-cluster --services stream-dev-$service --query 'services[0].[serviceName,status,runningCount,desiredCount]' --output table"
done
echo
echo "Test endpoints after deployment:"
ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"
for service in "${BROKEN_SERVICES[@]}"; do
    echo "http://$ALB_DNS/$service/"
done