#!/bin/bash
# Diagnose frontend loading issues

set -e

ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

echo "🔍 Diagnosing Frontend Loading Issues"
echo "====================================="

# Test main page
echo "📄 Testing main page HTML..."
curl -s "$ALB_DNS" > /tmp/main_page.html
echo "HTML content length: $(wc -c < /tmp/main_page.html)"
echo "Contains root div: $(grep -c 'id="root"' /tmp/main_page.html || echo 0)"

# Extract JavaScript file path
JS_FILE=$(grep -o 'src="/assets/[^"]*"' /tmp/main_page.html | sed 's/src="//;s/"//')
echo "JavaScript file path: $JS_FILE"

# Test JavaScript file
if [ -n "$JS_FILE" ]; then
    echo "📦 Testing JavaScript file..."
    JS_URL="$ALB_DNS$JS_FILE"
    JS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$JS_URL")
    echo "JavaScript file response: $JS_RESPONSE"
    
    if [ "$JS_RESPONSE" = "200" ]; then
        echo "✅ JavaScript file is accessible"
        # Get file size
        JS_SIZE=$(curl -s "$JS_URL" | wc -c)
        echo "JavaScript file size: $JS_SIZE bytes"
        
        if [ "$JS_SIZE" -lt 1000 ]; then
            echo "⚠️  JavaScript file seems too small, might be an error page"
            echo "First 200 chars:"
            curl -s "$JS_URL" | head -c 200
            echo ""
        fi
    else
        echo "❌ JavaScript file not accessible (HTTP $JS_RESPONSE)"
    fi
else
    echo "❌ No JavaScript file found in HTML"
fi

# Test assets directory
echo "📁 Testing assets directory..."
ASSETS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$ALB_DNS/assets/")
echo "Assets directory response: $ASSETS_RESPONSE"

# Test health endpoint
echo "🏥 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$ALB_DNS/health")
echo "Health endpoint response: $HEALTH_RESPONSE"

# Test with different ports
echo "🔌 Testing different ports..."
for PORT in 3000 3001 3003 3004 3005 3006; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$ALB_DNS:$PORT" 2>/dev/null || echo "000")
    echo "Port $PORT: HTTP $RESPONSE"
done

echo ""
echo "🔧 Recommendations:"
echo "1. If JavaScript file returns 404, the assets aren't being copied correctly"
echo "2. If JavaScript file is too small, it might be an nginx error page"
echo "3. Check ECS service logs for any errors"
echo "4. Verify the Docker image was built with the correct assets"