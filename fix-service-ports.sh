#!/bin/bash

echo "=== FIXING SERVICE PORTS TO MATCH ALB TARGET GROUPS ==="

# Port mapping based on ALB target groups
declare -A SERVICE_PORTS=(
    ["viewer-portal"]=3000
    ["creator-dashboard"]=3001
    ["admin-portal"]=3002
    ["support-system"]=3003
    ["analytics-dashboard"]=3004
    ["developer-console"]=3005
)

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    port=${SERVICE_PORTS[$service]}
    echo "Fixing $service to use port $port..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Update nginx.conf to listen on correct port
    sed -i "s/listen 3000;/listen $port;/" "$service_dir/nginx.conf"
    
    # Update Dockerfile to expose correct port
    sed -i "s/EXPOSE 3000/EXPOSE $port/" "$service_dir/Dockerfile"
    
    # Update health check script to use correct port
    sed -i "s/localhost:3000/localhost:$port/g" "$service_dir/Dockerfile"
    
    echo "✅ Updated $service to use port $port"
done

echo "=== SERVICE PORTS FIXED ==="
echo "Port assignments:"
for service in "${!SERVICE_PORTS[@]}"; do
    echo "  $service: ${SERVICE_PORTS[$service]}"
done