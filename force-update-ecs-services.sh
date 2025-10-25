#!/bin/bash
# Force update ECS services to pull new images with fixed base paths

set -e

# Configuration
CLUSTER_NAME="stream-dev-cluster"
AWS_REGION="eu-west-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Force updating ECS services to pull new fixed images${NC}"
echo "=================================================="

# Services to update
SERVICES=(
    "stream-dev-viewer-portal"
    "stream-dev-creator-dashboard" 
    "stream-dev-admin-portal"
    "stream-dev-analytics-dashboard"
    "stream-dev-support-system"
    "stream-dev-developer-console"
)

# Force update each service
for SERVICE in "${SERVICES[@]}"; do
    echo -e "${YELLOW}🔄 Force updating $SERVICE...${NC}"
    
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE \
        --force-new-deployment \
        --region $AWS_REGION
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully triggered update for $SERVICE${NC}"
    else
        echo -e "${RED}❌ Failed to update $SERVICE${NC}"
    fi
    echo "---"
done

echo -e "${GREEN}🎉 All ECS services have been triggered for update!${NC}"
echo ""
echo -e "${BLUE}📊 Monitoring deployment status...${NC}"

# Wait a bit and check service status
sleep 10

for SERVICE in "${SERVICES[@]}"; do
    echo -e "${YELLOW}📊 Checking $SERVICE status...${NC}"
    
    aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE \
        --region $AWS_REGION \
        --query 'services[0].{ServiceName:serviceName,Status:status,RunningCount:runningCount,PendingCount:pendingCount,DesiredCount:desiredCount}' \
        --output table
    
    echo "---"
done

echo -e "${BLUE}💡 Next steps:${NC}"
echo "1. Monitor ECS console for deployment progress"
echo "2. Test applications once deployments complete"
echo "3. Check CloudWatch logs if any issues persist"
echo ""
echo -e "${GREEN}🔧 Fix Summary:${NC}"
echo "• Fixed Vite base paths from '/app-name/' to '/'"
echo "• Rebuilt and pushed all Docker images"
echo "• Forced ECS service updates to pull new images"
echo "• Applications should now load properly without blank pages"