#!/bin/bash
# Test the container locally

echo "🧪 Testing Container Locally"
echo "============================"

# Start container in background
echo "🚀 Starting container..."
CONTAINER_ID=$(docker run -d -p 3001:3000 test-viewer)
echo "Container ID: $CONTAINER_ID"

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 5

# Test main page
echo "📄 Testing main page..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001 2>/dev/null || echo "000")
echo "Main page response: $RESPONSE"

if [ "$RESPONSE" = "200" ]; then
    echo "✅ Main page accessible"
    
    # Get JS file path
    echo "📦 Testing JavaScript assets..."
    JS_FILE=$(curl -s http://localhost:3001 | grep -o 'src="/assets/[^"]*"' | sed 's/src="//;s/"//' | head -1)
    if [ -n "$JS_FILE" ]; then
        JS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3001$JS_FILE" 2>/dev/null || echo "000")
        echo "JavaScript file response: $JS_RESPONSE"
        
        if [ "$JS_RESPONSE" = "200" ]; then
            echo "✅ JavaScript assets accessible"
        else
            echo "❌ JavaScript assets not accessible"
        fi
    else
        echo "❌ No JavaScript file found in HTML"
    fi
    
    # Test health endpoint
    echo "🏥 Testing health endpoint..."
    HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health 2>/dev/null || echo "000")
    echo "Health endpoint response: $HEALTH_RESPONSE"
    
    if [ "$HEALTH_RESPONSE" = "200" ]; then
        echo "✅ Health endpoint working"
    else
        echo "❌ Health endpoint not working"
    fi
    
else
    echo "❌ Main page not accessible"
fi

# Clean up
echo "🧹 Cleaning up..."
docker stop $CONTAINER_ID > /dev/null 2>&1
docker rm $CONTAINER_ID > /dev/null 2>&1

if [ "$RESPONSE" = "200" ] && [ "$JS_RESPONSE" = "200" ] && [ "$HEALTH_RESPONSE" = "200" ]; then
    echo ""
    echo "🎉 SUCCESS! Container is working correctly"
    echo "Ready to push to ECR and deploy to ECS"
    exit 0
else
    echo ""
    echo "❌ FAILED! Container has issues"
    exit 1
fi