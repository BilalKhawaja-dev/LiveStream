#!/bin/bash

# Simple container build script
set -e

# Configuration
REGISTRY="streaming-platform"
TAG="latest"
REGION="eu-west-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Building Simple Streaming Platform Containers${NC}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo "Region: $REGION"
echo

# List of applications to build
APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

# Track build results
SUCCESSFUL_BUILDS=()
FAILED_BUILDS=()

echo -e "${BLUE}📦 Step 1: Installing dependencies${NC}"
npm install --legacy-peer-deps

echo
echo -e "${BLUE}🐳 Step 2: Building Docker containers${NC}"

for APP in "${APPS[@]}"; do
    echo -e "${YELLOW}🔨 Building $APP...${NC}"
    
    # Create app-specific Dockerfile
    sed "s/APP_NAME/$APP/g" Dockerfile.simple > "packages/$APP/Dockerfile.temp"
    
    # Build the container
    if docker build -t "$REGISTRY/$APP:$TAG" -f "packages/$APP/Dockerfile.temp" .; then
        echo -e "${GREEN}✅ Successfully built $APP${NC}"
        SUCCESSFUL_BUILDS+=("$APP")
    else
        echo -e "${RED}❌ Failed to build $APP${NC}"
        FAILED_BUILDS+=("$APP")
    fi
    
    # Clean up temp Dockerfile
    rm -f "packages/$APP/Dockerfile.temp"
    echo
done

echo -e "${BLUE}📊 Build Summary${NC}"
echo "=============="

if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Successful builds (${#SUCCESSFUL_BUILDS[@]})${NC}"
    for app in "${SUCCESSFUL_BUILDS[@]}"; do
        echo "  - $app"
    done
    echo
fi

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed builds (${#FAILED_BUILDS[@]})${NC}"
    for app in "${FAILED_BUILDS[@]}"; do
        echo "  - $app"
    done
    echo
fi

echo -e "${BLUE}🏷️  Built Images:${NC}"
if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
    for app in "${SUCCESSFUL_BUILDS[@]}"; do
        echo "  - $REGISTRY/$app:$TAG"
    done
else
    echo "  No images were built successfully."
fi

if [ ${#FAILED_BUILDS[@]} -eq 0 ]; then
    echo -e "${GREEN}🎉 All builds completed successfully!${NC}"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Push images to ECR: ./push-to-ecr.sh"
    echo "2. Deploy to ECS using Terraform"
    exit 0
else
    echo -e "${RED}❌ Some builds failed. Please check the errors above.${NC}"
    exit 1
fi