#!/bin/bash

# Fixed build script for streaming platform frontend containers
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY=${ECR_REGISTRY:-"streaming-platform"}
TAG=${IMAGE_TAG:-"latest"}
REGION=${AWS_REGION:-"eu-west-2"}

# Applications to build
APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

echo -e "${GREEN}🚀 Starting build process for streaming platform frontend applications${NC}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo "Region: $REGION"
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ Error: package.json not found. Please run this script from the streaming-platform-frontend directory${NC}"
    exit 1
fi

# Check Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Step 1: Installing dependencies with npm (skipping workspace resolution)${NC}"

# Install root dependencies first
npm install --legacy-peer-deps

# Install dependencies for each package individually to avoid workspace issues
for app in "${APPS[@]}"; do
    if [ -d "packages/$app" ]; then
        echo -e "${YELLOW}📦 Installing dependencies for $app...${NC}"
        cd "packages/$app"
        
        # Replace workspace dependencies with local paths in package.json temporarily
        if [ -f "package.json.backup" ]; then
            rm package.json.backup
        fi
        cp package.json package.json.backup
        
        # Replace workspace references with file paths
        sed -i 's/"@streaming\/shared": "workspace:\*"/"@streaming\/shared": "file:..\/..\/shared"/g' package.json
        sed -i 's/"@streaming\/ui": "workspace:\*"/"@streaming\/ui": "file:..\/..\/packages\/ui"/g' package.json
        sed -i 's/"@streaming\/auth": "workspace:\*"/"@streaming\/auth": "file:..\/..\/packages\/auth"/g' package.json
        
        # Install dependencies
        npm install --legacy-peer-deps || {
            echo -e "${YELLOW}⚠️  npm install failed for $app, trying with --force${NC}"
            npm install --force
        }
        
        # Restore original package.json
        mv package.json.backup package.json
        
        cd ../..
    else
        echo -e "${YELLOW}⚠️  Directory packages/$app not found, skipping...${NC}"
    fi
done

echo -e "${BLUE}🐳 Step 2: Building Docker images${NC}"

# Function to build and tag image
build_app() {
    local app=$1
    echo -e "${YELLOW}🔨 Building $app...${NC}"
    
    if [ ! -f "packages/$app/Dockerfile" ]; then
        echo -e "${RED}❌ Dockerfile not found for $app at packages/$app/Dockerfile${NC}"
        return 1
    fi
    
    # Build the image using the Dockerfile in the app directory
    docker build -f "packages/$app/Dockerfile" -t "$REGISTRY/$app:$TAG" . || {
        echo -e "${RED}❌ Failed to build $app${NC}"
        return 1
    }
    
    echo -e "${GREEN}✅ Successfully built $app${NC}"
    
    # Tag for ECR if registry looks like ECR
    if [[ $REGISTRY == *.amazonaws.com ]]; then
        docker tag "$REGISTRY/$app:$TAG" "$REGISTRY/$app:$TAG"
        echo -e "${GREEN}✅ Tagged $app for ECR${NC}"
    fi
    
    return 0
}

# Build all applications
failed_builds=()
successful_builds=()

for app in "${APPS[@]}"; do
    if build_app "$app"; then
        successful_builds+=("$app")
    else
        failed_builds+=("$app")
    fi
    echo ""
done

# Summary
echo -e "${BLUE}📊 Build Summary${NC}"
echo "=============="

if [ ${#successful_builds[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Successfully built (${#successful_builds[@]})${NC}"
    for app in "${successful_builds[@]}"; do
        echo "  - $app"
    done
fi

if [ ${#failed_builds[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed builds (${#failed_builds[@]})${NC}"
    for app in "${failed_builds[@]}"; do
        echo "  - $app"
    done
fi

echo ""
echo -e "${BLUE}🏷️  Built Images:${NC}"
docker images | grep "$REGISTRY" | head -10

if [ ${#failed_builds[@]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All containers built successfully!${NC}"
    echo ""
    echo -e "${BLUE}📤 Next steps:${NC}"
    echo "1. Get your ECR repository URL from Terraform:"
    echo "   terraform output ecr_repository_url"
    echo ""
    echo "2. Push images to ECR:"
    echo "   ./push-to-ecr.sh \$ECR_URL"
    echo ""
    echo "3. Update ECS services:"
    echo "   aws ecs update-service --cluster <cluster-name> --service <service-name> --force-new-deployment"
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some builds failed. Please check the errors above.${NC}"
    exit 1
fi