#!/bin/bash

export AWS_DEFAULT_REGION=eu-west-2

echo "=== Fixing and Deploying Remaining Frontend Applications ==="
echo ""

# Applications that need fixing (excluding viewer-portal which already works)
APPS=("creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

# ECR repository base
ECR_REGISTRY="981686514879.dkr.ecr.eu-west-2.amazonaws.com"

echo "🔧 Building and pushing fixed applications..."
echo ""

cd streaming-platform-frontend

for app in "${APPS[@]}"; do
    echo "📦 Building $app..."
    
    # Build the Docker image
    docker build -t "$ECR_REGISTRY/stream-$app:fixed" -f "packages/$app/Dockerfile" .
    
    if [ $? -eq 0 ]; then
        echo "✅ Built $app successfully"
        
        # Push to ECR
        echo "🚀 Pushing $app to ECR..."
        docker push "$ECR_REGISTRY/stream-$app:fixed"
        
        if [ $? -eq 0 ]; then
            echo "✅ Pushed $app successfully"
        else
            echo "❌ Failed to push $app"
        fi
    else
        echo "❌ Failed to build $app"
    fi
    
    echo ""
done

cd ..

echo "🔄 Updating ECS services to use fixed images..."
echo ""

# Update ECS services to use the new images
for app in "${APPS[@]}"; do
    service_name="stream-dev-$app"
    
    echo "Updating service: $service_name"
    
    # Force new deployment
    aws ecs update-service \
        --cluster stream-dev-cluster \
        --service "$service_name" \
        --force-new-deployment \
        --query 'service.{ServiceName:serviceName,Status:status,TaskDefinition:taskDefinition}' \
        --output table
    
    echo ""
done

echo "⏳ Waiting for services to stabilize..."
echo ""

# Wait for services to become stable
for app in "${APPS[@]}"; do
    service_name="stream-dev-$app"
    
    echo "Waiting for $service_name to stabilize..."
    aws ecs wait services-stable --cluster stream-dev-cluster --services "$service_name"
    
    if [ $? -eq 0 ]; then
        echo "✅ $service_name is stable"
    else
        echo "⚠️  $service_name may still be updating"
    fi
done

echo ""
echo "🧪 Testing fixed applications..."
echo ""

# Test the applications
ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

for app in "${APPS[@]}"; do
    echo "Testing $app:"
    
    # Test main path
    status=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/$app/" --connect-timeout 10)
    echo "  /$app/ -> HTTP $status"
    
    # Test assets path
    status_assets=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/$app/assets/index.js" --connect-timeout 10)
    echo "  /$app/assets/* -> HTTP $status_assets"
    
    if [ "$status" = "200" ] && [ "$status_assets" != "404" ]; then
        echo "  ✅ $app is working correctly"
    else
        echo "  ❌ $app still has issues"
    fi
    
    echo ""
done

echo "=== Deployment Complete ==="
echo ""
echo "All applications should now handle ALB path-based routing correctly."
echo "If any applications still show blank pages, check the browser console for JavaScript errors."