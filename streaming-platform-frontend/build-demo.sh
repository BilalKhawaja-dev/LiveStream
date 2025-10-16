#!/bin/bash

# Demo build script - creates simple working containers for ECS
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

echo -e "${GREEN}🚀 Building Demo Containers for ECS${NC}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo "Region: $REGION"
echo ""
echo -e "${YELLOW}📝 Note: Creating simple demo containers that will work with ECS${NC}"
echo "These containers will serve basic HTML pages for each application."
echo ""

# Check Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Applications to build
APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

# Function to create a simple demo container
build_demo_app() {
    local app=$1
    echo -e "${YELLOW}🔨 Building demo container for $app...${NC}"
    
    # Create a temporary directory for this app
    mkdir -p "temp-$app"
    
    # Create a simple HTML page
    cat > "temp-$app/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Streaming Platform - ${app^}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
        .container {
            text-align: center;
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 2.5em; margin-bottom: 20px; }
        .status { color: #4ade80; font-weight: bold; }
        .info { margin: 20px 0; }
        .footer { margin-top: 40px; opacity: 0.8; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎬 Streaming Platform</h1>
        <h2>${app^}</h2>
        <p class="status">✅ Container Running Successfully</p>
        <div class="info">
            <p><strong>Application:</strong> ${app}</p>
            <p><strong>Status:</strong> Deployed on ECS</p>
            <p><strong>Region:</strong> ${REGION}</p>
            <p><strong>Container:</strong> ${REGISTRY}/${app}:${TAG}</p>
        </div>
        <div class="footer">
            <p>Infrastructure deployed with Terraform</p>
            <p>Containers running on AWS ECS</p>
        </div>
    </div>
    
    <script>
        // Add some basic interactivity
        document.addEventListener('DOMContentLoaded', function() {
            console.log('${app^} container loaded successfully');
            
            // Health check endpoint simulation
            if (window.location.pathname === '/health') {
                document.body.innerHTML = '<h1>OK</h1><p>Container is healthy</p>';
            }
        });
    </script>
</body>
</html>
EOF

    # Create nginx config
    cat > "temp-$app/nginx.conf" << EOF
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;
    
    # Health check endpoint
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
    
    # Main application
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

    # Create Dockerfile
    cat > "temp-$app/Dockerfile" << EOF
FROM nginx:alpine

# Copy HTML content
COPY index.html /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create health check file
RUN echo 'OK' > /usr/share/nginx/html/health

# Set permissions
RUN chown -R nginx:nginx /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

    # Build the container
    docker build -t "$REGISTRY/$app:$TAG" "temp-$app/" || {
        echo -e "${RED}❌ Failed to build $app${NC}"
        rm -rf "temp-$app"
        return 1
    }
    
    # Clean up
    rm -rf "temp-$app"
    
    echo -e "${GREEN}✅ Successfully built demo container for $app${NC}"
    return 0
}

# Build all demo applications
failed_builds=()
successful_builds=()

for app in "${APPS[@]}"; do
    if build_demo_app "$app"; then
        successful_builds+=("$app")
    else
        failed_builds+=("$app")
    fi
    echo ""
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

if [ ${#successful_builds[@]} -gt 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 Demo containers built successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 What these containers do:${NC}"
    echo "• Serve a demo page for each application"
    echo "• Include health check endpoints (/health)"
    echo "• Work perfectly with ECS and ALB"
    echo "• Show deployment status and info"
    echo ""
    echo -e "${BLUE}📤 Next steps:${NC}"
    echo "1. Deploy infrastructure (if not done):"
    echo "   terraform init && terraform apply"
    echo ""
    echo "2. Push containers to ECR:"
    echo "   ECR_URL=\$(terraform output -raw ecr_repository_url)"
    echo "   ./push-to-ecr.sh \$ECR_URL"
    echo ""
    echo "3. Access your streaming platform:"
    echo "   terraform output application_url"
    echo ""
    echo -e "${YELLOW}💡 These demo containers will prove your ECS deployment works!${NC}"
    echo "You can replace them with full React apps later."
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ All builds failed. Check Docker installation.${NC}"
    exit 1
fi