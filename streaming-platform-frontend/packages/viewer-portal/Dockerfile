# Multi-stage build for Viewer Portal
# Stage 1: Build the application
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY lerna.json ./
COPY packages/shared/package.json ./packages/shared/
COPY packages/ui/package.json ./packages/ui/
COPY packages/auth/package.json ./packages/auth/
COPY packages/viewer-portal/package.json ./packages/viewer-portal/

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY packages/shared ./packages/shared
COPY packages/ui ./packages/ui
COPY packages/auth ./packages/auth
COPY packages/viewer-portal ./packages/viewer-portal

# Build the application
RUN npm run build --workspace=packages/viewer-portal

# Stage 2: Production image with Nginx
FROM nginx:1.25-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY packages/viewer-portal/nginx.conf /etc/nginx/conf.d/default.conf

# Copy built application from builder stage
COPY --from=builder /app/packages/viewer-portal/dist /usr/share/nginx/html

# Create health check endpoint
RUN echo '{"status":"healthy","app":"viewer-portal","timestamp":"'$(date -Iseconds)'"}' > /usr/share/nginx/html/health

# Set proper permissions
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]