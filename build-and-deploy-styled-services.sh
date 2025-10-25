#!/bin/bash

echo "🎨 Building and deploying properly styled frontend services..."

cd streaming-platform-frontend

# Services that should work now
WORKING_SERVICES=("admin-portal" "developer-console" "analytics-dashboard")
FIXED_SERVICES=("creator-dashboard" "support-system")

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "🔧 First, let's test the builds locally..."

for SERVICE in "${WORKING_SERVICES[@]}" "${FIXED_SERVICES[@]}"; do
    echo "🔨 Testing build for $SERVICE..."
    cd "packages/$SERVICE"
    
    npm run build
    
    if [ $? -eq 0 ]; then
        echo "✅ $SERVICE builds successfully"
        
        # Check CSS generation
        if [ -d "dist/assets" ]; then
            CSS_COUNT=$(find dist/assets -name "*.css" | wc -l)
            JS_COUNT=$(find dist/assets -name "*.js" | wc -l)
            echo "📄 Generated $CSS_COUNT CSS files and $JS_COUNT JS files"
            
            if [ $CSS_COUNT -gt 0 ]; then
                echo "🎨 CSS files found - styling should work!"
                find dist/assets -name "*.css" -exec ls -lh {} \; | awk '{print "  " $9 " (" $5 ")"}'
            else
                echo "⚠️  No CSS files generated - may have styling issues"
            fi
        fi
    else
        echo "❌ $SERVICE build failed"
    fi
    
    cd ../..
    echo ""
done

echo "🐳 Building Docker images with proper styling..."

for SERVICE in "${WORKING_SERVICES[@]}" "${FIXED_SERVICES[@]}"; do
    echo "🐳 Building Docker image for $SERVICE..."
    
    cd "packages/$SERVICE"
    
    # Build Docker image with styled tag
    docker build -t "streaming-$SERVICE:styled" .
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully built Docker image for $SERVICE"
        
        # Test container startup
        echo "🧪 Testing container..."
        CONTAINER_ID=$(docker run -d -p 0:3000 "streaming-$SERVICE:styled")
        sleep 3
        
        if docker ps | grep -q "$CONTAINER_ID"; then
            PORT=$(docker port "$CONTAINER_ID" 3000 | cut -d: -f2)
            echo "✅ Container running on port $PORT"
            
            # Test if it serves content with CSS
            sleep 2
            RESPONSE=$(curl -s "http://localhost:$PORT")
            if echo "$RESPONSE" | grep -q "<!DOCTYPE html>"; then
                echo "✅ Serves HTML content"
                if echo "$RESPONSE" | grep -q "\.css"; then
                    echo "🎨 CSS references found in HTML!"
                else
                    echo "⚠️  No CSS references in HTML"
                fi
            else
                echo "⚠️  May not be serving content properly"
            fi
            
            docker stop "$CONTAINER_ID" > /dev/null 2>&1
        else
            echo "⚠️  Container startup issues"
            docker logs "$CONTAINER_ID" 2>/dev/null | tail -3
        fi
        
        docker rm "$CONTAINER_ID" > /dev/null 2>&1
        
        # Tag for ECR
        ECR_REPO="${ECR_BASE}/streaming-$SERVICE"
        docker tag "streaming-$SERVICE:styled" "$ECR_REPO:styled"
        echo "🏷️  Tagged as $ECR_REPO:styled"
        
    else
        echo "❌ Failed to build Docker image for $SERVICE"
    fi
    
    cd ../..
done

echo ""
echo "🚀 Pushing styled images to ECR..."

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_BASE

for SERVICE in "${WORKING_SERVICES[@]}" "${FIXED_SERVICES[@]}"; do
    ECR_REPO="${ECR_BASE}/streaming-$SERVICE"
    
    echo "📤 Pushing $SERVICE to ECR..."
    docker push "$ECR_REPO:styled"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully pushed $ECR_REPO:styled"
    else
        echo "❌ Failed to push $SERVICE"
    fi
done

echo ""
echo "🔄 Updating ECS services to use styled images..."

for SERVICE in "${WORKING_SERVICES[@]}" "${FIXED_SERVICES[@]}"; do
    SERVICE_NAME="streaming-$SERVICE"
    CLUSTER_NAME="streaming-platform-cluster"
    
    echo "🔄 Updating ECS service: $SERVICE_NAME..."
    
    # Get current task definition
    TASK_DEF_ARN=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --query 'services[0].taskDefinition' \
        --output text)
    
    if [ "$TASK_DEF_ARN" != "None" ] && [ "$TASK_DEF_ARN" != "" ]; then
        # Get task definition
        TASK_DEF=$(aws ecs describe-task-definition \
            --task-definition $TASK_DEF_ARN \
            --query 'taskDefinition')
        
        # Update image to use :styled tag
        NEW_TASK_DEF=$(echo $TASK_DEF | jq --arg image "${ECR_BASE}/streaming-$SERVICE:styled" '
            .containerDefinitions[0].image = $image |
            del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
        ')
        
        # Register new task definition
        NEW_TASK_DEF_ARN=$(echo $NEW_TASK_DEF | aws ecs register-task-definition \
            --cli-input-json file:///dev/stdin \
            --query 'taskDefinition.taskDefinitionArn' \
            --output text)
        
        if [ $? -eq 0 ]; then
            echo "✅ Registered new task definition: $NEW_TASK_DEF_ARN"
            
            # Update service
            aws ecs update-service \
                --cluster $CLUSTER_NAME \
                --service $SERVICE_NAME \
                --task-definition $NEW_TASK_DEF_ARN \
                --force-new-deployment > /dev/null
            
            if [ $? -eq 0 ]; then
                echo "✅ Updated ECS service: $SERVICE_NAME"
            else
                echo "❌ Failed to update ECS service: $SERVICE_NAME"
            fi
        else
            echo "❌ Failed to register task definition for $SERVICE_NAME"
        fi
    else
        echo "⚠️  Service $SERVICE_NAME not found or not running"
    fi
done

echo ""
echo "⏳ Waiting for services to stabilize..."
sleep 30

echo ""
echo "🧪 Testing the updated services..."

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names streaming-platform-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text 2>/dev/null)

if [ "$ALB_DNS" != "None" ] && [ "$ALB_DNS" != "" ]; then
    echo "🌐 Testing services via ALB: $ALB_DNS"
    
    for SERVICE in "${WORKING_SERVICES[@]}" "${FIXED_SERVICES[@]}"; do
        SERVICE_PATH="/${SERVICE//-/}"
        URL="http://$ALB_DNS$SERVICE_PATH"
        
        echo "🧪 Testing $SERVICE at $URL..."
        
        RESPONSE=$(curl -s -w "%{http_code}" "$URL" -o /tmp/response_$SERVICE.html)
        
        if [ "$RESPONSE" = "200" ]; then
            echo "✅ $SERVICE responds with 200"
            
            # Check for CSS in response
            if grep -q "\.css" /tmp/response_$SERVICE.html; then
                echo "🎨 CSS references found - styling should be working!"
            else
                echo "⚠️  No CSS references found"
            fi
            
            # Check for actual content
            if grep -q "<!DOCTYPE html>" /tmp/response_$SERVICE.html; then
                echo "📄 Valid HTML content served"
            else
                echo "⚠️  May not be serving proper HTML"
            fi
        else
            echo "❌ $SERVICE responds with $RESPONSE"
        fi
        
        rm -f /tmp/response_$SERVICE.html
    done
else
    echo "⚠️  Could not find ALB DNS name"
fi

echo ""
echo "📋 Deployment Summary:"
echo "======================"

for SERVICE in "${WORKING_SERVICES[@]}" "${FIXED_SERVICES[@]}"; do
    echo "📦 $SERVICE:"
    
    # Check if image exists in ECR
    if aws ecr describe-images --repository-name "streaming-$SERVICE" --image-ids imageTag=styled --region $AWS_REGION > /dev/null 2>&1; then
        echo "  ✅ Styled image in ECR"
    else
        echo "  ❌ No styled image in ECR"
    fi
    
    # Check ECS service status
    SERVICE_STATUS=$(aws ecs describe-services \
        --cluster streaming-platform-cluster \
        --services "streaming-$SERVICE" \
        --query 'services[0].status' \
        --output text 2>/dev/null)
    
    if [ "$SERVICE_STATUS" = "ACTIVE" ]; then
        echo "  ✅ ECS service active"
    else
        echo "  ❌ ECS service not active ($SERVICE_STATUS)"
    fi
done

echo ""
echo "🎨 Styled frontend deployment completed!"
echo ""
echo "🌐 You can now test the services with proper styling at:"
if [ "$ALB_DNS" != "None" ] && [ "$ALB_DNS" != "" ]; then
    for SERVICE in "${WORKING_SERVICES[@]}" "${FIXED_SERVICES[@]}"; do
        SERVICE_PATH="/${SERVICE//-/}"
        echo "  - $SERVICE: http://$ALB_DNS$SERVICE_PATH"
    done
else
    echo "  - Check your ALB DNS name and test the services"
fi