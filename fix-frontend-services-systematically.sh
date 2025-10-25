#!/bin/bash

echo "=== SYSTEMATIC FRONTEND SERVICE FIX ==="
echo "Problem: 5/6 services show white pages due to asset path issues"
echo "Solution: Fix configs based on working viewer-portal pattern"
echo

# Services to fix (viewer-portal already works)
BROKEN_SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")
ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

# Function to test service locally
test_service_locally() {
    local service=$1
    echo "=== Testing $service locally ==="
    
    cd "streaming-platform-frontend/packages/$service"
    
    # Build the service
    echo "Building $service..."
    npm run build
    
    if [ ! -d "dist" ]; then
        echo "❌ Build failed for $service"
        cd ../../..
        return 1
    fi
    
    # Check if assets were generated
    asset_count=$(find dist -name "*.js" -o -name "*.css" 2>/dev/null | wc -l)
    echo "Generated $asset_count asset files"
    
    # Build Docker image locally
    echo "Building Docker image for $service..."
    docker build -t "test-$service:local" . > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "❌ Docker build failed for $service"
        cd ../../..
        return 1
    fi
    
    # Test container locally
    echo "Testing container locally..."
    docker run -d --name "test-$service" -p 8080:3000 "test-$service:local" > /dev/null 2>&1
    
    # Wait for container to start
    sleep 3
    
    # Test HTML
    html_status=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:8080/$service/")
    echo "HTML status: $html_status"
    
    # Test if we can get the HTML content and extract asset paths
    if [ "$html_status" = "200" ]; then
        html_content=$(curl -s "http://localhost:8080/$service/")
        js_files=$(echo "$html_content" | grep -o 'src="[^"]*\.js"' | head -1 | sed 's/src="//g' | sed 's/"//g')
        
        if [ -n "$js_files" ]; then
            # Test first JS asset
            if [[ $js_files == /* ]]; then
                js_url="http://localhost:8080$js_files"
            else
                js_url="http://localhost:8080/$service/$js_files"
            fi
            
            js_status=$(curl -s -w "%{http_code}" -o /dev/null "$js_url")
            echo "JS asset status: $js_status"
            
            if [ "$js_status" = "200" ]; then
                echo "✅ $service works locally"
                docker stop "test-$service" > /dev/null 2>&1
                docker rm "test-$service" > /dev/null 2>&1
                cd ../../..
                return 0
            else
                echo "❌ $service JS assets fail locally"
            fi
        else
            echo "❌ No JS assets found in HTML"
        fi
    else
        echo "❌ $service HTML fails locally"
    fi
    
    # Cleanup
    docker stop "test-$service" > /dev/null 2>&1
    docker rm "test-$service" > /dev/null 2>&1
    cd ../../..
    return 1
}

# Function to fix service configuration
fix_service_config() {
    local service=$1
    echo "=== Fixing $service configuration ==="
    
    # Fix vite.config.ts - use viewer-portal pattern
    cat > "streaming-platform-frontend/packages/$service/vite.config.ts" << EOF
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
  plugins: [react()],
  base: '/$service/',
  resolve: {
    alias: {
      '@streaming-platform/shared': resolve(__dirname, '../../shared'),
      '@streaming/shared': resolve(__dirname, '../shared/src'),
      '@streaming/ui': resolve(__dirname, '../ui/src'),
      '@streaming/auth': resolve(__dirname, '../auth/src'),
    },
  },
  server: {
    port: 3000,
    host: true,
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
});
EOF

    # Fix nginx.conf - use viewer-portal pattern
    cat > "streaming-platform-frontend/packages/$service/nginx.conf" << EOF
server {
    listen 3000;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Handle React Router (SPA routing) - serve everything from root
    location / {
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Handle $service specific routing (ALB forwards /$service/* here)
    location /$service/ {
        alias /usr/share/nginx/html/;
        try_files \$uri \$uri/ /index.html;
    }
    
    # Handle $service assets specifically
    location ~ ^/$service/assets/(.*)\$ {
        alias /usr/share/nginx/html/assets/\$1;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check endpoints
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location /healthz {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
    
    # Prevent access to sensitive files
    location ~ /\. {
        deny all;
    }
}
EOF

    echo "✅ Fixed configuration for $service"
}

# Function to push service to ECR
push_service_to_ecr() {
    local service=$1
    echo "=== Pushing $service to ECR ==="
    
    cd "streaming-platform-frontend/packages/$service"
    
    # Build for production
    echo "Building $service for production..."
    npm run build
    
    # Build Docker image
    timestamp=$(date +%s)
    docker build -t "stream-$service:fixed-$timestamp" .
    
    # Tag for ECR
    docker tag "stream-$service:fixed-$timestamp" "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:fixed-$timestamp"
    docker tag "stream-$service:fixed-$timestamp" "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:latest"
    
    # Push to ECR
    echo "Pushing to ECR..."
    docker push "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:fixed-$timestamp"
    docker push "992382474575.dkr.ecr.eu-west-2.amazonaws.com/stream-$service:latest"
    
    # Force ECS update
    echo "Updating ECS service..."
    aws ecs update-service \
        --cluster stream-dev-cluster \
        --service "stream-dev-$service" \
        --force-new-deployment \
        --query 'service.[serviceName,status]' \
        --output table
    
    cd ../../..
    echo "✅ $service pushed and deployed"
}

# Function to test service on ALB
test_service_on_alb() {
    local service=$1
    echo "=== Testing $service on ALB ==="
    
    # Wait for deployment
    echo "Waiting 30 seconds for deployment..."
    sleep 30
    
    # Test HTML
    html_url="http://$ALB_DNS/$service/"
    html_status=$(curl -s -w "%{http_code}" -o /dev/null "$html_url")
    echo "HTML status: $html_status"
    
    if [ "$html_status" = "200" ]; then
        # Test assets
        html_content=$(curl -s "$html_url")
        js_files=$(echo "$html_content" | grep -o 'src="[^"]*\.js"' | head -1 | sed 's/src="//g' | sed 's/"//g')
        
        if [ -n "$js_files" ]; then
            if [[ $js_files == /* ]]; then
                js_url="http://$ALB_DNS$js_files"
            else
                js_url="http://$ALB_DNS/$service/$js_files"
            fi
            
            js_status=$(curl -s -w "%{http_code}" -o /dev/null "$js_url")
            echo "JS asset status: $js_status"
            
            if [ "$js_status" = "200" ]; then
                echo "✅ $service working on ALB"
                return 0
            else
                echo "❌ $service JS assets fail on ALB"
                return 1
            fi
        else
            echo "❌ No JS assets found"
            return 1
        fi
    else
        echo "❌ $service HTML fails on ALB"
        return 1
    fi
}

# Main execution
echo "Step 1: ECR Login"
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 992382474575.dkr.ecr.eu-west-2.amazonaws.com

echo
echo "Step 2: Process each service systematically"

for service in "${BROKEN_SERVICES[@]}"; do
    echo
    echo "=========================================="
    echo "PROCESSING: $service"
    echo "=========================================="
    
    # Fix configuration
    fix_service_config "$service"
    
    # Test locally
    if test_service_locally "$service"; then
        echo "✅ $service works locally, pushing to ECR..."
        
        # Push to ECR and deploy
        push_service_to_ecr "$service"
        
        # Test on ALB
        if test_service_on_alb "$service"; then
            echo "🎉 $service FULLY WORKING"
        else
            echo "⚠️  $service deployed but still has issues"
        fi
    else
        echo "❌ $service still broken locally, skipping ECR push"
        echo "Manual investigation needed for $service"
    fi
    
    echo "=========================================="
done

echo
echo "=== FINAL STATUS CHECK ==="
for service in "${BROKEN_SERVICES[@]}"; do
    html_status=$(curl -s -w "%{http_code}" -o /dev/null "http://$ALB_DNS/$service/")
    if [ "$html_status" = "200" ]; then
        html_content=$(curl -s "http://$ALB_DNS/$service/")
        js_files=$(echo "$html_content" | grep -o 'src="[^"]*\.js"' | head -1 | sed 's/src="//g' | sed 's/"//g')
        if [ -n "$js_files" ]; then
            if [[ $js_files == /* ]]; then
                js_url="http://$ALB_DNS$js_files"
            else
                js_url="http://$ALB_DNS/$service/$js_files"
            fi
            js_status=$(curl -s -w "%{http_code}" -o /dev/null "$js_url")
            if [ "$js_status" = "200" ]; then
                echo "✅ $service: WORKING"
            else
                echo "❌ $service: HTML OK, Assets FAIL"
            fi
        else
            echo "❌ $service: No assets found"
        fi
    else
        echo "❌ $service: HTML FAIL"
    fi
done

echo
echo "=== PROCESS COMPLETE ==="
echo "Services should now work correctly!"