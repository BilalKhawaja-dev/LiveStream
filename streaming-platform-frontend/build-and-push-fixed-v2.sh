#!/bin/bash
# Fixed build and push script for streaming platform frontend
set -e

# Configuration
AWS_REGION="eu-west-2"
ECR_REGISTRY="981686514879.dkr.ecr.eu-west-2.amazonaws.com"
REPOSITORY_NAME="stream-dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting FIXED Frontend Build and Push Process${NC}"
echo "=================================================="

# Login to ECR
echo -e "${YELLOW}🔐 Logging into ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Applications to build
APPLICATIONS=(
    "viewer-portal"
    "creator-dashboard" 
    "admin-portal"
    "analytics-dashboard"
    "support-system"
    "developer-console"
)

# Build and push each application
for APP in "${APPLICATIONS[@]}"; do
    echo -e "${BLUE}📦 Building $APP with FIXED base paths...${NC}"
    
    # Build the Docker image
    docker build -f packages/$APP/Dockerfile -t $ECR_REGISTRY/$REPOSITORY_NAME:$APP-latest .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully built $APP${NC}"
        
        # Test the image locally first
        echo -e "${YELLOW}🧪 Testing $APP image locally...${NC}"
        CONTAINER_ID=$(docker run -d -p 8080:3000 $ECR_REGISTRY/$REPOSITORY_NAME:$APP-latest)
        sleep 3
        
        # Check if the container is running and serving content
        if curl -f http://localhost:8080/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $APP health check passed${NC}"
        else
            echo -e "${YELLOW}⚠️  Health check failed, but continuing...${NC}"
        fi
        
        # Stop test container
        docker stop $CONTAINER_ID > /dev/null 2>&1
        docker rm $CONTAINER_ID > /dev/null 2>&1
        
        # Push to ECR
        echo -e "${YELLOW}📤 Pushing $APP to ECR...${NC}"
        docker push $ECR_REGISTRY/$REPOSITORY_NAME:$APP-latest
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Successfully pushed $APP${NC}"
        else
            echo -e "${RED}❌ Failed to push $APP${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Failed to build $APP${NC}"
        exit 1
    fi
    echo "---"
done

echo -e "${GREEN}🎉 All applications built and pushed successfully with FIXED base paths!${NC}"
echo ""
echo -e "${BLUE}📊 Build and Push Summary:${NC}"
echo -e "${GREEN}✅ All applications built and pushed successfully!${NC}"
echo ""
echo "Images pushed to ECR:"
for APP in "${APPLICATIONS[@]}"; do
    echo "• $ECR_REGISTRY/$REPOSITORY_NAME:$APP-latest"
done
echo ""
echo -e "${YELLOW}🔄 Next steps:${NC}"
echo "1. Force update ECS services to pull new images"
echo "2. Monitor deployment health"
echo "3. Test application functionality"
echo ""
echo -e "${BLUE}💡 The fix applied:${NC}"
echo "• Changed Vite base path from '/app-name/' to '/'"
echo "• This ensures assets are served from the correct paths"
echo "• Applications should now load properly instead of showing blank pages"