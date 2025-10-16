#!/bin/bash

# Fix Dockerfiles to work without workspace commands
set -e

echo "🔧 Fixing Dockerfiles..."

APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

for app in "${APPS[@]}"; do
    if [ -f "packages/$app/Dockerfile" ]; then
        echo "Fixing packages/$app/Dockerfile"
        
        # Create backup
        cp "packages/$app/Dockerfile" "packages/$app/Dockerfile.backup"
        
        # Fix the Dockerfile to work without workspace commands
        cat > "packages/$app/Dockerfile" << EOF
# Multi-stage build for $app
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY lerna.json ./
COPY shared/package.json ./shared/
COPY packages/shared/package.json ./packages/shared/
COPY packages/ui/package.json ./packages/ui/ 2>/dev/null || true
COPY packages/auth/package.json ./packages/auth/ 2>/dev/null || true
COPY packages/$app/package.json ./packages/$app/

# Install root dependencies
RUN npm install --legacy-peer-deps

# Copy source code
COPY shared ./shared
COPY packages/shared ./packages/shared
COPY packages/ui ./packages/ui 2>/dev/null || true
COPY packages/auth ./packages/auth 2>/dev/null || true
COPY packages/$app ./packages/$app

# Build the application
WORKDIR /app/packages/$app
RUN npm install --legacy-peer-deps && npm run build

# Production stage with Nginx
FROM nginx:1.25-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Copy nginx configuration or create default
COPY packages/$app/nginx.conf /etc/nginx/conf.d/default.conf 2>/dev/null || true
RUN if [ ! -f /etc/nginx/conf.d/default.conf ]; then echo 'server { listen 80; location / { root /usr/share/nginx/html; index index.html; try_files \$uri \$uri/ /index.html; } }' > /etc/nginx/conf.d/default.conf; fi

# Copy built application
COPY --from=builder /app/packages/$app/dist /usr/share/nginx/html

# Create health check endpoint
RUN echo '{"status":"healthy","app":"$app","timestamp":"'$(date -Iseconds)'"}' > /usr/share/nginx/html/health

# Set permissions
RUN chown -R nginx:nginx /usr/share/nginx/html && chmod -R 755 /usr/share/nginx/html

EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD curl -f http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF
        
        echo "✅ Fixed packages/$app/Dockerfile"
    fi
done

echo "🎉 All Dockerfiles fixed!"