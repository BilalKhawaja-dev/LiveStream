#!/bin/bash

echo "=== FIXING ASSET PATH ALIGNMENT FOR REMAINING SERVICES ==="
echo "Target: creator-dashboard, admin-portal, developer-console, analytics-dashboard, support-system"
echo

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="eu-west-2"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Services to fix (excluding viewer-portal which works)
SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

cd streaming-platform-frontend

for service in "${SERVICES[@]}"; do
    echo
    echo "=== FIXING $service ==="
    
    # 1. Fix Vite config for proper asset paths
    echo "📝 Updating Vite config for $service..."
    cat > "packages/$service/vite.config.ts" << EOF
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/$service/',
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        manualChunks: undefined,
        assetFileNames: 'assets/[name].[hash].[ext]',
        chunkFileNames: 'assets/[name].[hash].js',
        entryFileNames: 'assets/[name].[hash].js'
      }
    }
  },
  server: {
    port: 3000,
    host: '0.0.0.0'
  }
})
EOF

    # 2. Fix nginx config to properly serve assets
    echo "🌐 Updating nginx config for $service..."
    cat > "packages/$service/nginx.conf" << EOF
server {
    listen 3000;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Enable gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Handle static assets with proper caching
    location /$service/assets/ {
        alias /usr/share/nginx/html/assets/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    # Handle the main application
    location /$service/ {
        alias /usr/share/nginx/html/;
        try_files \$uri \$uri/ /index.html;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Fallback for any other requests
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

    # 3. Update Dockerfile to ensure proper build and asset placement
    echo "🐳 Updating Dockerfile for $service..."
    cat > "packages/$service/Dockerfile" << EOF
# Build stage
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY packages/$service/package*.json ./packages/$service/
COPY packages/shared/package*.json ./packages/shared/
COPY packages/ui/package*.json ./packages/ui/
COPY packages/auth/package*.json ./packages/auth/

# Install dependencies
RUN npm ci

# Copy source code
COPY packages/$service ./packages/$service
COPY packages/shared ./packages/shared
COPY packages/ui ./packages/ui
COPY packages/auth ./packages/auth
COPY tsconfig.json ./

# Build the application
WORKDIR /app/packages/$service
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy custom nginx config
COPY packages/$service/nginx.conf /etc/nginx/conf.d/default.conf

# Copy built application
COPY --from=builder /app/packages/$service/dist /usr/share/nginx/html

# Create health check script
RUN echo '#!/bin/sh' > /health-check.sh && \
    echo 'curl -f http://localhost:3000/health || exit 1' >> /health-check.sh && \
    chmod +x /health-check.sh

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /health-check.sh

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

    # 4. Build and push the fixed image
    echo "🔨 Building Docker image for $service..."
    docker build -f "packages/$service/Dockerfile" -t "$service:fixed" .
    
    if [ $? -eq 0 ]; then
        echo "✅ Build successful for $service"
        
        # Tag and push to ECR
        IMAGE_TAG="fixed-$(date +%Y%m%d-%H%M%S)"
        docker tag "$service:fixed" "$ECR_REGISTRY/stream-dev-$service:$IMAGE_TAG"
        docker tag "$service:fixed" "$ECR_REGISTRY/stream-dev-$service:latest"
        
        echo "📤 Pushing to ECR..."
        docker push "$ECR_REGISTRY/stream-dev-$service:$IMAGE_TAG"
        docker push "$ECR_REGISTRY/stream-dev-$service:latest"
        
        if [ $? -eq 0 ]; then
            echo "✅ Push successful for $service"
            
            # Force ECS service update
            echo "🚀 Updating ECS service..."
            aws ecs update-service \
                --cluster stream-dev-cluster \
                --service "stream-dev-$service" \
                --force-new-deployment \
                --no-cli-pager
            
            echo "✅ ECS service update initiated for $service"
        else
            echo "❌ Push failed for $service"
        fi
    else
        echo "❌ Build failed for $service"
    fi
    
    echo "--- Completed $service ---"
done

cd ..

echo
echo "=== ASSET PATH FIX SUMMARY ==="
echo "✅ Updated Vite configs with proper base paths"
echo "✅ Fixed nginx configs for asset serving"
echo "✅ Updated Dockerfiles for correct builds"
echo "✅ Rebuilt and pushed all images"
echo "✅ Initiated ECS deployments"
echo
echo "🔍 Monitor deployment progress with:"
echo "./monitor-deployment-progress.sh"
echo
echo "⏱️  Expected completion: 10-15 minutes"