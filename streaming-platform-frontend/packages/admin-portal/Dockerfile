# Multi-stage build for Admin Portal
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json lerna.json ./
COPY packages/shared/package.json ./packages/shared/
COPY packages/ui/package.json ./packages/ui/
COPY packages/auth/package.json ./packages/auth/
COPY packages/admin-portal/package.json ./packages/admin-portal/
RUN npm ci --only=production && npm cache clean --force
COPY packages/shared ./packages/shared
COPY packages/ui ./packages/ui
COPY packages/auth ./packages/auth
COPY packages/admin-portal ./packages/admin-portal
RUN npm run build --workspace=packages/admin-portal

FROM nginx:1.25-alpine
RUN apk add --no-cache curl
COPY nginx.conf /etc/nginx/nginx.conf
COPY packages/admin-portal/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/packages/admin-portal/dist /usr/share/nginx/html
RUN echo '{"status":"healthy","app":"admin-portal","timestamp":"'$(date -Iseconds)'"}' > /usr/share/nginx/html/health
RUN chown -R nginx:nginx /usr/share/nginx/html && chmod -R 755 /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD curl -f http://localhost/health || exit 1
CMD ["nginx", "-g", "daemon off;"]