# Multi-stage build for support-system
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built application
COPY --from=builder /app/dist /usr/share/nginx/html

# Create health check script
RUN echo '#!/bin/sh' > /health-check.sh &&     echo 'curl -f http://localhost:3003/health || exit 1' >> /health-check.sh &&     chmod +x /health-check.sh

# Expose port
EXPOSE 3003

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3     CMD /health-check.sh

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
