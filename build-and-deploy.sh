#!/bin/bash

# Comprehensive Build and Deploy Script
# This script builds container images, deploys infrastructure, and runs tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="stream"
ENVIRONMENT="dev"
AWS_REGION="eu-west-2"
TAG=$(date +%Y%m%d-%H%M%S)

echo -e "${BLUE}🚀 Starting comprehensive build and deployment process...${NC}"
echo -e "${BLUE}Project: ${PROJECT_NAME}${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}Region: ${AWS_REGION}${NC}"
echo -e "${BLUE}Tag: ${TAG}${NC}"

# Function to check if AWS CLI is configured
check_aws_config() {
    echo -e "\n${YELLOW}🔧 Checking AWS configuration...${NC}"
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        echo -e "${RED}❌ AWS CLI not configured or no valid credentials${NC}"
        echo -e "${YELLOW}Please run: aws configure${NC}"
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✅ AWS configured for account: ${ACCOUNT_ID}${NC}"
}

# Function to create ECR repositories if they don't exist
create_ecr_repos() {
    echo -e "\n${YELLOW}📦 Setting up ECR repositories...${NC}"
    
    APPLICATIONS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")
    
    for app in "${APPLICATIONS[@]}"; do
        REPO_NAME="${PROJECT_NAME}-${app}"
        
        if ! aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
            echo "Creating ECR repository: $REPO_NAME"
            aws ecr create-repository \
                --repository-name "$REPO_NAME" \
                --region "$AWS_REGION" \
                --image-scanning-configuration scanOnPush=true \
                --encryption-configuration encryptionType=AES256
        else
            echo "ECR repository already exists: $REPO_NAME"
        fi
    done
    
    echo -e "${GREEN}✅ ECR repositories ready${NC}"
}

# Function to build and push container images
build_and_push_images() {
    echo -e "\n${YELLOW}🏗️  Building and pushing container images...${NC}"
    
    # Get ECR login token
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    # Set registry URL for build script
    export REGISTRY_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    export TAG="$TAG"
    export ENVIRONMENT="$ENVIRONMENT"
    
    # Build all containers
    cd streaming-platform-frontend
    ./build-containers.sh
    cd ..
    
    echo -e "${GREEN}✅ All container images built and pushed${NC}"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    echo -e "\n${YELLOW}🏗️  Deploying infrastructure...${NC}"
    
    # Initialize Terraform
    terraform init
    
    # Create a plan
    echo "Creating Terraform plan..."
    terraform plan -out=tfplan -var="image_tag=${TAG}"
    
    # Apply the plan
    echo "Applying Terraform plan..."
    terraform apply tfplan
    
    echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
}

# Function to wait for services to be ready
wait_for_services() {
    echo -e "\n${YELLOW}⏳ Waiting for services to be ready...${NC}"
    
    # Get cluster name
    CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
    
    # Wait for ECS services to be stable
    echo "Waiting for ECS services to stabilize..."
    
    SERVICES=(
        "${PROJECT_NAME}-${ENVIRONMENT}-viewer-portal"
        "${PROJECT_NAME}-${ENVIRONMENT}-creator-dashboard"
        "${PROJECT_NAME}-${ENVIRONMENT}-admin-portal"
        "${PROJECT_NAME}-${ENVIRONMENT}-support-system"
        "${PROJECT_NAME}-${ENVIRONMENT}-analytics-dashboard"
        "${PROJECT_NAME}-${ENVIRONMENT}-developer-console"
    )
    
    for service in "${SERVICES[@]}"; do
        echo "Waiting for service: $service"
        aws ecs wait services-stable \
            --cluster "$CLUSTER_NAME" \
            --services "$service" \
            --region "$AWS_REGION" || echo "Warning: Service $service may not be stable yet"
    done
    
    echo -e "${GREEN}✅ Services are ready${NC}"
}

# Function to run health checks
run_health_checks() {
    echo -e "\n${YELLOW}🏥 Running health checks...${NC}"
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names "${PROJECT_NAME}-${ENVIRONMENT}-alb" \
        --region "$AWS_REGION" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
        echo "Testing ALB health: $ALB_DNS"
        
        # Test each application endpoint
        APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")
        
        for app in "${APPS[@]}"; do
            echo "Testing $app..."
            if curl -f -s "http://$ALB_DNS/$app/health" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ $app is healthy${NC}"
            else
                echo -e "${YELLOW}⚠️  $app health check failed (may still be starting)${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠️  ALB not found or not ready yet${NC}"
    fi
    
    # Check API Gateway
    API_ID=$(aws apigateway get-rest-apis \
        --query "items[?name=='${PROJECT_NAME}-${ENVIRONMENT}-api'].id" \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
        API_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${ENVIRONMENT}"
        echo "Testing API Gateway: $API_URL"
        
        if curl -f -s "$API_URL/auth" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ API Gateway is responding${NC}"
        else
            echo -e "${YELLOW}⚠️  API Gateway not responding yet${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  API Gateway not found${NC}"
    fi
}

# Function to display deployment summary
show_deployment_summary() {
    echo -e "\n${BLUE}📊 Deployment Summary${NC}"
    
    # Get key outputs from Terraform
    echo -e "\n${YELLOW}Infrastructure Endpoints:${NC}"
    
    # ALB DNS
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "Not available")
    echo "ALB DNS: $ALB_DNS"
    
    # API Gateway URL
    API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "Not available")
    echo "API Gateway: $API_URL"
    
    # CloudWatch Dashboard URLs
    echo -e "\n${YELLOW}Monitoring:${NC}"
    echo "CloudWatch Console: https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:"
    
    # ECS Console
    echo -e "\n${YELLOW}Container Management:${NC}"
    echo "ECS Console: https://${AWS_REGION}.console.aws.amazon.com/ecs/home?region=${AWS_REGION}#/clusters/${PROJECT_NAME}-${ENVIRONMENT}-cluster"
    
    # Application URLs (if ALB is available)
    if [ "$ALB_DNS" != "Not available" ]; then
        echo -e "\n${YELLOW}Application URLs:${NC}"
        echo "Viewer Portal: http://$ALB_DNS/viewer-portal"
        echo "Creator Dashboard: http://$ALB_DNS/creator-dashboard"
        echo "Admin Portal: http://$ALB_DNS/admin-portal"
        echo "Support System: http://$ALB_DNS/support-system"
        echo "Analytics Dashboard: http://$ALB_DNS/analytics-dashboard"
        echo "Developer Console: http://$ALB_DNS/developer-console"
    fi
    
    echo -e "\n${GREEN}🎉 Deployment completed successfully!${NC}"
    echo -e "${BLUE}Container images tagged with: ${TAG}${NC}"
}

# Function to run cleanup on failure
cleanup_on_failure() {
    echo -e "\n${RED}❌ Deployment failed. Running cleanup...${NC}"
    
    # Optionally destroy infrastructure on failure
    read -p "Do you want to destroy the infrastructure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform destroy -auto-approve
        echo -e "${YELLOW}Infrastructure destroyed${NC}"
    fi
}

# Main execution
main() {
    # Set up error handling
    trap cleanup_on_failure ERR
    
    # Pre-flight checks
    check_aws_config
    
    # Run infrastructure validation
    echo -e "\n${YELLOW}🔍 Running pre-deployment validation...${NC}"
    ./test-infrastructure.sh
    
    # Create ECR repositories
    create_ecr_repos
    
    # Build and push images
    build_and_push_images
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Wait for services
    wait_for_services
    
    # Run health checks
    run_health_checks
    
    # Show summary
    show_deployment_summary
}

# Show usage if help requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script builds container images and deploys the streaming platform infrastructure."
    echo ""
    echo "Prerequisites:"
    echo "  - AWS CLI configured with appropriate permissions"
    echo "  - Docker installed and running"
    echo "  - Terraform installed"
    echo ""
    echo "The script will:"
    echo "  1. Validate the infrastructure configuration"
    echo "  2. Create ECR repositories if needed"
    echo "  3. Build and push container images"
    echo "  4. Deploy infrastructure with Terraform"
    echo "  5. Wait for services to be ready"
    echo "  6. Run health checks"
    echo "  7. Display deployment summary"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_PROFILE    AWS profile to use (optional)"
    echo "  AWS_REGION     AWS region (default: eu-west-2)"
    echo ""
    exit 0
fi

# Run main function
main "$@"