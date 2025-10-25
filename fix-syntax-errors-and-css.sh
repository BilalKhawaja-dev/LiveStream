#!/bin/bash

echo "🔧 Fixing syntax errors and CSS imports..."

cd streaming-platform-frontend

# Fix syntax errors first
echo "🐛 Fixing syntax errors in component files..."

# Fix creator-dashboard RevenueTracking.tsx
echo "📝 Fixing creator-dashboard RevenueTracking.tsx..."
sed -i "s/title: ',/title: '',/g" packages/creator-dashboard/src/components/Revenue/RevenueTracking.tsx
sed -i "s/deadline: ',/deadline: '',/g" packages/creator-dashboard/src/components/Revenue/RevenueTracking.tsx

# Fix analytics-dashboard StreamerAnalytics.tsx
echo "📝 Fixing analytics-dashboard StreamerAnalytics.tsx..."
sed -i "s/searchQuery: '/searchQuery: ''/g" packages/analytics-dashboard/src/components/Streamers/StreamerAnalytics.tsx

# Fix support-system TicketDashboard.tsx
echo "📝 Fixing support-system TicketDashboard.tsx..."
sed -i "s/useState(')/useState('')/g" packages/support-system/src/components/TicketManagement/TicketDashboard.tsx

echo "✅ Syntax errors fixed!"

# Now fix CSS imports in main.tsx files
echo "🎨 Adding CSS imports to main.tsx files..."

SERVICES=("admin-portal" "creator-dashboard" "developer-console" "analytics-dashboard" "support-system")

for SERVICE in "${SERVICES[@]}"; do
    MAIN_FILE="packages/$SERVICE/src/main.tsx"
    CSS_FILE="./styles/${SERVICE}-theme.css"
    
    if [ -f "$MAIN_FILE" ]; then
        echo "📝 Adding CSS import to $SERVICE main.tsx..."
        
        # Create backup
        cp "$MAIN_FILE" "$MAIN_FILE.backup"
        
        # Check if CSS import already exists
        if ! grep -q "${SERVICE}-theme.css" "$MAIN_FILE"; then
            # Add CSS import after the App import
            sed -i "/import App from/a import '$CSS_FILE'" "$MAIN_FILE"
            echo "✅ Added CSS import to $SERVICE"
        else
            echo "ℹ️  CSS import already exists in $SERVICE"
        fi
    fi
done

echo ""
echo "🏗️  Testing builds with fixes..."

for SERVICE in "${SERVICES[@]}"; do
    echo "🔨 Building $SERVICE..."
    cd "packages/$SERVICE"
    
    npm run build
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully built $SERVICE"
        
        # Check if CSS files were generated
        if [ -d "dist/assets" ]; then
            CSS_COUNT=$(find dist/assets -name "*.css" | wc -l)
            JS_COUNT=$(find dist/assets -name "*.js" | wc -l)
            echo "📄 Generated $CSS_COUNT CSS files and $JS_COUNT JS files"
            
            # Show file sizes
            if [ $CSS_COUNT -gt 0 ]; then
                echo "📊 CSS files:"
                find dist/assets -name "*.css" -exec ls -lh {} \; | awk '{print "  " $9 " (" $5 ")"}'
            fi
        fi
    else
        echo "❌ Failed to build $SERVICE"
        echo "🔍 Checking for remaining syntax errors..."
        npm run build 2>&1 | grep -A 5 -B 5 "ERROR"
    fi
    
    cd ../..
    echo ""
done

echo "🐳 Building Docker images with fixes..."

for SERVICE in "${SERVICES[@]}"; do
    echo "🐳 Building Docker image for $SERVICE..."
    
    cd "packages/$SERVICE"
    
    # Build Docker image
    docker build -t "streaming-$SERVICE:styled" .
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully built Docker image for $SERVICE"
        
        # Quick test
        echo "🧪 Testing container..."
        CONTAINER_ID=$(docker run -d -p 0:3000 "streaming-$SERVICE:styled")
        sleep 2
        
        if docker ps | grep -q "$CONTAINER_ID"; then
            echo "✅ Container starts successfully"
            
            # Get the mapped port
            PORT=$(docker port "$CONTAINER_ID" 3000 | cut -d: -f2)
            echo "🌐 Container running on port $PORT"
            
            # Test if it serves content
            sleep 1
            if curl -s "http://localhost:$PORT" | grep -q "<!DOCTYPE html>"; then
                echo "✅ Container serves HTML content"
            else
                echo "⚠️  Container may not be serving content properly"
            fi
            
            docker stop "$CONTAINER_ID" > /dev/null 2>&1
        else
            echo "⚠️  Container startup issues"
            docker logs "$CONTAINER_ID" 2>/dev/null | tail -3
        fi
        
        docker rm "$CONTAINER_ID" > /dev/null 2>&1
    else
        echo "❌ Failed to build Docker image for $SERVICE"
    fi
    
    cd ../..
done

echo ""
echo "📋 Final Status Report:"
echo "======================"

for SERVICE in "${SERVICES[@]}"; do
    echo "📦 $SERVICE:"
    
    # Check syntax
    MAIN_FILE="packages/$SERVICE/src/main.tsx"
    if grep -q "${SERVICE}-theme.css" "$MAIN_FILE" 2>/dev/null; then
        echo "  ✅ CSS import added"
    else
        echo "  ❌ CSS import missing"
    fi
    
    # Check build
    if [ -d "packages/$SERVICE/dist" ]; then
        echo "  ✅ Build successful"
        CSS_COUNT=$(find "packages/$SERVICE/dist/assets" -name "*.css" 2>/dev/null | wc -l)
        echo "  📄 Generated $CSS_COUNT CSS files"
    else
        echo "  ❌ Build failed"
    fi
    
    # Check Docker image
    if docker images | grep -q "streaming-$SERVICE:styled"; then
        echo "  ✅ Docker image built"
    else
        echo "  ❌ Docker image failed"
    fi
    
    echo ""
done

echo "🎨 CSS and syntax fix completed!"
echo ""
echo "Next steps:"
echo "1. Tag and push images to ECR with :styled tag"
echo "2. Update ECS services to use new images"
echo "3. Test styling in browser"