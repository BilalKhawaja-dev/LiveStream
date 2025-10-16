# Multi-stage build for admin-portal
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY lerna.json ./
COPY shared/package.json ./shared/
COPY packages/shared/package.json ./packages/shared/
COPY packages/ui/package.json ./packages/ui/ 2>/dev/null || true
COPY packages/auth/package.json ./packages/auth/ 2>/dev/null || true
COPY packages/admin-portal/package.json ./packages/admin-portal/

# Install root dependencies
RUN npm install --legacy-peer-deps

# Copy source code
COPY shared ./shared
COPY packages/shared ./packages/shared
COPY packages/ui ./packages/ui 2>/dev/null || true
COPY packages/auth ./packages/auth 2>/dev/null || true
COPY packages/admin-portal ./packages/admin-portal

# Build the application
WORKDIR /app/packages/admin-portal
RUN npm install --legacy-peer-deps && npm run build

# Production stage with Nginx
FROM nginx:1.25-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Copy nginx configuration
COPY packages/admin-portal/nginx.conf /etc/nginx/conf.d/default.conf 2>/dev/null || echo "server { listen 80; location / { root /usr/share/nginx/html; index index.html; try_files \$uri \$uri/ /index.html; } }" > /etc/nginx/conf.d/default.conf

# Copy built application
COPY --from=builder /app/packages/admin-portal/dist /usr/share/nginx/html

# Create health check endpoint
RUN echo '{"status":"healthy","app":"admin-portal","timestamp":"'2025-10-15T13:59:09+0100'"}' > /usr/share/nginx/html/health

# Set permissions
RUN chown -R nginx:nginx /usr/share/nginx/html && chmod -R 755 /usr/share/nginx/html

EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD curl -f http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
