#!/bin/bash

# Build script for all frontend application containers
# This script builds optimized Docker images for all six frontend applications

set -e

# Configuration
REGISTRY_URL=${REGISTRY_URL:-""}
TAG=${TAG:-"latest"}
ENVIRONMENT=${ENVIRONMENT:-"dev"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Applications to build
APPLICATIONS=(
    "viewer-portal:3000"
    "creator-dashboard:3001"
    "admin-portal:3002"
    "support-system:3003"
    "analytics-dashboard:3004"
    "developer-console:3005"
)

echo -e "${BLUE}🚀 Starting container build process...${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}Tag: ${TAG}${NC}"

# Function to build a single application
build_application() {
    local app_info=$1
    local app_name=$(echo $app_info | cut -d':' -f1)
    local app_port=$(echo $app_info | cut -d':' -f2)
    
    echo -e "\n${YELLOW}📦 Building ${app_name}...${NC}"
    
    # Build the Docker image from root context
    local image_name="streaming-platform-${app_name}"
    local full_image_name="${REGISTRY_URL}${image_name}:${TAG}"
    
    if [ -n "$REGISTRY_URL" ]; then
        full_image_name="${REGISTRY_URL}/${image_name}:${TAG}"
    else
        full_image_name="${image_name}:${TAG}"
    fi
    
    echo -e "${BLUE}Building image: ${full_image_name}${NC}"
    
    # Build with build args for environment-specific configuration
    # Use the package-specific Dockerfile but build from root context
    docker build \
        --build-arg ENVIRONMENT=${ENVIRONMENT} \
        --build-arg PORT=${app_port} \
        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
        --build-arg VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
        -f "packages/${app_name}/Dockerfile" \
        -t "${full_image_name}" \
        .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully built ${app_name}${NC}"
        
        # Tag with additional tags
        docker tag "${full_image_name}" "${image_name}:latest"
        docker tag "${full_image_name}" "${image_name}:${ENVIRONMENT}"
        
        # Security scan (if trivy is available)
        if command -v trivy &> /dev/null; then
            echo -e "${BLUE}🔍 Running security scan for ${app_name}...${NC}"
            trivy image --exit-code 0 --severity HIGH,CRITICAL "${full_image_name}"
        fi
        
        # Push to registry if specified
        if [ -n "$REGISTRY_URL" ]; then
            echo -e "${BLUE}📤 Pushing ${full_image_name} to registry...${NC}"
            docker push "${full_image_name}"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Successfully pushed ${app_name}${NC}"
            else
                echo -e "${RED}❌ Failed to push ${app_name}${NC}"
                return 1
            fi
        fi
    else
        echo -e "${RED}❌ Failed to build ${app_name}${NC}"
        return 1
    fi

}

# Function to run container tests
test_container() {
    local app_info=$1
    local app_name=$(echo $app_info | cut -d':' -f1)
    local app_port=$(echo $app_info | cut -d':' -f2)
    
    echo -e "\n${YELLOW}🧪 Testing ${app_name} container...${NC}"
    
    local image_name="streaming-platform-${app_name}:${TAG}"
    local container_name="test-${app_name}-${RANDOM}"
    
    # Run container for testing
    docker run -d --name "${container_name}" -p "${app_port}:${app_port}" "${image_name}"
    
    # Wait for container to start
    sleep 10
    
    # Test health endpoint
    if curl -f "http://localhost:${app_port}/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Health check passed for ${app_name}${NC}"
    else
        echo -e "${RED}❌ Health check failed for ${app_name}${NC}"
    fi
    
    # Clean up test container
    docker stop "${container_name}" > /dev/null 2>&1
    docker rm "${container_name}" > /dev/null 2>&1
}

# Main build process
main() {
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}❌ Please run this script from the streaming-platform-frontend directory${NC}"
        exit 1
    fi
    
    # Build all applications
    local failed_builds=()
    
    for app_info in "${APPLICATIONS[@]}"; do
        if ! build_application "$app_info"; then
            failed_builds+=("$(echo $app_info | cut -d':' -f1)")
        fi
    done
    
    # Report results
    echo -e "\n${BLUE}📊 Build Summary:${NC}"
    
    if [ ${#failed_builds[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All applications built successfully!${NC}"
        
        # Run container tests if requested
        if [ "$1" = "--test" ]; then
            echo -e "\n${BLUE}🧪 Running container tests...${NC}"
            for app_info in "${APPLICATIONS[@]}"; do
                test_container "$app_info"
            done
        fi
        
        echo -e "\n${GREEN}🎉 Container build process completed successfully!${NC}"
        echo -e "${BLUE}To run all applications: docker-compose up${NC}"
        
    else
        echo -e "${RED}❌ Failed to build: ${failed_builds[*]}${NC}"
        exit 1
    fi
}

# Show usage if help requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --test          Run container tests after building"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  REGISTRY_URL    Docker registry URL (optional)"
    echo "  TAG             Image tag (default: latest)"
    echo "  ENVIRONMENT     Build environment (default: dev)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Build all containers"
    echo "  $0 --test                            # Build and test containers"
    echo "  REGISTRY_URL=my-registry.com $0      # Build and push to registry"
    echo "  TAG=v1.0.0 $0                       # Build with specific tag"
    exit 0
fi

# Run main function
main "$@"