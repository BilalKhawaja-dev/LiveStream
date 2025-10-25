#!/bin/bash

set -e

# Configuration
AWS_REGION="eu-west-2"
ECR_REGISTRY="981686514879.dkr.ecr.eu-west-2.amazonaws.com"
REPOSITORY_NAME="stream-dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Building and Pushing Remaining Frontend Services${NC}"
echo "====================================================="

# Applications to build (creator-dashboard already built)
APPLICATIONS=(
    "admin-portal" 
    "analytics-dashboard"
    "support-system"
    "developer-console"
)

echo -e "${YELLOW}📤 Pushing creator-dashboard first...${NC}"
docker push 981686514879.dkr.ecr.eu-west-2.amazonaws.com/stream-dev:creator-dashboard-latest

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully pushed creator-dashboard${NC}"
else
    echo -e "${RED}❌ Failed to push creator-dashboard${NC}"
    exit 1
fi

# Build and push remaining applications
for APP in "${APPLICATIONS[@]}"
do
    echo ""
    echo -e "${BLUE}🐳 Building Docker image for $APP...${NC}"
    
    docker build -f packages/$APP/Dockerfile -t $ECR_REGISTRY/$REPOSITORY_NAME:$APP-latest .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully built $APP Docker image${NC}"
        
        echo -e "${YELLOW}📤 Pushing $APP to ECR...${NC}"
        docker push $ECR_REGISTRY/$REPOSITORY_NAME:$APP-latest
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Successfully pushed $APP${NC}"
        else
            echo -e "${RED}❌ Failed to push $APP${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Failed to build $APP Docker image${NC}"
        exit 1
    fi
done

echo ""
echo -e "${YELLOW}📝 Updating ECS services...${NC}"

# Update ECS services
ALL_APPS=("creator-dashboard" "${APPLICATIONS[@]}")
for APP in "${ALL_APPS[@]}"
do
    SERVICE_NAME="stream-dev-$APP"
    echo -e "${BLUE}🔄 Updating ECS service: $SERVICE_NAME${NC}"
    
    aws ecs update-service \
        --cluster stream-dev-cluster \
        --service $SERVICE_NAME \
        --force-new-deployment \
        --region $AWS_REGION \
        --no-cli-pager > /dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully triggered update for $SERVICE_NAME${NC}"
    else
        echo -e "${RED}❌ Failed to update $SERVICE_NAME${NC}"
    fi
done

echo ""
echo -e "${GREEN}🎉 All services have been built, pushed, and deployed!${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "Fixed applications with correct ALB paths:"
echo "• Creator Dashboard: http://stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com/creator-dashboard"
echo "• Admin Portal: http://stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com/admin-portal"
echo "• Analytics Dashboard: http://stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com/analytics-dashboard"
echo "• Support System: http://stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com/support-system"
echo "• Developer Console: http://stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com/developer-console"
echo "• Viewer Portal: http://stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com/viewer-portal (✅ Already working)"
echo ""
echo -e "${YELLOW}⏱️  Deployment Status:${NC}"
echo "ECS services are updating (2-3 minutes per service)"
echo "Monitor progress in AWS ECS console"