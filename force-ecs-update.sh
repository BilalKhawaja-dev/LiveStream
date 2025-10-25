#!/bin/bash

# Force ECS Update Script
# Forces all ECS services to redeploy with the latest images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="stream-dev-cluster"
REGION="eu-west-2"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

SERVICES=(
    "stream-dev-admin-portal"
    "stream-dev-viewer-portal"
    "stream-dev-creator-dashboard"
    "stream-dev-support-system"
    "stream-dev-analytics-dashboard"
    "stream-dev-developer-console"
)

echo -e "${BLUE}🔄 Forcing ECS services to use latest images...${NC}"
echo -e "${BLUE}Cluster: ${CLUSTER_NAME}${NC}"
echo -e "${BLUE}Timestamp: ${TIMESTAMP}${NC}"
echo

# Method 1: Force new deployments for all services
echo -e "${YELLOW}📦 Forcing new deployments...${NC}"

for service in "${SERVICES[@]}"; do
    echo -e "${BLUE}Updating ${service}...${NC}"
    
    aws ecs update-service \
        --cluster ${CLUSTER_NAME} \
        --service ${service} \
        --force-new-deployment \
        --region ${REGION} \
        --query 'service.[serviceName,taskDefinition,runningCount,desiredCount]' \
        --output table
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully triggered deployment for ${service}${NC}"
    else
        echo -e "${RED}❌ Failed to update ${service}${NC}"
    fi
    echo
done

# Method 2: Update terraform with a new image tag to force task definition updates
echo -e "${YELLOW}🔧 Updating Terraform configuration...${NC}"

# Update the image tag in terraform.tfvars to force new task definitions
if grep -q "ecs_image_tag" terraform.tfvars; then
    sed -i "s/ecs_image_tag = .*/ecs_image_tag = \"latest-${TIMESTAMP}\"/" terraform.tfvars
else
    echo "ecs_image_tag = \"latest-${TIMESTAMP}\"" >> terraform.tfvars
fi

echo -e "${GREEN}✅ Updated terraform.tfvars with new image tag: latest-${TIMESTAMP}${NC}"

# Apply terraform to create new task definitions
echo -e "${BLUE}Applying terraform to create new task definitions...${NC}"
terraform apply -target=module.ecs -auto-approve

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Terraform applied successfully${NC}"
else
    echo -e "${RED}❌ Terraform apply failed${NC}"
    exit 1
fi

# Wait for services to stabilize
echo -e "\n${YELLOW}⏳ Waiting for services to stabilize...${NC}"
sleep 30

# Verify all services are running
echo -e "\n${BLUE}🔍 Verifying service status...${NC}"

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Checking ${service}...${NC}"
    
    status=$(aws ecs describe-services \
        --cluster ${CLUSTER_NAME} \
        --services ${service} \
        --region ${REGION} \
        --query 'services[0].[serviceName,runningCount,desiredCount,taskDefinition]' \
        --output table)
    
    echo "$status"
    echo
done

# Test health endpoints
echo -e "${BLUE}🏥 Testing health endpoints...${NC}"
ALB_DNS="stream-dev-fe-alb-471778558.eu-west-2.elb.amazonaws.com"

APPS=("admin-portal" "viewer-portal" "creator-dashboard" "support-system" "analytics-dashboard" "developer-console")

for app in "${APPS[@]}"; do
    echo -n "  ${app}: "
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}/${app}/health" || echo "000")
    if [ "$status_code" = "200" ]; then
        echo -e "${GREEN}✅ $status_code${NC}"
    else
        echo -e "${RED}❌ $status_code${NC}"
    fi
done

echo -e "\n${GREEN}🎉 ECS force update completed!${NC}"
echo -e "${YELLOW}💡 Services may take 2-3 minutes to fully restart with new images${NC}"

# Revert terraform.tfvars to keep it clean
sed -i "s/ecs_image_tag = .*/ecs_image_tag = \"latest\"/" terraform.tfvars
echo -e "${BLUE}Reverted terraform.tfvars to use 'latest' tag${NC}"