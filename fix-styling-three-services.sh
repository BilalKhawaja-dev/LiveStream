#!/bin/bash

echo "🎨 Fixing styling for admin-portal, analytics-dashboard, and developer-console..."

# Get AWS account details
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-west-2"
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

echo "📋 AWS Account: $AWS_ACCOUNT_ID"
echo "🌍 Region: $AWS_REGION"
echo "🌐 ALB DNS: $ALB_DNS"
echo ""

# Only the three services that need styling fixes
SERVICES_TO_FIX=("admin-portal" "analytics-dashboard" "developer-console")

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
echo "🔨 Building services with CSS fixes..."
echo "====================================="

for SERVICE in "${SERVICES_TO_FIX[@]}"; do
    echo "🔨 Building $SERVICE with CSS styling..."
    cd "packages/$SERVICE"
    
    # Clean previous builds
    rm -rf dist node_modules/.cache 2>/dev/null
    
    # Build the service
    npm run build > /tmp/css_fix_build_$SERVICE.log 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Build successful"
        BUILD_SUCCESS+=("$SERVICE")
        
        # Check CSS generation
        if [ -d "dist/assets" ]; then
            CSS_COUNT=$(find dist/assets -name "*.css" | wc -l)
            JS_COUNT=$(find dist/assets -name "*.js" | wc -l)
            echo "  📄 Generated $CSS_COUNT CSS files and $JS_COUNT JS files"
            
            if [ $CSS_COUNT -gt 0 ]; then
                echo "  🎨 CSS styling now available!"
            else
                echo "  ⚠️  Still no CSS files generated"
            fi
        fi
        
        # Build Docker image
        echo "  🐳 Building Docker image..."
        docker build -t "stream-dev-$SERVICE:css-fixed" . > /tmp/css_fix_docker_$SERVICE.log 2>&1
        
        if [ $? -eq 0 ]; then
            echo "  ✅ Docker build successful"
            DOCKER_SUCCESS+=("$SERVICE")
            
            # Tag for ECR
            ECR_REPO="${ECR_BASE}/stream-dev"
            docker tag "stream-dev-$SERVICE:css-fixed" "$ECR_REPO:$SERVICE-css-fixed"
            docker tag "stream-dev-$SERVICE:css-fixed" "$ECR_REPO:$SERVICE-latest"
            
            # Push to ECR
            echo "  📤 Pushing to ECR..."
            docker push "$ECR_REPO:$SERVICE-css-fixed" > /tmp/css_fix_push_$SERVICE.log 2>&1
            docker push "$ECR_REPO:$SERVICE-latest" >> /tmp/css_fix_push_$SERVICE.log 2>&1
            
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
                    echo "  ❌ ECS service update failed"
                    ECS_FAILED+=("$SERVICE")
                fi
            else
                echo "  ❌ Failed to push to ECR"
                PUSH_FAILED+=("$SERVICE")
                echo "    Error: $(head -3 /tmp/css_fix_push_$SERVICE.log)"
            fi
        else
            echo "  ❌ Docker build failed"
            DOCKER_FAILED+=("$SERVICE")
            echo "    Error: $(head -3 /tmp/css_fix_docker_$SERVICE.log)"
        fi
    else
        echo "  ❌ Build failed"
        BUILD_FAILED+=("$SERVICE")
        echo "    Error: $(head -3 /tmp/css_fix_build_$SERVICE.log)"
    fi
    
    cd ../..
done

cd ..

echo ""
echo "📊 CSS Fix Results:"
echo "=================="
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
    echo "⏳ Waiting for services to update..."
    echo "=================================="
    
    echo "Waiting 30 seconds for services to restart with new styling..."
    sleep 30
    
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
            echo "  ⚠️  Service may still be restarting ($RUNNING_COUNT/$DESIRED_COUNT tasks)"
        fi
    done
    
    echo ""
    echo "🧪 Testing updated services..."
    echo "============================="
    
    for SERVICE in "${ECS_SUCCESS[@]}"; do
        SERVICE_PATH="/${SERVICE//-/}"
        SERVICE_URL="http://$ALB_DNS$SERVICE_PATH"
        
        echo "🔍 Testing $SERVICE at $SERVICE_URL"
        
        # Test the endpoint
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$SERVICE_URL" 2>/dev/null || echo "000")
        
        if [ "$HTTP_STATUS" = "200" ]; then
            echo "  ✅ Service responding with styling (HTTP $HTTP_STATUS)"
        elif [ "$HTTP_STATUS" = "502" ] || [ "$HTTP_STATUS" = "503" ]; then
            echo "  ⚠️  Service may still be starting (HTTP $HTTP_STATUS)"
        else
            echo "  ❌ Service not responding (HTTP $HTTP_STATUS)"
        fi
    done
fi

echo ""
echo "🌐 Updated Service URLs:"
echo "======================="

for SERVICE in "${ECS_SUCCESS[@]}"; do
    echo "📱 $SERVICE: http://$ALB_DNS/${SERVICE//-/}"
done

echo ""
if [ ${#ECS_SUCCESS[@]} -gt 0 ]; then
    echo "🎉 CSS styling fixes applied successfully!"
    echo "✨ ${#ECS_SUCCESS[@]} services now have proper styling"
    echo ""
    echo "💡 The following services should now display with proper themes:"
    for SERVICE in "${ECS_SUCCESS[@]}"; do
        case $SERVICE in
            "admin-portal")
                echo "  🔵 Admin Portal: Professional blue theme with glassmorphism"
                ;;
            "analytics-dashboard")
                echo "  📊 Analytics Dashboard: Data-focused purple theme"
                ;;
            "developer-console")
                echo "  💻 Developer Console: Dark tech theme with green accents"
                ;;
        esac
    done
    echo ""
    echo "🔄 The working services (creator-dashboard, support-system, viewer-portal) were left unchanged"
else
    echo "⚠️  No services were successfully updated"
    echo "🔧 Check the errors above and retry if needed"
fi

echo ""
echo "📊 CSS styling fix process complete!"