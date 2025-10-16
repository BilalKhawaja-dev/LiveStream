#!/bin/bash

# Working container build script that addresses all the root issues
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

echo -e "${BLUE}🚀 Building Working Streaming Platform Containers${NC}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo "Region: $REGION"
echo

# List of applications to build
APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

# Track build results
SUCCESSFUL_BUILDS=()
FAILED_BUILDS=()

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

echo -e "${BLUE}🐳 Step 3: Building Docker containers${NC}"

for APP in "${APPS[@]}"; do
    echo -e "${YELLOW}🔨 Building $APP...${NC}"
    
    # Create app-specific Dockerfile that handles the build correctly
    cat > "packages/$APP/Dockerfile.working" << EOF
# Multi-stage build for $APP
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files for dependency resolution
COPY package*.json ./
COPY lerna.json ./
COPY tsconfig.json ./

# Copy all package.json files
COPY packages/shared/package.json ./packages/shared/
COPY packages/ui/package.json ./packages/ui/
COPY packages/auth/package.json ./packages/auth/
COPY packages/$APP/package.json ./packages/$APP/

# Install root dependencies
RUN npm install --legacy-peer-deps

# Copy shared package source and build them first
COPY packages/shared ./packages/shared
COPY packages/ui ./packages/ui  
COPY packages/auth ./packages/auth

# Build shared packages in correct order
WORKDIR /app/packages/shared
RUN npm install --legacy-peer-deps && npm run build

WORKDIR /app/packages/ui
RUN npm install --legacy-peer-deps && npm run build

WORKDIR /app/packages/auth
RUN npm install --legacy-peer-deps && npm run build

# Now copy and build the main app
WORKDIR /app
COPY packages/$APP ./packages/$APP

WORKDIR /app/packages/$APP
RUN npm install --legacy-peer-deps && npm run build

# Production stage with Nginx
FROM nginx:1.25-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Create default nginx config
RUN echo 'server { listen 80; location / { root /usr/share/nginx/html; index index.html; try_files \$uri \$uri/ /index.html; } }' > /etc/nginx/conf.d/default.conf

# Copy built application
COPY --from=builder /app/packages/$APP/dist /usr/share/nginx/html

# Create health check endpoint
RUN echo '{"status":"healthy","app":"$APP","timestamp":"'"\$(date -Iseconds)"'"}' > /usr/share/nginx/html/health

# Set permissions
RUN chown -R nginx:nginx /usr/share/nginx/html && chmod -R 755 /usr/share/nginx/html

EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD curl -f http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF
    
    # Build the container
    if docker build -t "$REGISTRY/$APP:$TAG" -f "packages/$APP/Dockerfile.working" .; then
        echo -e "${GREEN}✅ Successfully built $APP${NC}"
        SUCCESSFUL_BUILDS+=("$APP")
    else
        echo -e "${RED}❌ Failed to build $APP${NC}"
        FAILED_BUILDS+=("$APP")
    fi
    
    # Clean up temp Dockerfile
    rm -f "packages/$APP/Dockerfile.working"
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