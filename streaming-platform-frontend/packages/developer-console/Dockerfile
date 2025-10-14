# Multi-stage build for Developer Console
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json lerna.json ./
COPY packages/shared/package.json ./packages/shared/
COPY packages/ui/package.json ./packages/ui/
COPY packages/auth/package.json ./packages/auth/
COPY packages/developer-console/package.json ./packages/developer-console/
RUN npm ci --only=production && npm cache clean --force
COPY packages/shared ./packages/shared
COPY packages/ui ./packages/ui
COPY packages/auth ./packages/auth
COPY packages/developer-console ./packages/developer-console
RUN npm run build --workspace=packages/developer-console

FROM nginx:1.25-alpine
RUN apk add --no-cache curl
COPY nginx.conf /etc/nginx/nginx.conf
COPY packages/developer-console/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/packages/developer-console/dist /usr/share/nginx/html
RUN echo '{"status":"healthy","app":"developer-console","timestamp":"'$(date -Iseconds)'"}' > /usr/share/nginx/html/health
RUN chown -R nginx:nginx /usr/share/nginx/html && chmod -R 755 /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD curl -f http://localhost/health || exit 1
CMD ["nginx", "-g", "daemon off;"]