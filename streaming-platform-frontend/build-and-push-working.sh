#!/bin/bash
# Build and push the WORKING applications to ECR

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

echo -e "${BLUE}🚀 Building and Pushing WORKING Applications${NC}"
echo "=============================================="

# Login to ECR
echo -e "${YELLOW}🔐 Logging into ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build and push viewer-portal first (we know this works)
echo -e "${BLUE}📦 Building viewer-portal (WORKING VERSION)...${NC}"
docker build -f packages/viewer-portal/Dockerfile -t $ECR_REGISTRY/$REPOSITORY_NAME:viewer-portal-latest .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully built viewer-portal${NC}"
    
    # Test the image locally first
    echo -e "${YELLOW}🧪 Testing viewer-portal image locally...${NC}"
    CONTAINER_ID=$(docker run -d -p 8080:3000 $ECR_REGISTRY/$REPOSITORY_NAME:viewer-portal-latest)
    sleep 3
    
    # Check if the container is serving content
    if curl -f http://localhost:8080 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ viewer-portal test passed${NC}"
        
        # Check assets
        JS_FILE=$(curl -s http://localhost:8080 | grep -o 'src="/assets/[^"]*"' | sed 's/src="//;s/"//' | head -1)
        if [ -n "$JS_FILE" ]; then
            if curl -f "http://localhost:8080$JS_FILE" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ viewer-portal assets working${NC}"
            else
                echo -e "${RED}❌ viewer-portal assets failed${NC}"
                docker stop $CONTAINER_ID > /dev/null 2>&1
                docker rm $CONTAINER_ID > /dev/null 2>&1
                exit 1
            fi
        fi
    else
        echo -e "${RED}❌ viewer-portal test failed${NC}"
        docker stop $CONTAINER_ID > /dev/null 2>&1
        docker rm $CONTAINER_ID > /dev/null 2>&1
        exit 1
    fi
    
    # Stop test container
    docker stop $CONTAINER_ID > /dev/null 2>&1
    docker rm $CONTAINER_ID > /dev/null 2>&1
    
    # Push to ECR
    echo -e "${YELLOW}📤 Pushing viewer-portal to ECR...${NC}"
    docker push $ECR_REGISTRY/$REPOSITORY_NAME:viewer-portal-latest
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully pushed viewer-portal${NC}"
    else
        echo -e "${RED}❌ Failed to push viewer-portal${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to build viewer-portal${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Working viewer-portal built and pushed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "• viewer-portal: $ECR_REGISTRY/$REPOSITORY_NAME:viewer-portal-latest"
echo ""
echo -e "${YELLOW}🔄 Next steps:${NC}"
echo "1. Force update ECS viewer-portal service"
echo "2. Test the live application"
echo "3. If working, build and push other applications"