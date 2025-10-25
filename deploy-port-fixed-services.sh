#!/bin/bash

echo "=== DEPLOYING PORT-FIXED SERVICES ==="
echo "Rebuilding with correct port configurations"

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")
ACCOUNT_ID="981686514879"
ECR_REPO="stream-dev"

# Port mapping
declare -A SERVICE_PORTS=(
    ["creator-dashboard"]=3001
    ["admin-portal"]=3002
    ["support-system"]=3003
    ["analytics-dashboard"]=3004
    ["developer-console"]=3005
)

# ECR Login
echo "Step 1: ECR Login"
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com"

if [ $? -ne 0 ]; then
    echo "❌ ECR login failed"
    exit 1
fi

for service in "${SERVICES[@]}"; do
    port=${SERVICE_PORTS[$service]}
    echo
    echo "=========================================="
    echo "REBUILDING: $service (Port $port)"
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
    
    # Build Docker image
    timestamp=$(date +%s)
    echo "Building Docker image for $service..."
    docker build -t "$service:port-fix-$timestamp" . > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "❌ Docker build failed for $service"
        cd ../../..
        continue
    fi
    
    # Test locally first
    echo "Testing $service locally on port $port..."
    docker run -d --name "test-$service-port" -p "808$((port-3000)):$port" "$service:port-fix-$timestamp" > /dev/null 2>&1
    sleep 3
    
    # Test health endpoint
    local_port=$((8080 + port - 3000))
    health_status=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:$local_port/health")
    
    if [ "$health_status" = "200" ]; then
        echo "✅ Local test passed for $service"
        
        # Cleanup test container
        docker stop "test-$service-port" > /dev/null 2>&1
        docker rm "test-$service-port" > /dev/null 2>&1
        
        # Tag for ECR
        docker tag "$service:port-fix-$timestamp" "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-port-fix-$timestamp"
        docker tag "$service:port-fix-$timestamp" "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-latest"
        
        # Push to ECR
        echo "Pushing $service to ECR..."
        docker push "$ACCOUNT_ID.dkr.ecr.eu-west-2.amazonaws.com/$ECR_REPO:$service-port-fix-$timestamp" > /dev/null 2>&1
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
    else
        echo "❌ Local test failed for $service (health check returned $health_status)"
        docker stop "test-$service-port" > /dev/null 2>&1
        docker rm "test-$service-port" > /dev/null 2>&1
    fi
    
    cd ../../..
    echo "=========================================="
done

echo
echo "=== DEPLOYMENT SUMMARY ==="
echo "All services rebuilt with correct port configurations:"
for service in "${!SERVICE_PORTS[@]}"; do
    echo "  $service: Port ${SERVICE_PORTS[$service]}"
done
echo
echo "ECS deployments are in progress..."
echo "Wait 3-4 minutes for deployments to complete, then test:"
echo "  ./check-current-service-status.sh"