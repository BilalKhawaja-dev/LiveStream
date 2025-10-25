#!/bin/bash

# Build and push script for streaming platform frontend applications
set -e

# Configuration
ECR_REGISTRY="981686514879.dkr.ecr.eu-west-2.amazonaws.com"
REPOSITORY_NAME="stream-dev"
TAG=${TAG:-"latest"}
AWS_REGION="eu-west-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Applications to build
APPLICATIONS=(
    "viewer-portal"
    "creator-dashboard"
    "admin-portal"
    "support-system"
    "analytics-dashboard"
    "developer-console"
)

echo -e "${BLUE}🚀 Building and pushing Docker images to ECR...${NC}"
echo -e "${BLUE}Registry: ${ECR_REGISTRY}${NC}"
echo -e "${BLUE}Repository: ${REPOSITORY_NAME}${NC}"
echo -e "${BLUE}Tag: ${TAG}${NC}"

# Login to ECR
echo -e "${YELLOW}🔐 Logging in to ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to login to ECR${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Successfully logged in to ECR${NC}"

# Function to build and push a single application
build_and_push() {
    local app_name=$1
    
    echo -e "\n${YELLOW}📦 Building ${app_name}...${NC}"
    
    local image_name="${ECR_REGISTRY}/${REPOSITORY_NAME}:${app_name}-${TAG}"
    
    # Build the Docker image
    docker build \
        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
        --build-arg VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
        -f "packages/${app_name}/Dockerfile" \
        -t "${image_name}" \
        .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully built ${app_name}${NC}"
        
        # Push to ECR
        echo -e "${BLUE}📤 Pushing ${image_name}...${NC}"
        docker push "${image_name}"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Successfully pushed ${app_name}${NC}"
            
            # Also tag and push as latest for this app
            local latest_image="${ECR_REGISTRY}/${REPOSITORY_NAME}:${app_name}-latest"
            docker tag "${image_name}" "${latest_image}"
            docker push "${latest_image}"
            
            return 0
        else
            echo -e "${RED}❌ Failed to push ${app_name}${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to build ${app_name}${NC}"
        return 1
    fi
}

# Build and push all applications
failed_builds=()

for app in "${APPLICATIONS[@]}"; do
    if ! build_and_push "$app"; then
        failed_builds+=("$app")
    fi
done

# Report results
echo -e "\n${BLUE}📊 Build and Push Summary:${NC}"

if [ ${#failed_builds[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All applications built and pushed successfully!${NC}"
    echo -e "\n${BLUE}Images pushed to ECR:${NC}"
    for app in "${APPLICATIONS[@]}"; do
        echo -e "${GREEN}  • ${ECR_REGISTRY}/${REPOSITORY_NAME}:${app}-${TAG}${NC}"
        echo -e "${GREEN}  • ${ECR_REGISTRY}/${REPOSITORY_NAME}:${app}-latest${NC}"
    done
else
    echo -e "${RED}❌ Failed to build/push: ${failed_builds[*]}${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 Build and push process completed successfully!${NC}"