#!/bin/bash

# Rebuild and Deploy Script for Streaming Platform Frontend
# This script rebuilds all images with the latest code and deploys them to ECS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ECR_REGISTRY="981686514879.dkr.ecr.eu-west-2.amazonaws.com"
REPOSITORY_NAME="stream-dev"
TAG="latest"
AWS_REGION="eu-west-2"
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

echo -e "${BLUE}🚀 Rebuilding and deploying streaming platform with latest code...${NC}"
echo -e "${BLUE}Timestamp: ${TIMESTAMP}${NC}"
echo -e "${BLUE}Registry: ${ECR_REGISTRY}${NC}"
echo -e "${BLUE}Repository: ${REPOSITORY_NAME}${NC}"

# Step 1: Check prerequisites
echo -e "\n${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Step 2: Login to ECR
echo -e "\n${YELLOW}🔐 Logging in to ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to login to ECR${NC}"
    echo -e "${YELLOW}💡 Make sure AWS credentials are configured: aws configure${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Successfully logged in to ECR${NC}"

# Step 3: Build and push all applications
echo -e "\n${YELLOW}📦 Building and pushing applications...${NC}"

failed_builds=()

for app in "${APPLICATIONS[@]}"; do
    echo -e "\n${BLUE}Building ${app}...${NC}"
    
    local_image_name="streaming-platform-${app}:${TIMESTAMP}"
    ecr_image_name="${ECR_REGISTRY}/${REPOSITORY_NAME}:${app}-${TAG}"
    
    # Build the Docker image
    docker build \
        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
        --build-arg VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
        -f "streaming-platform-frontend/packages/${app}/Dockerfile" \
        -t "${local_image_name}" \
        -t "${ecr_image_name}" \
        streaming-platform-frontend/
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully built ${app}${NC}"
        
        # Push to ECR
        echo -e "${BLUE}📤 Pushing ${ecr_image_name}...${NC}"
        docker push "${ecr_image_name}"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Successfully pushed ${app}${NC}"
        else
            echo -e "${RED}❌ Failed to push ${app}${NC}"
            failed_builds+=("$app")
        fi
    else
        echo -e "${RED}❌ Failed to build ${app}${NC}"
        failed_builds+=("$app")
    fi
done

# Step 4: Force ECS deployment
if [ ${#failed_builds[@]} -eq 0 ]; then
    echo -e "\n${YELLOW}🔄 Forcing ECS service deployments...${NC}"
    
    # Update terraform.tfvars to force new deployments
    if grep -q "ecs_image_tag" terraform.tfvars; then
        sed -i "s/ecs_image_tag = .*/ecs_image_tag = \"${TAG}\"/" terraform.tfvars
    else
        echo "ecs_image_tag = \"${TAG}\"" >> terraform.tfvars
    fi
    
    # Apply terraform to update ECS services
    echo -e "${BLUE}Applying terraform to update ECS services...${NC}"
    terraform apply -target=module.ecs -auto-approve
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ ECS services updated successfully${NC}"
    else
        echo -e "${RED}❌ Failed to update ECS services${NC}"
        exit 1
    fi
else
    echo -e "\n${RED}❌ Some builds failed: ${failed_builds[*]}${NC}"
    exit 1
fi

# Step 5: Verify deployment
echo -e "\n${YELLOW}🔍 Verifying deployment...${NC}"

ALB_DNS="stream-dev-fe-alb-471778558.eu-west-2.elb.amazonaws.com"

echo -e "${BLUE}Testing services...${NC}"
for app in "${APPLICATIONS[@]}"; do
    echo -n "  ${app}: "
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}/${app}/health" || echo "000")
    if [ "$status_code" = "200" ]; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ $status_code${NC}"
    fi
done

# Step 6: Summary
echo -e "\n${GREEN}🎉 Deployment Summary:${NC}"
echo -e "${GREEN}✅ All applications rebuilt with latest code${NC}"
echo -e "${GREEN}✅ Images pushed to ECR${NC}"
echo -e "${GREEN}✅ ECS services updated${NC}"
echo -e "\n${BLUE}Access your applications:${NC}"
for app in "${APPLICATIONS[@]}"; do
    echo -e "${BLUE}  • ${app}: http://${ALB_DNS}/${app}/${NC}"
done

echo -e "\n${GREEN}🚀 Deployment completed successfully!${NC}"
echo -e "${YELLOW}💡 It may take 2-3 minutes for all services to fully restart${NC}"