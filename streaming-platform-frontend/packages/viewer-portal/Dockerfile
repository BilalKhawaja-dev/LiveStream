# Multi-stage build for optimized production image
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy root package files first
COPY package*.json ./
COPY lerna.json ./
COPY tsconfig.json ./
COPY .env ./

# Copy all package files for dependency resolution
COPY packages/viewer-portal/package*.json ./packages/viewer-portal/
COPY packages/shared/package*.json ./packages/shared/
COPY packages/ui/package*.json ./packages/ui/
COPY packages/auth/package*.json ./packages/auth/

# Install dependencies from root (this handles workspace linking)
RUN npm install

# Copy all source code
COPY packages/viewer-portal ./packages/viewer-portal/
COPY packages/shared ./packages/shared/
COPY packages/ui ./packages/ui/
COPY packages/auth ./packages/auth/

# Build shared packages first (in correct order)
WORKDIR /app/packages/shared
RUN npm run build

WORKDIR /app/packages/ui
RUN npm run build

WORKDIR /app/packages/auth
RUN npm run build

# Build the main application with environment variables
WORKDIR /app/packages/viewer-portal
ENV NODE_ENV=production
RUN npm run build

# Verify build output exists
RUN ls -la dist/ && test -f dist/index.html

# Production stage
FROM nginx:alpine

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache curl

# Copy built application from builder stage
COPY --from=builder /app/packages/viewer-portal/dist /usr/share/nginx/html

# Copy nginx configuration
COPY packages/viewer-portal/nginx.conf /etc/nginx/conf.d/default.conf

# Create health check endpoint
RUN echo '<!DOCTYPE html><html><body><h1>OK</h1></body></html>' > /usr/share/nginx/html/health

# Expose the application port
EXPOSE 3000

# Health check with better error handling
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start nginx as root (common pattern for containers)
CMD ["nginx", "-g", "daemon off;"]
