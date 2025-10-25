#!/bin/bash
# Test the fixed applications to verify they're working

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Testing Fixed Applications${NC}"
echo "=================================="

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers --region eu-west-2 --query 'LoadBalancers[?contains(LoadBalancerName, `stream-dev`)].DNSName' --output text)

if [ -z "$ALB_DNS" ]; then
    echo -e "${RED}❌ Could not find ALB DNS name${NC}"
    exit 1
fi

echo -e "${BLUE}🌐 ALB DNS: $ALB_DNS${NC}"
echo ""

# Applications to test
declare -A APPLICATIONS=(
    ["viewer-portal"]="3000"
    ["creator-dashboard"]="3001"
    ["admin-portal"]="3003"
    ["analytics-dashboard"]="3005"
    ["support-system"]="3004"
    ["developer-console"]="3006"
)

# Test each application
for APP in "${!APPLICATIONS[@]}"; do
    PORT=${APPLICATIONS[$APP]}
    URL="http://$ALB_DNS:$PORT"
    
    echo -e "${YELLOW}🔍 Testing $APP at $URL${NC}"
    
    # Test health endpoint first
    HEALTH_URL="$URL/health"
    if curl -f -s "$HEALTH_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $APP health check passed${NC}"
    else
        echo -e "${RED}❌ $APP health check failed${NC}"
    fi
    
    # Test main page
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || echo "000")
    
    if [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}✅ $APP main page accessible (HTTP $RESPONSE)${NC}"
        
        # Check if it's actually serving content (not blank)
        CONTENT=$(curl -s "$URL" | grep -o '<div id="root">' || echo "")
        if [ -n "$CONTENT" ]; then
            echo -e "${GREEN}✅ $APP has React root element${NC}"
        else
            echo -e "${YELLOW}⚠️  $APP may still have content issues${NC}"
        fi
    else
        echo -e "${RED}❌ $APP main page failed (HTTP $RESPONSE)${NC}"
    fi
    
    echo "---"
done

echo -e "${BLUE}📊 Test Summary${NC}"
echo "If applications show ✅ for health check and main page, the fix was successful!"
echo "If you still see blank pages, check browser console for JavaScript errors."
echo ""
echo -e "${YELLOW}🔗 Application URLs:${NC}"
for APP in "${!APPLICATIONS[@]}"; do
    PORT=${APPLICATIONS[$APP]}
    echo "• $APP: http://$ALB_DNS:$PORT"
done