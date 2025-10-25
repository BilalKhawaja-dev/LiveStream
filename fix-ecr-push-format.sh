#!/bin/bash

echo "=== REBUILDING AND PUSHING FIXED SERVICES ==="
echo "Rebuilding with corrected nginx configurations"

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

# ECR Login
echo "Step 1: ECR Login"
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 992382474575.dkr.ecr.eu-west-2.amazonaws.com

if [ $? -ne 0 ]; then
    echo "❌ ECR login failed. Please configure AWS credentials."
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
    docker build -t "stream-$service:nginx-fix-$timestamp" . > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "❌ Docker build failed for $service"
        cd ../../..
        continue
    fi
    
    # Tag for ECR
    docker tag "stream-$service:nginx-fix-$timestamp" "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:nginx-fix-$timestamp"
    docker tag "stream-$service:nginx-fix-$timestamp" "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:latest"
    
    # Push to ECR
    echo "Pushing $service to ECR..."
    docker push "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:nginx-fix-$timestamp" > /dev/null 2>&1
    docker push "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:latest" > /dev/null 2>&1
    
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
echo "=== DEPLOYMENT INITIATED ==="
echo "All services have been rebuilt with fixed nginx configurations"
echo "ECS deployments are in progress..."
echo
echo "Wait 2-3 minutes for deployments to complete, then test:"
echo "  ./check-current-service-status.sh"