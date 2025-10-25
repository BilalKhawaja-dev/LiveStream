#!/bin/bash

echo "🚀 Deploying ECS infrastructure and styled frontend services..."

# First, let's check if we need to deploy the infrastructure
echo "🔍 Checking current infrastructure status..."

# Check if ECS cluster exists
CLUSTER_EXISTS=$(aws ecs describe-clusters --clusters streaming-platform-cluster --query 'clusters[0].status' --output text 2>/dev/null)

if [ "$CLUSTER_EXISTS" != "ACTIVE" ]; then
    echo "📦 ECS cluster not found or not active. Deploying infrastructure..."
    
    # Deploy the infrastructure
    terraform init
    terraform plan -out=tfplan
    
    echo "🤔 Do you want to apply the Terraform plan to create the ECS infrastructure?"
    read -p "Type 'yes' to continue: " confirm
    
    if [ "$confirm" = "yes" ]; then
        terraform apply tfplan
        
        if [ $? -eq 0 ]; then
            echo "✅ Infrastructure deployed successfully"
        else
            echo "❌ Infrastructure deployment failed"
            exit 1
        fi
    else
        echo "❌ Infrastructure deployment cancelled"
        exit 1
    fi
else
    echo "✅ ECS cluster is active"
fi

# Now let's build and deploy the styled services
echo ""
echo "🎨 Building and deploying styled frontend services..."

cd streaming-platform-frontend

# Services to deploy
SERVICES=("admin-portal" "creator-dashboard" "developer-console" "analytics-dashboard" "support-system")

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "🔧 Testing builds locally first..."

BUILD_SUCCESS=()
BUILD_FAILED=()

for SERVICE in "${SERVICES[@]}"; do
    echo "🔨 Testing build for $SERVICE..."
    cd "packages/$SERVICE"
    
    # Clean previous builds
    rm -rf dist/
    
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
            else
                echo "⚠️  No CSS files generated - may have styling issues"
            fi
        fi
        BUILD_SUCCESS+=("$SERVICE")
    else
        echo "❌ $SERVICE build failed"
        BUILD_FAILED+=("$SERVICE")
    fi
    
    cd ../..
    echo ""
done

# Report build results
echo "📋 Build Results:"
echo "✅ Successful builds: ${BUILD_SUCCESS[*]}"
if [ ${#BUILD_FAILED[@]} -gt 0 ]; then
    echo "❌ Failed builds: ${BUILD_FAILED[*]}"
    echo ""
    echo "🛑 Some builds failed. Do you want to continue with only the successful builds?"
    read -p "Type 'yes' to continue: " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "❌ Deployment cancelled"
        exit 1
    fi
fi

# Create ECR repositories if they don't exist
echo ""
echo "📦 Ensuring ECR repositories exist..."

for SERVICE in "${BUILD_SUCCESS[@]}"; do
    REPO_NAME="streaming-$SERVICE"
    
    # Check if repository exists
    aws ecr describe-repositories --repository-names "$REPO_NAME" --region $AWS_REGION > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "📦 Creating ECR repository: $REPO_NAME"
        aws ecr create-repository --repository-name "$REPO_NAME" --region $AWS_REGION > /dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ Created repository: $REPO_NAME"
        else
            echo "❌ Failed to create repository: $REPO_NAME"
        fi
    else
        echo "✅ Repository exists: $REPO_NAME"
    fi
done

# Build Docker images
echo ""
echo "🐳 Building Docker images..."

DOCKER_SUCCESS=()
DOCKER_FAILED=()

for SERVICE in "${BUILD_SUCCESS[@]}"; do
    echo "🐳 Building Docker image for $SERVICE..."
    
    cd "packages/$SERVICE"
    
    # Build Docker image
    docker build -t "streaming-$SERVICE:styled" .
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully built Docker image for $SERVICE"
        
        # Tag for ECR
        ECR_REPO="${ECR_BASE}/streaming-$SERVICE"
        docker tag "streaming-$SERVICE:styled" "$ECR_REPO:styled"
        echo "🏷️  Tagged as $ECR_REPO:styled"
        
        DOCKER_SUCCESS+=("$SERVICE")
    else
        echo "❌ Failed to build Docker image for $SERVICE"
        DOCKER_FAILED+=("$SERVICE")
    fi
    
    cd ../..
done

# Report Docker build results
echo ""
echo "📋 Docker Build Results:"
echo "✅ Successful Docker builds: ${DOCKER_SUCCESS[*]}"
if [ ${#DOCKER_FAILED[@]} -gt 0 ]; then
    echo "❌ Failed Docker builds: ${DOCKER_FAILED[*]}"
fi

# Push images to ECR
echo ""
echo "🚀 Pushing images to ECR..."

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_BASE

PUSH_SUCCESS=()
PUSH_FAILED=()

for SERVICE in "${DOCKER_SUCCESS[@]}"; do
    ECR_REPO="${ECR_BASE}/streaming-$SERVICE"
    
    echo "📤 Pushing $SERVICE to ECR..."
    docker push "$ECR_REPO:styled"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully pushed $ECR_REPO:styled"
        PUSH_SUCCESS+=("$SERVICE")
    else
        echo "❌ Failed to push $SERVICE"
        PUSH_FAILED+=("$SERVICE")
    fi
done

# Update ECS services
echo ""
echo "🔄 Updating ECS services..."

CLUSTER_NAME="streaming-platform-cluster"
UPDATE_SUCCESS=()
UPDATE_FAILED=()

for SERVICE in "${PUSH_SUCCESS[@]}"; do
    SERVICE_NAME="streaming-$SERVICE"
    
    echo "🔄 Updating ECS service: $SERVICE_NAME..."
    
    # Get current task definition
    TASK_DEF_ARN=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --query 'services[0].taskDefinition' \
        --output text 2>/dev/null)
    
    if [ "$TASK_DEF_ARN" != "None" ] && [ "$TASK_DEF_ARN" != "" ] && [ "$TASK_DEF_ARN" != "null" ]; then
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
                UPDATE_SUCCESS+=("$SERVICE")
            else
                echo "❌ Failed to update ECS service: $SERVICE_NAME"
                UPDATE_FAILED+=("$SERVICE")
            fi
        else
            echo "❌ Failed to register task definition for $SERVICE_NAME"
            UPDATE_FAILED+=("$SERVICE")
        fi
    else
        echo "⚠️  Service $SERVICE_NAME not found or not running"
        UPDATE_FAILED+=("$SERVICE")
    fi
done

# Wait for services to stabilize
if [ ${#UPDATE_SUCCESS[@]} -gt 0 ]; then
    echo ""
    echo "⏳ Waiting for services to stabilize..."
    sleep 45
    
    # Check service status
    echo "🔍 Checking service status..."
    for SERVICE in "${UPDATE_SUCCESS[@]}"; do
        SERVICE_NAME="streaming-$SERVICE"
        
        SERVICE_STATUS=$(aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services $SERVICE_NAME \
            --query 'services[0].deployments[0].status' \
            --output text 2>/dev/null)
        
        RUNNING_COUNT=$(aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services $SERVICE_NAME \
            --query 'services[0].runningCount' \
            --output text 2>/dev/null)
        
        echo "📊 $SERVICE_NAME: Status=$SERVICE_STATUS, Running=$RUNNING_COUNT"
    done
fi

# Test the services
echo ""
echo "🧪 Testing the updated services..."

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names streaming-platform-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text 2>/dev/null)

if [ "$ALB_DNS" != "None" ] && [ "$ALB_DNS" != "" ] && [ "$ALB_DNS" != "null" ]; then
    echo "🌐 Testing services via ALB: $ALB_DNS"
    
    TEST_SUCCESS=()
    TEST_FAILED=()
    
    for SERVICE in "${UPDATE_SUCCESS[@]}"; do
        SERVICE_PATH="/${SERVICE//-/}"
        URL="http://$ALB_DNS$SERVICE_PATH"
        
        echo "🧪 Testing $SERVICE at $URL..."
        
        # Test with timeout
        RESPONSE=$(timeout 10 curl -s -w "%{http_code}" "$URL" -o /tmp/response_$SERVICE.html 2>/dev/null)
        
        if [ "$RESPONSE" = "200" ]; then
            echo "✅ $SERVICE responds with 200"
            
            # Check for CSS in response
            if grep -q "\.css" /tmp/response_$SERVICE.html 2>/dev/null; then
                echo "🎨 CSS references found - styling should be working!"
            else
                echo "⚠️  No CSS references found"
            fi
            
            # Check for actual content
            if grep -q "<!DOCTYPE html>" /tmp/response_$SERVICE.html 2>/dev/null; then
                echo "📄 Valid HTML content served"
                TEST_SUCCESS+=("$SERVICE")
            else
                echo "⚠️  May not be serving proper HTML"
                TEST_FAILED+=("$SERVICE")
            fi
        else
            echo "❌ $SERVICE responds with $RESPONSE"
            TEST_FAILED+=("$SERVICE")
        fi
        
        rm -f /tmp/response_$SERVICE.html
    done
else
    echo "⚠️  Could not find ALB DNS name"
fi

# Final summary
echo ""
echo "📋 Final Deployment Summary:"
echo "============================"

echo "🏗️  Build Results:"
echo "  ✅ Successful: ${BUILD_SUCCESS[*]}"
if [ ${#BUILD_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${BUILD_FAILED[*]}"
fi

echo ""
echo "🐳 Docker Results:"
echo "  ✅ Successful: ${DOCKER_SUCCESS[*]}"
if [ ${#DOCKER_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${DOCKER_FAILED[*]}"
fi

echo ""
echo "📤 Push Results:"
echo "  ✅ Successful: ${PUSH_SUCCESS[*]}"
if [ ${#PUSH_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${PUSH_FAILED[*]}"
fi

echo ""
echo "🔄 ECS Update Results:"
echo "  ✅ Successful: ${UPDATE_SUCCESS[*]}"
if [ ${#UPDATE_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed: ${UPDATE_FAILED[*]}"
fi

if [ ${#TEST_SUCCESS[@]} -gt 0 ]; then
    echo ""
    echo "🧪 Service Test Results:"
    echo "  ✅ Working: ${TEST_SUCCESS[*]}"
    if [ ${#TEST_FAILED[@]} -gt 0 ]; then
        echo "  ❌ Issues: ${TEST_FAILED[*]}"
    fi
fi

echo ""
echo "🎨 Styled frontend deployment completed!"

if [ "$ALB_DNS" != "None" ] && [ "$ALB_DNS" != "" ] && [ "$ALB_DNS" != "null" ]; then
    echo ""
    echo "🌐 You can test the services with proper styling at:"
    for SERVICE in "${TEST_SUCCESS[@]}"; do
        SERVICE_PATH="/${SERVICE//-/}"
        echo "  - $SERVICE: http://$ALB_DNS$SERVICE_PATH"
    done
else
    echo ""
    echo "ℹ️  Check your ALB DNS name and test the services manually"
fi

# Return to original directory
cd ..

echo ""
echo "✨ Deployment process complete!"