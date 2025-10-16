#!/bin/bash

# Functional container build script - fixes workspace deps and builds proper containers
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

echo -e "${GREEN}🚀 Building Functional Streaming Platform Containers${NC}"
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

echo -e "${BLUE}🔧 Step 1: Fixing workspace dependencies${NC}"

# Fix workspace dependencies
./fix-workspace-deps.sh

echo -e "${BLUE}📦 Step 2: Installing dependencies${NC}"

# Install root dependencies
echo "Installing root dependencies..."
npm install --legacy-peer-deps || {
    echo -e "${YELLOW}⚠️  Root npm install failed, trying with --force${NC}"
    npm install --force
}

# Install dependencies for shared packages first
echo "Installing shared package dependencies..."
cd shared
npm install --legacy-peer-deps || npm install --force
cd ..

echo "Installing ui package dependencies..."
cd packages/ui
npm install --legacy-peer-deps || npm install --force
cd ../..

echo "Installing auth package dependencies..."
cd packages/auth
npm install --legacy-peer-deps || npm install --force
cd ../..

# Applications to build
APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

# Install dependencies for each app
for app in "${APPS[@]}"; do
    if [ -d "packages/$app" ]; then
        echo "Installing dependencies for $app..."
        cd "packages/$app"
        npm install --legacy-peer-deps || npm install --force
        cd ../..
    fi
done

echo -e "${BLUE}🐳 Step 3: Building Docker containers${NC}"

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

echo -e "${BLUE}🔄 Step 4: Restoring original package.json files${NC}"

# Restore original package.json files
for app in "${APPS[@]}"; do
    if [ -f "packages/$app/package.json.backup" ]; then
        mv "packages/$app/package.json.backup" "packages/$app/package.json"
        echo "Restored packages/$app/package.json"
    fi
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
    echo -e "${GREEN}🎉 All functional containers built successfully!${NC}"
    echo ""
    echo -e "${BLUE}📤 Next steps:${NC}"
    echo "1. Deploy infrastructure first (if not done):"
    echo "   terraform init && terraform apply"
    echo ""
    echo "2. Get ECR URL and push images:"
    echo "   ECR_URL=\$(terraform output -raw ecr_repository_url)"
    echo "   ./push-to-ecr.sh \$ECR_URL"
    echo ""
    echo "3. Access your application:"
    echo "   terraform output application_url"
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some builds failed. Please check the errors above.${NC}"
    exit 1
fi