#!/bin/bash

# Push containers to ECR script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if ECR URL is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: ECR repository URL required${NC}"
    echo "Usage: $0 <ecr-repository-url>"
    echo ""
    echo "Get your ECR URL from Terraform:"
    echo "  terraform output ecr_repository_url"
    echo ""
    echo "Example:"
    echo "  $0 123456789012.dkr.ecr.us-east-1.amazonaws.com/streaming-platform"
    exit 1
fi

ECR_URL="$1"
TAG=${IMAGE_TAG:-"latest"}
REGION=$(echo "$ECR_URL" | cut -d'.' -f4)

# Applications to push
APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

echo -e "${GREEN}🚀 Pushing containers to ECR${NC}"
echo "ECR URL: $ECR_URL"
echo "Region: $REGION"
echo "Tag: $TAG"
echo ""

# Login to ECR
echo -e "${BLUE}🔐 Logging in to ECR...${NC}"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_URL" || {
    echo -e "${RED}❌ Failed to login to ECR. Check your AWS credentials and region.${NC}"
    exit 1
}

echo -e "${GREEN}✅ Successfully logged in to ECR${NC}"
echo ""

# Function to push image
push_app() {
    local app=$1
    local local_image="streaming-platform/$app:$TAG"
    local ecr_image="$ECR_URL:$app-$TAG"
    
    echo -e "${YELLOW}📤 Pushing $app...${NC}"
    
    # Check if local image exists
    if ! docker image inspect "$local_image" >/dev/null 2>&1; then
        echo -e "${RED}❌ Local image $local_image not found. Did you run build-containers-fixed.sh first?${NC}"
        return 1
    fi
    
    # Tag for ECR
    docker tag "$local_image" "$ecr_image" || {
        echo -e "${RED}❌ Failed to tag $app for ECR${NC}"
        return 1
    }
    
    # Push to ECR
    docker push "$ecr_image" || {
        echo -e "${RED}❌ Failed to push $app to ECR${NC}"
        return 1
    }
    
    echo -e "${GREEN}✅ Successfully pushed $app${NC}"
    return 0
}

# Push all applications
failed_pushes=()
successful_pushes=()

for app in "${APPS[@]}"; do
    if push_app "$app"; then
        successful_pushes+=("$app")
    else
        failed_pushes+=("$app")
    fi
    echo ""
done

# Summary
echo -e "${BLUE}📊 Push Summary${NC}"
echo "============="

if [ ${#successful_pushes[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Successfully pushed (${#successful_pushes[@]})${NC}"
    for app in "${successful_pushes[@]}"; do
        echo "  - $app"
    done
fi

if [ ${#failed_pushes[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed pushes (${#failed_pushes[@]})${NC}"
    for app in "${failed_pushes[@]}"; do
        echo "  - $app"
    done
fi

if [ ${#failed_pushes[@]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All containers pushed successfully to ECR!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next steps:${NC}"
    echo "1. Update ECS services to use new images:"
    echo "   CLUSTER_NAME=\$(terraform output -raw ecs_cluster_name)"
    echo "   aws ecs update-service --cluster \$CLUSTER_NAME --service streaming-platform-dev-viewer-portal --force-new-deployment"
    echo ""
    echo "2. Check ECS service status:"
    echo "   aws ecs describe-services --cluster \$CLUSTER_NAME --services streaming-platform-dev-viewer-portal"
    echo ""
    echo "3. Get your application URL:"
    echo "   terraform output application_url"
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some pushes failed. Please check the errors above.${NC}"
    exit 1
fi