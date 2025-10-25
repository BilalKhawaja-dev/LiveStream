#!/bin/bash

echo "=== DEPLOYING NGINX-FIXED SERVICES ==="
echo "Using correct ECR repository and account"

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")
ACCOUNT_ID="981686514879"
ECR_REPO="stream-dev"

# ECR Login
echo "Step 1: ECR Login to account $ACCOUNT_ID"
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com"

if [ $? -ne 0 ]; then
    echo "❌ ECR login failed"
    exit 1
fi

for service in "${SERVICES[@]}"; do
    echo
    echo "=========================================="
    echo "REBUILDING: $service"
    echo "=========================================="
    
    cd "streaming-platform-frontend/packages/$service"
    
    # Build the application
    echo "Building $service..."
    npm run build > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "❌ Build failed for $service"
        cd ../../..
        continue
    fi
    
    # Build Docker image with timestamp
    timestamp=$(date +%s)
    echo "Building Docker image for $service..."
    docker build -t "$service:nginx-fix-$timestamp" . > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "❌ Docker build failed for $service"
        cd ../../..
        continue
    fi
    
    # Tag for ECR with correct repository and tag format
    docker tag "$service:nginx-fix-$timestamp" "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-nginx-fix-$timestamp"
    docker tag "$service:nginx-fix-$timestamp" "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-latest"
    
    # Push to ECR
    echo "Pushing $service to ECR..."
    docker push "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-nginx-fix-$timestamp" > /dev/null 2>&1
    docker push "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-latest" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ $service pushed to ECR successfully"
        
        # Force ECS update
        echo "Updating ECS service for $service..."
        aws ecs update-service \
            --cluster stream-dev-cluster \
            --service "stream-dev-$service" \
            --force-new-deployment \
            --query 'service.[serviceName,status]' \
            --output table > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo "✅ ECS service updated for $service"
        else
            echo "⚠️  ECS service update may have failed for $service"
        fi
    else
        echo "❌ Failed to push $service to ECR"
    fi
    
    cd ../../..
    echo "=========================================="
done

echo
echo "=== DEPLOYMENT SUMMARY ==="
echo "All services have been rebuilt with fixed nginx configurations"
echo "ECS deployments are in progress..."
echo
echo "Wait 2-3 minutes for deployments to complete, then test:"
echo "  ./check-current-service-status.sh"
echo
echo "The key fix applied:"
echo "  - Fixed nginx asset path matching: location ~ ^/\$service/assets/(.*)\$ {"
echo "  - This matches the working viewer-portal pattern"
echo "  - Should resolve the 404 asset errors"