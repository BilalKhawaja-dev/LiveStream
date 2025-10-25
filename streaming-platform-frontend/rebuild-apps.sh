#!/bin/bash
# Rebuild all applications with correct base paths

set -e

echo "🔧 Rebuilding all applications with correct base paths..."

# Applications to rebuild
APPLICATIONS=(
    "viewer-portal"
    "creator-dashboard" 
    "admin-portal"
    "analytics-dashboard"
    "support-system"
    "developer-console"
)

# Clean and rebuild shared packages first
echo "📦 Building shared packages..."
cd packages/shared && npm run build && cd ../..
cd packages/ui && npm run build && cd ../..
cd packages/auth && npm run build && cd ../..

# Rebuild each application
for APP in "${APPLICATIONS[@]}"; do
    echo "🔨 Rebuilding $APP..."
    cd packages/$APP
    rm -rf dist/
    npm run build
    
    # Verify build output
    if [ -f "dist/index.html" ]; then
        echo "✅ $APP built successfully"
        echo "📄 Checking asset paths in index.html:"
        grep -o 'src="[^"]*"' dist/index.html || echo "No script tags found"
        grep -o 'href="[^"]*"' dist/index.html || echo "No link tags found"
    else
        echo "❌ $APP build failed - no index.html found"
        exit 1
    fi
    
    cd ../..
    echo "---"
done

echo "🎉 All applications rebuilt successfully!"