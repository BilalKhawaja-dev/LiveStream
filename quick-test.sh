#!/bin/bash

# Quick Test Script - Tests container builds without full deployment
# This allows us to verify everything works before the full deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Running quick tests before full deployment...${NC}"

# Test 1: Infrastructure validation
echo -e "\n${YELLOW}📋 Test 1: Infrastructure Validation${NC}"
./test-infrastructure.sh

# Test 2: Docker build test (without pushing)
echo -e "\n${YELLOW}🐳 Test 2: Docker Build Test${NC}"
cd streaming-platform-frontend

# Test build one application to verify Docker setup
echo "Testing Docker build for viewer-portal..."
cd packages/viewer-portal

if docker build -t test-viewer-portal . > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker build successful${NC}"
    docker rmi test-viewer-portal > /dev/null 2>&1
else
    echo -e "${RED}❌ Docker build failed${NC}"
    exit 1
fi

cd ../..

# Test 3: AWS CLI connectivity
echo -e "\n${YELLOW}☁️  Test 3: AWS Connectivity${NC}"
if aws sts get-caller-identity > /dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✅ AWS CLI configured for account: ${ACCOUNT_ID}${NC}"
else
    echo -e "${RED}❌ AWS CLI not configured${NC}"
    echo -e "${YELLOW}Please run: aws configure${NC}"
    exit 1
fi

# Test 4: Terraform plan (dry run)
echo -e "\n${YELLOW}🏗️  Test 4: Terraform Plan (Dry Run)${NC}"
cd ..
terraform init -backend=false > /dev/null 2>&1
if terraform plan -out=/dev/null > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Terraform plan successful${NC}"
else
    echo -e "${RED}❌ Terraform plan failed${NC}"
    echo -e "${YELLOW}Run 'terraform plan' to see detailed errors${NC}"
    exit 1
fi

# Test 5: Check required tools
echo -e "\n${YELLOW}🔧 Test 5: Required Tools Check${NC}"
REQUIRED_TOOLS=("docker" "aws" "terraform" "curl" "jq")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All required tools are installed${NC}"
else
    echo -e "${RED}❌ Missing tools: ${MISSING_TOOLS[*]}${NC}"
    exit 1
fi

# Summary
echo -e "\n${GREEN}🎉 All quick tests passed!${NC}"
echo -e "${BLUE}Ready for full deployment. Run: ./build-and-deploy.sh${NC}"

exit 0