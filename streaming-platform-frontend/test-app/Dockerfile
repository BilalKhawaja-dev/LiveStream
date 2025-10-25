# Multi-stage build for test app
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig*.json ./
COPY vite.config.ts ./

# Install dependencies
RUN npm install

# Copy source code
COPY src ./src/
COPY index.html ./
COPY public ./public/

# Build the application
RUN npm run build

# Verify build output exists
RUN ls -la dist/ && test -f dist/index.html

# Production stage
FROM nginx:alpine

# Install curl for health checks
RUN apk update && apk upgrade && apk add --no-cache curl

# Copy built application from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create health check endpoint
RUN echo '<!DOCTYPE html><html><body><h1>OK</h1></body></html>' > /usr/share/nginx/html/health

# Expose the application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
