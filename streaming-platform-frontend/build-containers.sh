#!/bin/bash

# Build script for all streaming platform frontend containers
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGISTRY=${ECR_REGISTRY:-"streaming-platform"}
TAG=${IMAGE_TAG:-"latest"}
REGION=${AWS_REGION:-"eu-west-2"}

# Applications to build
APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

echo -e "${GREEN}Starting build process for streaming platform frontend applications${NC}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo "Region: $REGION"
echo ""

# Function to build and tag image
build_app() {
    local app=$1
    echo -e "${YELLOW}Building $app...${NC}"
    
    # Build the image
    docker build -f packages/$app/Dockerfile -t $REGISTRY/$app:$TAG .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully built $app${NC}"
        
        # Tag for ECR if registry is provided
        if [[ $REGISTRY == *.amazonaws.com ]]; then
            docker tag $REGISTRY/$app:$TAG $REGISTRY/$app:$TAG
            echo -e "${GREEN}✓ Tagged $app for ECR${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to build $app${NC}"
        return 1
    fi
}

# Function to push image to ECR
push_app() {
    local app=$1
    echo -e "${YELLOW}Pushing $app to ECR...${NC}"
    
    docker push $REGISTRY/$app:$TAG
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully pushed $app${NC}"
    else
        echo -e "${RED}✗ Failed to push $app${NC}"
        return 1
    fi
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install
fi

# Build all applications
echo -e "${YELLOW}Building all applications...${NC}"
for app in "${APPS[@]}"; do
    build_app $app
    if [ $? -ne 0 ]; then
        echo -e "${RED}Build failed for $app. Exiting.${NC}"
        exit 1
    fi
done

# Push to ECR if registry is ECR
if [[ $REGISTRY == *.amazonaws.com ]]; then
    echo -e "${YELLOW}Logging into ECR...${NC}"
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully logged into ECR${NC}"
        
        # Push all images
        for app in "${APPS[@]}"; do
            push_app $app
            if [ $? -ne 0 ]; then
                echo -e "${RED}Push failed for $app. Continuing with others.${NC}"
            fi
        done
    else
        echo -e "${RED}✗ Failed to login to ECR${NC}"
        exit 1
    fi
fi

# Summary
echo ""
echo -e "${GREEN}Build Summary:${NC}"
echo "Built applications: ${APPS[*]}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"

# Show image sizes
echo ""
echo -e "${YELLOW}Image Sizes:${NC}"
for app in "${APPS[@]}"; do
    size=$(docker images $REGISTRY/$app:$TAG --format "table {{.Size}}" | tail -n 1)
    echo "$app: $size"
done

echo ""
echo -e "${GREEN}✓ All builds completed successfully!${NC}"

# Optional: Run security scan
if command -v trivy &> /dev/null; then
    echo ""
    echo -e "${YELLOW}Running security scans...${NC}"
    for app in "${APPS[@]}"; do
        echo "Scanning $app..."
        trivy image --severity HIGH,CRITICAL $REGISTRY/$app:$TAG
    done
fi

echo ""
echo -e "${GREEN}Build process complete!${NC}"
echo "To run locally: docker-compose up"
echo "To deploy: Update ECS task definitions with new image URIs"