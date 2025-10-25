#!/bin/bash
# Test specific ports to identify the routing issue

ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

echo "🔍 Testing Specific Ports"
echo "========================="

# Test each port individually
declare -A PORTS=(
    ["viewer-portal"]="3000"
    ["creator-dashboard"]="3001"
    ["admin-portal"]="3002"
    ["support-system"]="3003"
    ["analytics-dashboard"]="3004"
    ["developer-console"]="3005"
)

for APP in "${!PORTS[@]}"; do
    PORT=${PORTS[$APP]}
    echo "🔍 Testing $APP on port $PORT..."
    
    # Test main page
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$ALB_DNS:$PORT" 2>/dev/null || echo "000")
    echo "  Main page: HTTP $RESPONSE"
    
    # Test health endpoint
    HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$ALB_DNS:$PORT/health" 2>/dev/null || echo "000")
    echo "  Health: HTTP $HEALTH_RESPONSE"
    
    # Test assets
    if [ "$RESPONSE" = "200" ]; then
        # Get JS file path
        JS_FILE=$(curl -s "$ALB_DNS:$PORT" | grep -o 'src="/assets/[^"]*"' | sed 's/src="//;s/"//' | head -1)
        if [ -n "$JS_FILE" ]; then
            JS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$ALB_DNS:$PORT$JS_FILE" 2>/dev/null || echo "000")
            echo "  Assets: HTTP $JS_RESPONSE"
        fi
    fi
    
    echo "---"
done

echo "🎯 Summary:"
echo "If main page = 200 but assets = 404, then assets aren't being served"
echo "If main page = 404, then routing is broken"
echo "If health = 404, then nginx config is wrong"