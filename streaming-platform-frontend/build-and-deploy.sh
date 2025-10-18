#!/bin/bash

# Complete build and deploy script for streaming platform containers
# Builds with correct ports and optionally pushes to ECR
set -e

# Configuration
REGISTRY="streaming-platform"
TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo "Options:"
    echo "  -p, --push <ecr-url>    Push to ECR after building"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Build only"
    echo "  $0 --push \$(terraform output -raw ecr_repository_url)  # Build and push"
    echo ""
}

# Parse command line arguments
PUSH_TO_ECR=false
ECR_URL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--push)
            PUSH_TO_ECR=true
            ECR_URL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Validate ECR URL if pushing
if [ "$PUSH_TO_ECR" = true ]; then
    if [ -z "$ECR_URL" ]; then
        echo -e "${RED}❌ Error: ECR repository URL required when using --push${NC}"
        echo ""
        echo "Get your ECR URL from Terraform:"
        echo "  terraform output ecr_repository_url"
        exit 1
    fi
    
    REGION=$(echo "$ECR_URL" | cut -d'.' -f4)
    if [ -z "$REGION" ]; then
        echo -e "${RED}❌ Error: Invalid ECR URL format${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}🚀 Building Streaming Platform Containers with Correct Ports${NC}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
if [ "$PUSH_TO_ECR" = true ]; then
    echo "ECR URL: $ECR_URL"
    echo "Region: $REGION"
fi
echo

# List of applications with their expected ports
declare -A APPS=(
    ["viewer-portal"]="3000"
    ["creator-dashboard"]="3001"
    ["admin-portal"]="3002"
    ["support-system"]="3003"
    ["analytics-dashboard"]="3004"
    ["developer-console"]="3005"
)

# Track build results
SUCCESSFUL_BUILDS=()
FAILED_BUILDS=()
SUCCESSFUL_PUSHES=()
FAILED_PUSHES=()

echo -e "${BLUE}📦 Step 1: Clean and install dependencies${NC}"
# Clean everything first
rm -rf node_modules packages/*/node_modules packages/*/dist

# Install root dependencies
npm install --legacy-peer-deps

echo -e "${BLUE}🔧 Step 2: Build shared packages in correct order${NC}"
echo "Building shared packages..."

# Build shared packages first (they have no dependencies)
cd packages/shared
npm install --legacy-peer-deps
npm run build
cd ../..

cd packages/ui  
npm install --legacy-peer-deps
npm run build
cd ../..

cd packages/auth
npm install --legacy-peer-deps  
npm run build
cd ../..

echo -e "${GREEN}✅ Shared packages built successfully${NC}"

echo -e "${BLUE}🏗️  Step 3: Build individual applications${NC}"

for APP in "${!APPS[@]}"; do
    PORT=${APPS[$APP]}
    echo -e "${YELLOW}🔨 Building $APP (port $PORT)...${NC}"
    
    # Build the application
    cd "packages/$APP"
    
    # Install dependencies and build
    if npm install --legacy-peer-deps && npm run build; then
        echo -e "${GREEN}✅ Successfully built $APP application${NC}"
    else
        echo -e "${RED}❌ Failed to build $APP application${NC}"
        FAILED_BUILDS+=("$APP")
        cd ../..
        continue
    fi
    
    cd ../..
    
    # Build Docker container using the individual Dockerfile
    echo -e "${YELLOW}🐳 Building Docker container for $APP...${NC}"
    
    if docker build -t "$REGISTRY/$APP:$TAG" -f "packages/$APP/Dockerfile" "packages/$APP"; then
        echo -e "${GREEN}✅ Successfully built $APP container (port $PORT)${NC}"
        SUCCESSFUL_BUILDS+=("$APP")
    else
        echo -e "${RED}❌ Failed to build $APP container${NC}"
        FAILED_BUILDS+=("$APP")
    fi
    
    echo
done

# Push to ECR if requested
if [ "$PUSH_TO_ECR" = true ] && [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
    echo -e "${BLUE}🚀 Step 4: Pushing to ECR${NC}"
    
    # Login to ECR
    echo -e "${YELLOW}🔐 Logging in to ECR...${NC}"
    if aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_URL"; then
        echo -e "${GREEN}✅ Successfully logged in to ECR${NC}"
        
        # Push each successful build
        for APP in "${SUCCESSFUL_BUILDS[@]}"; do
            PORT=${APPS[$APP]}
            LOCAL_IMAGE="$REGISTRY/$APP:$TAG"
            ECR_IMAGE="$ECR_URL:$APP-$TAG"
            
            echo -e "${YELLOW}📤 Pushing $APP (port $PORT)...${NC}"
            
            # Tag for ECR
            if docker tag "$LOCAL_IMAGE" "$ECR_IMAGE"; then
                # Push to ECR
                if docker push "$ECR_IMAGE"; then
                    echo -e "${GREEN}✅ Successfully pushed $APP${NC}"
                    SUCCESSFUL_PUSHES+=("$APP")
                else
                    echo -e "${RED}❌ Failed to push $APP to ECR${NC}"
                    FAILED_PUSHES+=("$APP")
                fi
            else
                echo -e "${RED}❌ Failed to tag $APP for ECR${NC}"
                FAILED_PUSHES+=("$APP")
            fi
            echo
        done
    else
        echo -e "${RED}❌ Failed to login to ECR. Check your AWS credentials and region.${NC}"
        PUSH_TO_ECR=false
    fi
fi

echo -e "${BLUE}📊 Final Summary${NC}"
echo "==============="

# Build summary
if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Successful builds (${#SUCCESSFUL_BUILDS[@]})${NC}"
    for app in "${SUCCESSFUL_BUILDS[@]}"; do
        port=${APPS[$app]}
        echo "  - $app (port $port)"
    done
    echo
fi

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed builds (${#FAILED_BUILDS[@]})${NC}"
    for app in "${FAILED_BUILDS[@]}"; do
        port=${APPS[$app]}
        echo "  - $app (port $port)"
    done
    echo
fi

# Push summary (if applicable)
if [ "$PUSH_TO_ECR" = true ]; then
    if [ ${#SUCCESSFUL_PUSHES[@]} -gt 0 ]; then
        echo -e "${GREEN}✅ Successful pushes (${#SUCCESSFUL_PUSHES[@]})${NC}"
        for app in "${SUCCESSFUL_PUSHES[@]}"; do
            port=${APPS[$app]}
            echo "  - $app (port $port)"
        done
        echo
    fi
    
    if [ ${#FAILED_PUSHES[@]} -gt 0 ]; then
        echo -e "${RED}❌ Failed pushes (${#FAILED_PUSHES[@]})${NC}"
        for app in "${FAILED_PUSHES[@]}"; do
            port=${APPS[$app]}
            echo "  - $app (port $port)"
        done
        echo
    fi
fi

echo -e "${BLUE}🔍 Port Configuration Verification:${NC}"
echo "ECS expects containers on these ports:"
for app in "${!APPS[@]}"; do
    port=${APPS[$app]}
    echo "  - $app: $port"
done
echo

# Final status and next steps
if [ ${#FAILED_BUILDS[@]} -eq 0 ]; then
    echo -e "${GREEN}🎉 All builds completed successfully with correct ports!${NC}"
    
    if [ "$PUSH_TO_ECR" = true ] && [ ${#FAILED_PUSHES[@]} -eq 0 ]; then
        echo -e "${GREEN}🚀 All images pushed to ECR successfully!${NC}"
        echo
        echo -e "${BLUE}📋 Next steps:${NC}"
        echo "1. Update ECS services to use new images:"
        echo "   aws ecs update-service --region $REGION --cluster \$(terraform output -raw ecs_cluster_name) --service stream-dev-viewer-portal --force-new-deployment"
        echo ""
        echo "2. Check ECS service health:"
        echo "   aws ecs describe-services --region $REGION --cluster \$(terraform output -raw ecs_cluster_name) --services stream-dev-viewer-portal"
        echo ""
        echo "3. Monitor health checks - they should now pass on correct ports!"
    else
        echo
        echo -e "${BLUE}Next steps:${NC}"
        echo "1. Push to ECR: $0 --push \$(terraform output -raw ecr_repository_url)"
        echo "2. Update ECS services to use new images"
        echo "3. Health checks should now pass on correct ports"
    fi
    
    exit 0
else
    echo -e "${RED}❌ Some builds failed. Please check the errors above.${NC}"
    exit 1
fi