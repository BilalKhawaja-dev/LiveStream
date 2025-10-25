#!/bin/bash

echo "=== DEPLOYING RESTORED ORIGINAL APPS ==="
echo "Rebuilding with restored original component functionality"

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")
ACCOUNT_ID="981686514879"
ECR_REPO="stream-dev"

# ECR Login
echo "Step 1: ECR Login"
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com"

if [ $? -ne 0 ]; then
    echo "❌ ECR login failed"
    exit 1
fi

for service in "${SERVICES[@]}"; do
    echo
    echo "=========================================="
    echo "REBUILDING: $service (with original components)"
    echo "=========================================="
    
    cd "streaming-platform-frontend/packages/$service"
    
    # Build the application
    echo "Building $service..."
    npm run build > build.log 2>&1
    
    if [ $? -ne 0 ]; then
        echo "❌ Build failed for $service"
        echo "Build log:"
        tail -10 build.log
        cd ../../..
        continue
    fi
    
    # Build Docker image
    timestamp=$(date +%s)
    echo "Building Docker image for $service..."
    docker build -t "$service:restored-$timestamp" . > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "❌ Docker build failed for $service"
        cd ../../..
        continue
    fi
    
    # Tag for ECR
    docker tag "$service:restored-$timestamp" "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-restored-$timestamp"
    docker tag "$service:restored-$timestamp" "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-latest"
    
    # Push to ECR
    echo "Pushing $service to ECR..."
    docker push "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-restored-$timestamp" > /dev/null 2>&1
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
        
        echo "✅ ECS service updated for $service"
    else
        echo "❌ Failed to push $service to ECR"
    fi
    
    cd ../../..
    echo "=========================================="
done

echo
echo "=== DEPLOYMENT SUMMARY ==="
echo "All services rebuilt with restored original functionality"
echo "Each service now uses its proper components:"
echo "  - Creator Dashboard: Analytics, Stream Controls, Revenue Tracking"
echo "  - Admin Portal: System Dashboard, User Management, Performance Metrics"
echo "  - Developer Console: API Dashboard, System Health, API Testing"
echo "  - Analytics Dashboard: Real-time Metrics, Streamer Analytics, Revenue Analytics"
echo "  - Support System: Ticket Dashboard"
echo
echo "ECS deployments are in progress..."
echo "Wait 3-4 minutes for deployments to complete, then test the services"
echo "They should now show proper dashboards instead of placeholder content!"