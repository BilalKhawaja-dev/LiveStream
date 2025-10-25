#!/bin/bash

echo "=== UPDATING ALL DOCKERFILES ==="

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Updating Dockerfile for $service..."
    
    sed -i 's/RUN npm ci/RUN npm install/' "streaming-platform-frontend/packages/$service/Dockerfile"
    
    echo "✅ Updated Dockerfile for $service"
done

echo "=== ALL DOCKERFILES UPDATED ==="