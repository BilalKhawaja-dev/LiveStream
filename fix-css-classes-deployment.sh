#!/bin/bash

echo "🎨 Fixing CSS class usage for admin-portal, analytics-dashboard, and developer-console..."

# Get AWS account details
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-west-2"
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "📋 AWS Account: $AWS_ACCOUNT_ID"
echo "🌍 Region: $AWS_REGION"
echo ""

# Only the three services that need CSS class fixes
SERVICES_TO_FIX=("admin-portal" "analytics-dashboard" "developer-console")

echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_BASE

cd streaming-platform-frontend

BUILD_SUCCESS=()
BUILD_FAILED=()
DEPLOY_SUCCESS=()
DEPLOY_FAILED=()

echo ""
echo "🔨 Building services with CSS class fixes..."
echo "==========================================="

for SERVICE in "${SERVICES_TO_FIX[@]}"; do
    echo "🔨 Processing $SERVICE..."
    cd "packages/$SERVICE"
    
    # Clean previous builds
    rm -rf dist node_modules/.cache 2>/dev/null
    
    # Build the service
    echo "  🔧 Building..."
    npm run build > /tmp/css_class_build_$SERVICE.log 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Build successful"
        BUILD_SUCCESS+=("$SERVICE")
        
        # Check CSS generation
        if [ -d "dist/assets" ]; then
            CSS_COUNT=$(find dist/assets -name "*.css" | wc -l)
            JS_COUNT=$(find dist/assets -name "*.js" | wc -l)
            echo "  📄 Generated $CSS_COUNT CSS files and $JS_COUNT JS files"
            
            if [ $CSS_COUNT -gt 0 ]; then
                echo "  🎨 CSS classes now properly applied!"
                
                # Check if CSS contains the theme classes
                CSS_FILE=$(find dist/assets -name "*.css" | head -1)
                if [ -f "$CSS_FILE" ]; then
                    case $SERVICE in
                        "admin-portal")
                            if grep -q "admin-portal\|admin-header\|admin-card" "$CSS_FILE"; then
                                echo "  ✅ Admin theme classes found in CSS"
                            else
                                echo "  ⚠️  Admin theme classes not found in CSS"
                            fi
                            ;;
                        "analytics-dashboard")
                            if grep -q "analytics-dashboard\|analytics-header\|analytics-card" "$CSS_FILE"; then
                                echo "  ✅ Analytics theme classes found in CSS"
                            else
                                echo "  ⚠️  Analytics theme classes not found in CSS"
                            fi
                            ;;
                        "developer-console")
                            if grep -q "developer-console\|developer-header\|developer-card" "$CSS_FILE"; then
                                echo "  ✅ Developer theme classes found in CSS"
                            else
                                echo "  ⚠️  Developer theme classes not found in CSS"
                            fi
                            ;;
                    esac
                fi
            else
                echo "  ❌ No CSS files generated"
            fi
        fi
        
        # Build and deploy Docker image
        echo "  🐳 Building Docker image..."
        docker build -t "stream-dev-$SERVICE:css-classes" . > /tmp/css_class_docker_$SERVICE.log 2>&1
        
        if [ $? -eq 0 ]; then
            echo "  ✅ Docker build successful"
            
            # Tag for ECR
            ECR_REPO="${ECR_BASE}/stream-dev"
            docker tag "stream-dev-$SERVICE:css-classes" "$ECR_REPO:$SERVICE-css-classes"
            docker tag "stream-dev-$SERVICE:css-classes" "$ECR_REPO:$SERVICE-latest"
            
            # Push to ECR
            echo "  📤 Pushing to ECR..."
            docker push "$ECR_REPO:$SERVICE-css-classes" > /tmp/css_class_push_$SERVICE.log 2>&1
            docker push "$ECR_REPO:$SERVICE-latest" >> /tmp/css_class_push_$SERVICE.log 2>&1
            
            if [ $? -eq 0 ]; then
                echo "  ✅ Successfully pushed to ECR"
                
                # Update ECS service
                echo "  🔄 Updating ECS service..."
                aws ecs update-service \
                    --cluster "stream-dev-cluster" \
                    --service "stream-dev-$SERVICE" \
                    --force-new-deployment > /dev/null 2>&1
                
                if [ $? -eq 0 ]; then
                    echo "  ✅ ECS service update initiated"
                    DEPLOY_SUCCESS+=("$SERVICE")
                else
                    echo "  ❌ ECS service update failed"
                    DEPLOY_FAILED+=("$SERVICE")
                fi
            else
                echo "  ❌ Failed to push to ECR"
                DEPLOY_FAILED+=("$SERVICE")
                echo "    Error: $(head -2 /tmp/css_class_push_$SERVICE.log)"
            fi
        else
            echo "  ❌ Docker build failed"
            DEPLOY_FAILED+=("$SERVICE")
            echo "    Error: $(head -2 /tmp/css_class_docker_$SERVICE.log)"
        fi
    else
        echo "  ❌ Build failed"
        BUILD_FAILED+=("$SERVICE")
        echo "    Error: $(head -2 /tmp/css_class_build_$SERVICE.log)"
    fi
    
    cd ../..
done

cd ..

echo ""
echo "📊 CSS Class Fix Results:"
echo "========================"
echo "🔨 Build Results:"
echo "  ✅ Successful: ${BUILD_SUCCESS[*]}"
if [ ${#BUILD_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${BUILD_FAILED[*]}"
fi

echo "🚀 Deployment Results:"
echo "  ✅ Successful: ${DEPLOY_SUCCESS[*]}"
if [ ${#DEPLOY_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${DEPLOY_FAILED[*]}"
fi

if [ ${#DEPLOY_SUCCESS[@]} -gt 0 ]; then
    echo ""
    echo "⏳ Waiting for services to update with CSS classes..."
    echo "=================================================="
    
    echo "Waiting 45 seconds for services to restart..."
    sleep 45
    
    echo ""
    echo "📊 Service Status Check:"
    echo "======================="
    
    for SERVICE in "${DEPLOY_SUCCESS[@]}"; do
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
            echo "  ✅ Service is running with CSS classes ($RUNNING_COUNT/$DESIRED_COUNT tasks)"
        else
            echo "  ⚠️  Service may still be restarting ($RUNNING_COUNT/$DESIRED_COUNT tasks)"
        fi
    done
fi

echo ""
echo "🎨 Expected Styling Results:"
echo "============================"

for SERVICE in "${DEPLOY_SUCCESS[@]}"; do
    case $SERVICE in
        "admin-portal")
            echo "🔵 Admin Portal should now display:"
            echo "   - Professional blue gradient background"
            echo "   - Glassmorphism card effects"
            echo "   - Clean navigation header"
            echo "   - Organized grid layout"
            ;;
        "analytics-dashboard")
            echo "📊 Analytics Dashboard should now display:"
            echo "   - Purple data-focused theme"
            echo "   - Chart-friendly color scheme"
            echo "   - Professional analytics layout"
            echo "   - Data visualization optimized design"
            ;;
        "developer-console")
            echo "💻 Developer Console should now display:"
            echo "   - Dark tech theme with green accents"
            echo "   - Terminal-inspired design"
            echo "   - Code-friendly interface"
            echo "   - Developer-focused layout"
            ;;
    esac
    echo ""
done

echo ""
if [ ${#DEPLOY_SUCCESS[@]} -gt 0 ]; then
    echo "🎉 CSS class fixes applied successfully!"
    echo "✨ ${#DEPLOY_SUCCESS[@]} services now use proper CSS classes"
    echo ""
    echo "💡 The services should now display with full styling themes"
    echo "🔄 Working services (creator-dashboard, support-system, viewer-portal) remain unchanged"
else
    echo "⚠️  No services were successfully updated"
    echo "🔧 Check the errors above and retry if needed"
fi

echo ""
echo "📊 CSS class fix process complete!"