#!/bin/bash

echo "=== FIXING NGINX ALB PATH ALIGNMENT ==="
echo "Aligning nginx configurations with ALB path routing"

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Fixing nginx configuration for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Create nginx configuration that matches the working viewer-portal pattern
    cat > "$service_dir/nginx.conf" << EOF
server {
    listen 3000;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Handle React Router (SPA routing) - serve everything from root
    location / {
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Handle $service specific routing (ALB forwards /$service/* here)
    location /$service/ {
        alias /usr/share/nginx/html/;
        try_files \$uri \$uri/ /index.html;
    }
    
    # Handle $service assets specifically (CRITICAL FIX)
    location ~ ^/$service/assets/(.*)\$ {
        alias /usr/share/nginx/html/assets/\$1;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check endpoints
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location /healthz {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
    
    # Prevent access to sensitive files
    location ~ /\. {
        deny all;
    }
}
EOF

    echo "✅ Fixed nginx configuration for $service"
done

echo "=== NGINX ALB PATH ALIGNMENT FIXED ==="
echo "All services now use the same pattern as working viewer-portal"