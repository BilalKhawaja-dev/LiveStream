# Multi-stage build for React applications
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY lerna.json ./
COPY packages/*/package*.json ./packages/*/

# Install dependencies
RUN npm ci --only=production

# Build shared packages
FROM base AS builder
WORKDIR /app
COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Build shared packages first
RUN npm run build:shared

# Build specific application (passed as build arg)
ARG APP_NAME
RUN npm run build:${APP_NAME}

# Production image
FROM nginx:alpine AS runner
WORKDIR /usr/share/nginx/html

# Copy built application
ARG APP_NAME
COPY --from=builder /app/packages/${APP_NAME}/dist .

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]