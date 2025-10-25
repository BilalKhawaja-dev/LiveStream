#!/bin/bash

echo "=== DEPLOYING FIXED SERVICES TO ECR ==="
echo "Building, testing locally, then pushing to ECR one by one"
echo

# Services to deploy
SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")
ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

# Function to test service locally
test_service_locally() {
    local service=$1
    echo "=== Testing $service locally ==="
    
    # Build Docker image
    echo "Building Docker image for $service..."
    cd "streaming-platform-frontend/packages/$service"
    docker build -t "test-$service:local" . > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "❌ Docker build failed for $service"
        cd ../../..
        return 1
    fi
    
    # Test container locally
    echo "Testing container locally..."
    docker run -d --name "test-$service" -p 8080:3000 "test-$service:local" > /dev/null 2>&1
    
    # Wait for container to start
    sleep 5
    
    # Test HTML
    html_status=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:8080/$service/")
    echo "HTML status: $html_status"
    
    if [ "$html_status" = "200" ]; then
        # Test assets
        html_content=$(curl -s "http://localhost:8080/$service/")
        js_files=$(echo "$html_content" | grep -o 'src="[^"]*\.js"' | head -1 | sed 's/src="//g' | sed 's/"//g')
        
        if [ -n "$js_files" ]; then
            js_status=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:8080$js_files")
            echo "JS asset status: $js_status"
            
            if [ "$js_status" = "200" ]; then
                echo "✅ $service works locally"
                docker stop "test-$service" > /dev/null 2>&1
                docker rm "test-$service" > /dev/null 2>&1
                cd ../../..
                return 0
            else
                echo "❌ $service JS assets fail locally"
            fi
        else
            echo "❌ No JS assets found in HTML"
        fi
    else
        echo "❌ $service HTML fails locally"
    fi
    
    # Cleanup
    docker stop "test-$service" > /dev/null 2>&1
    docker rm "test-$service" > /dev/null 2>&1
    cd ../../..
    return 1
}

# Function to push service to ECR
push_service_to_ecr() {
    local service=$1
    echo "=== Pushing $service to ECR ==="
    
    cd "streaming-platform-frontend/packages/$service"
    
    # Build for production
    echo "Building $service for production..."
    npm run build > /dev/null 2>&1
    
    # Build Docker image
    timestamp=$(date +%s)
    docker build -t "stream-$service:fixed-$timestamp" . > /dev/null 2>&1
    
    # Tag for ECR
    docker tag "stream-$service:fixed-$timestamp" "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:fixed-$timestamp"
    docker tag "stream-$service:fixed-$timestamp" "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:latest"
    
    # Push to ECR
    echo "Pushing to ECR..."
    docker push "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:fixed-$timestamp" > /dev/null 2>&1
    docker push "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:latest" > /dev/null 2>&1
    
    # Force ECS update
    echo "Updating ECS service..."
    aws ecs update-service \
        --cluster stream-dev-cluster \
        --service "stream-dev-$service" \
        --force-new-deployment \
        --query 'service.[serviceName,status]' \
        --output table > /dev/null 2>&1
    
    cd ../../..
    echo "✅ $service pushed and deployed"
}

# Function to test service on ALB
test_service_on_alb() {
    local service=$1
    echo "=== Testing $service on ALB ==="
    
    # Wait for deployment
    echo "Waiting 45 seconds for deployment..."
    sleep 45
    
    # Test HTML
    html_url="http://$ALB_DNS/$service/"
    html_status=$(curl -s -w "%{http_code}" -o /dev/null "$html_url")
    echo "HTML status: $html_status"
    
    if [ "$html_status" = "200" ]; then
        # Test assets
        html_content=$(curl -s "$html_url")
        js_files=$(echo "$html_content" | grep -o 'src="[^"]*\.js"' | head -1 | sed 's/src="//g' | sed 's/"//g')
        
        if [ -n "$js_files" ]; then
            js_url="http://$ALB_DNS$js_files"
            js_status=$(curl -s -w "%{http_code}" -o /dev/null "$js_url")
            echo "JS asset status: $js_status"
            
            if [ "$js_status" = "200" ]; then
                echo "🎉 $service WORKING ON ALB"
                return 0
            else
                echo "❌ $service JS assets fail on ALB"
                return 1
            fi
        else
            echo "❌ No JS assets found"
            return 1
        fi
    else
        echo "❌ $service HTML fails on ALB"
        return 1
    fi
}

# Main execution
echo "Step 1: ECR Login"
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 992382474575.dkr.ecr.eu-west-2.amazonaws.com

if [ $? -ne 0 ]; then
    echo "❌ ECR login failed. Please configure AWS credentials."
    exit 1
fi

echo
echo "Step 2: Process each service systematically"

SUCCESSFUL_SERVICES=()
FAILED_SERVICES=()

for service in "${SERVICES[@]}"; do
    echo
    echo "=========================================="
    echo "PROCESSING: $service"
    echo "=========================================="
    
    # Test locally first
    if test_service_locally "$service"; then
        echo "✅ $service works locally, pushing to ECR..."
        
        # Push to ECR and deploy
        push_service_to_ecr "$service"
        
        # Test on ALB
        if test_service_on_alb "$service"; then
            echo "🎉 $service FULLY WORKING"
            SUCCESSFUL_SERVICES+=("$service")
        else
            echo "⚠️  $service deployed but still has issues on ALB"
            FAILED_SERVICES+=("$service")
        fi
    else
        echo "❌ $service still broken locally, skipping ECR push"
        FAILED_SERVICES+=("$service")
    fi
    
    echo "=========================================="
done

echo
echo "=== FINAL DEPLOYMENT SUMMARY ==="
echo "✅ SUCCESSFUL SERVICES:"
for service in "${SUCCESSFUL_SERVICES[@]}"; do
    echo "  🎉 $service"
done

echo
echo "❌ FAILED SERVICES:"
for service in "${FAILED_SERVICES[@]}"; do
    echo "  💥 $service"
done

echo
echo "=== FINAL STATUS CHECK ==="
for service in "${SERVICES[@]}"; do
    html_status=$(curl -s -w "%{http_code}" -o /dev/null "http://$ALB_DNS/$service/")
    if [ "$html_status" = "200" ]; then
        html_content=$(curl -s "http://$ALB_DNS/$service/")
        js_files=$(echo "$html_content" | grep -o 'src="[^"]*\.js"' | head -1 | sed 's/src="//g' | sed 's/"//g')
        if [ -n "$js_files" ]; then
            js_url="http://$ALB_DNS$js_files"
            js_status=$(curl -s -w "%{http_code}" -o /dev/null "$js_url")
            if [ "$js_status" = "200" ]; then
                echo "✅ $service: WORKING"
            else
                echo "❌ $service: HTML OK, Assets FAIL"
            fi
        else
            echo "❌ $service: No assets found"
        fi
    else
        echo "❌ $service: HTML FAIL"
    fi
done

echo
echo "=== DEPLOYMENT COMPLETE ==="
if [ ${#SUCCESSFUL_SERVICES[@]} -eq ${#SERVICES[@]} ]; then
    echo "🎉 ALL SERVICES SUCCESSFULLY DEPLOYED!"
    echo "All frontend services should now work correctly!"
else
    echo "⚠️  Some services may need additional attention"
    echo "Check the failed services above for issues"
fi