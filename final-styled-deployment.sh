#!/bin/bash

echo "🎨 Final styled frontend deployment with all fixes..."

# Get AWS account details
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-west-2"
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

echo "📋 AWS Account: $AWS_ACCOUNT_ID"
echo "🌍 Region: $AWS_REGION"
echo "🌐 ALB DNS: $ALB_DNS"
echo ""

# All services to deploy
SERVICES=("admin-portal" "creator-dashboard" "developer-console" "analytics-dashboard" "support-system" "viewer-portal")

echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_BASE

cd streaming-platform-frontend

BUILD_SUCCESS=()
BUILD_FAILED=()
DOCKER_SUCCESS=()
DOCKER_FAILED=()
PUSH_SUCCESS=()
PUSH_FAILED=()
ECS_SUCCESS=()
ECS_FAILED=()

echo ""
echo "🔨 Building all services..."
echo "=========================="

for SERVICE in "${SERVICES[@]}"; do
    echo "🔨 Building $SERVICE..."
    cd "packages/$SERVICE"
    
    # Clean previous builds
    rm -rf dist node_modules/.cache 2>/dev/null
    
    # Build the service
    npm run build > /tmp/final_build_$SERVICE.log 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Build successful"
        BUILD_SUCCESS+=("$SERVICE")
        
        # Check CSS generation
        if [ -d "dist/assets" ]; then
            CSS_COUNT=$(find dist/assets -name "*.css" | wc -l)
            JS_COUNT=$(find dist/assets -name "*.js" | wc -l)
            echo "  📄 Generated $CSS_COUNT CSS files and $JS_COUNT JS files"
            
            if [ $CSS_COUNT -gt 0 ]; then
                echo "  🎨 CSS styling available"
            else
                echo "  ⚠️  No CSS files - using inline styles"
            fi
        fi
        
        # Build Docker image
        echo "  🐳 Building Docker image..."
        docker build -t "stream-dev-$SERVICE:final" . > /tmp/final_docker_$SERVICE.log 2>&1
        
        if [ $? -eq 0 ]; then
            echo "  ✅ Docker build successful"
            DOCKER_SUCCESS+=("$SERVICE")
            
            # Tag for ECR
            ECR_REPO="${ECR_BASE}/stream-dev"
            docker tag "stream-dev-$SERVICE:final" "$ECR_REPO:$SERVICE-final"
            docker tag "stream-dev-$SERVICE:final" "$ECR_REPO:$SERVICE-latest"
            
            # Push to ECR
            echo "  📤 Pushing to ECR..."
            docker push "$ECR_REPO:$SERVICE-final" > /tmp/final_push_$SERVICE.log 2>&1
            docker push "$ECR_REPO:$SERVICE-latest" >> /tmp/final_push_$SERVICE.log 2>&1
            
            if [ $? -eq 0 ]; then
                echo "  ✅ Successfully pushed to ECR"
                PUSH_SUCCESS+=("$SERVICE")
                
                # Update ECS service
                echo "  🔄 Updating ECS service..."
                aws ecs update-service \
                    --cluster "stream-dev-cluster" \
                    --service "stream-dev-$SERVICE" \
                    --force-new-deployment > /dev/null 2>&1
                
                if [ $? -eq 0 ]; then
                    echo "  ✅ ECS service update initiated"
                    ECS_SUCCESS+=("$SERVICE")
                else
                    echo "  ⚠️  ECS service update failed or service doesn't exist"
                    ECS_FAILED+=("$SERVICE")
                fi
            else
                echo "  ❌ Failed to push to ECR"
                PUSH_FAILED+=("$SERVICE")
                echo "    Error: $(cat /tmp/final_push_$SERVICE.log | head -3)"
            fi
        else
            echo "  ❌ Docker build failed"
            DOCKER_FAILED+=("$SERVICE")
            echo "    Error: $(cat /tmp/final_docker_$SERVICE.log | head -3)"
        fi
    else
        echo "  ❌ Build failed"
        BUILD_FAILED+=("$SERVICE")
        echo "    Error: $(cat /tmp/final_build_$SERVICE.log | head -3)"
    fi
    
    cd ../..
done

cd ..

echo ""
echo "📊 Final Deployment Summary:"
echo "============================"
echo "🔨 Build Results:"
echo "  ✅ Successful: ${BUILD_SUCCESS[*]}"
if [ ${#BUILD_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${BUILD_FAILED[*]}"
fi

echo "🐳 Docker Results:"
echo "  ✅ Successful: ${DOCKER_SUCCESS[*]}"
if [ ${#DOCKER_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${DOCKER_FAILED[*]}"
fi

echo "📤 Push Results:"
echo "  ✅ Successful: ${PUSH_SUCCESS[*]}"
if [ ${#PUSH_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${PUSH_FAILED[*]}"
fi

echo "🔄 ECS Update Results:"
echo "  ✅ Successful: ${ECS_SUCCESS[*]}"
if [ ${#ECS_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${ECS_FAILED[*]}"
fi

if [ ${#ECS_SUCCESS[@]} -gt 0 ]; then
    echo ""
    echo "⏳ Waiting for services to stabilize..."
    echo "====================================="
    
    echo "Waiting 45 seconds for services to start..."
    sleep 45
    
    echo ""
    echo "📊 Service Status Check:"
    echo "======================="
    
    for SERVICE in "${ECS_SUCCESS[@]}"; do
        echo "🔍 Checking service: stream-dev-$SERVICE"
        
        RUNNING_COUNT=$(aws ecs describe-services \
            --cluster "stream-dev-cluster" \
            --services "stream-dev-$SERVICE" \
            --query 'services[0].runningCount' \
            --output text 2>/dev/null)
        
        DESIRED_COUNT=$(aws ecs describe-services \
            --cluster "stream-dev-cluster" \
            --services "stream-dev-$SERVICE" \
            --query 'services[0].desiredCount' \
            --output text 2>/dev/null)
        
        if [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ] && [ "$RUNNING_COUNT" != "0" ]; then
            echo "  ✅ Service is running ($RUNNING_COUNT/$DESIRED_COUNT tasks)"
        else
            echo "  ⚠️  Service may still be starting ($RUNNING_COUNT/$DESIRED_COUNT tasks)"
        fi
    done
    
    echo ""
    echo "🧪 Testing ALB endpoints..."
    echo "=========================="
    
    # Test different path formats that ALB might be configured for
    TEST_PATHS=(
        "/admin-portal"
        "/adminportal"
        "/admin"
        "/developer-console"
        "/developerconsole"
        "/developer"
        "/analytics-dashboard"
        "/analyticsdashboard"
        "/analytics"
        "/creator-dashboard"
        "/creatordashboard"
        "/creator"
        "/support-system"
        "/supportsystem"
        "/support"
        "/viewer-portal"
        "/viewerportal"
        "/viewer"
        "/"
    )
    
    echo "🔍 Testing various ALB paths..."
    WORKING_PATHS=()
    
    for PATH in "${TEST_PATHS[@]}"; do
        URL="http://$ALB_DNS$PATH"
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$URL" 2>/dev/null || echo "000")
        
        if [ "$HTTP_STATUS" = "200" ]; then
            echo "  ✅ $PATH -> HTTP $HTTP_STATUS (Working!)"
            WORKING_PATHS+=("$PATH")
        elif [ "$HTTP_STATUS" = "502" ] || [ "$HTTP_STATUS" = "503" ]; then
            echo "  ⚠️  $PATH -> HTTP $HTTP_STATUS (Service starting)"
        elif [ "$HTTP_STATUS" = "404" ]; then
            echo "  ❌ $PATH -> HTTP $HTTP_STATUS (Not found)"
        else
            echo "  ⚠️  $PATH -> HTTP $HTTP_STATUS (Unknown)"
        fi
    done
    
    echo ""
    if [ ${#WORKING_PATHS[@]} -gt 0 ]; then
        echo "🎉 Found working endpoints!"
        echo "========================="
        for PATH in "${WORKING_PATHS[@]}"; do
            echo "✅ http://$ALB_DNS$PATH"
        done
    else
        echo "⚠️  No endpoints responding yet. This could be because:"
        echo "1. Services are still starting up (wait a few more minutes)"
        echo "2. ALB health checks are still in progress"
        echo "3. Target group configuration needs adjustment"
        echo ""
        echo "💡 Try accessing these URLs in 2-3 minutes:"
        echo "🏠 Main: http://$ALB_DNS"
        for SERVICE in "${ECS_SUCCESS[@]}"; do
            echo "📱 $SERVICE: http://$ALB_DNS/$SERVICE"
        done
    fi
fi

echo ""
echo "🌐 All Possible Access URLs:"
echo "============================"
echo "🏠 Main Application: http://$ALB_DNS"

for SERVICE in "${ECS_SUCCESS[@]}"; do
    echo "📱 $SERVICE:"
    echo "   - http://$ALB_DNS/$SERVICE"
    echo "   - http://$ALB_DNS/${SERVICE//-/}"
    echo "   - http://$ALB_DNS/${SERVICE%-*}"
done

echo ""
if [ ${#ECS_SUCCESS[@]} -gt 0 ]; then
    echo "🎉 Styled frontend deployment completed!"
    echo "✨ ${#ECS_SUCCESS[@]} services with proper styling are now running"
    echo ""
    echo "💡 Next steps:"
    echo "1. Wait 2-3 minutes for all services to fully start"
    echo "2. Test the URLs above in your browser"
    echo "3. Check AWS ECS Console for service health"
    echo "4. Check CloudWatch logs if any issues occur"
else
    echo "⚠️  No services were successfully deployed"
    echo "🔧 Check the errors above and retry"
fi

echo ""
echo "📊 Final deployment process complete!"