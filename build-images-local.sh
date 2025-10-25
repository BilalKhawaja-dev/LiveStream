#!/bin/bash

# Local Build Script for Testing
# This script builds all images locally for testing without pushing to ECR

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Applications to build
APPLICATIONS=(
    "viewer-portal"
    "creator-dashboard"
    "admin-portal"
    "support-system"
    "analytics-dashboard"
    "developer-console"
)

echo -e "${BLUE}🚀 Building streaming platform images locally...${NC}"
echo -e "${BLUE}Timestamp: ${TIMESTAMP}${NC}"

failed_builds=()

for app in "${APPLICATIONS[@]}"; do
    echo -e "\n${YELLOW}📦 Building ${app}...${NC}"
    
    image_name="streaming-platform-${app}:${TIMESTAMP}"
    
    # Build the Docker image
    docker build \
        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
        --build-arg VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
        -f "streaming-platform-frontend/packages/${app}/Dockerfile" \
        -t "${image_name}" \
        -t "streaming-platform-${app}:latest" \
        streaming-platform-frontend/
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully built ${app}${NC}"
    else
        echo -e "${RED}❌ Failed to build ${app}${NC}"
        failed_builds+=("$app")
    fi
done

# Summary
echo -e "\n${BLUE}📊 Build Summary:${NC}"

if [ ${#failed_builds[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All applications built successfully!${NC}"
    echo -e "\n${BLUE}Built images:${NC}"
    for app in "${APPLICATIONS[@]}"; do
        echo -e "${GREEN}  • streaming-platform-${app}:${TIMESTAMP}${NC}"
        echo -e "${GREEN}  • streaming-platform-${app}:latest${NC}"
    done
    
    echo -e "\n${YELLOW}💡 To test locally: docker-compose up${NC}"
    echo -e "${YELLOW}💡 To deploy to AWS: ./rebuild-and-deploy.sh${NC}"
else
    echo -e "${RED}❌ Failed to build: ${failed_builds[*]}${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 Local build completed successfully!${NC}"