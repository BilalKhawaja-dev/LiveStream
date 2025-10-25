#!/bin/bash

echo "=== TESTING ALL SERVICE BUILDS ==="

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")
SUCCESSFUL_BUILDS=()
FAILED_BUILDS=()

for service in "${SERVICES[@]}"; do
    echo "=== Testing build for $service ==="
    
    cd "streaming-platform-frontend/packages/$service"
    
    if npm run build > /dev/null 2>&1; then
        echo "✅ $service builds successfully"
        SUCCESSFUL_BUILDS+=("$service")
    else
        echo "❌ $service build failed"
        FAILED_BUILDS+=("$service")
    fi
    
    cd ../../..
done

echo
echo "=== BUILD TEST RESULTS ==="
echo "✅ SUCCESSFUL BUILDS:"
for service in "${SUCCESSFUL_BUILDS[@]}"; do
    echo "  🎉 $service"
done

echo
echo "❌ FAILED BUILDS:"
for service in "${FAILED_BUILDS[@]}"; do
    echo "  💥 $service"
done

echo
if [ ${#SUCCESSFUL_BUILDS[@]} -eq ${#SERVICES[@]} ]; then
    echo "🎉 ALL SERVICES BUILD SUCCESSFULLY!"
    echo "Ready for Docker builds and deployment"
else
    echo "⚠️  Some services need attention"
fi