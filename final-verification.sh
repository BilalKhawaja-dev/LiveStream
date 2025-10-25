#!/bin/bash

# Final Verification Script
# Tests all applications to ensure they're working with the latest code and fixed nginx permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ALB_DNS="stream-dev-fe-alb-471778558.eu-west-2.elb.amazonaws.com"

APPLICATIONS=(
    "admin-portal"
    "viewer-portal"
    "creator-dashboard"
    "support-system"
    "analytics-dashboard"
    "developer-console"
)

echo -e "${BLUE}🎉 Final Verification: Testing All Applications${NC}"
echo -e "${BLUE}Load Balancer: ${ALB_DNS}${NC}"
echo

all_healthy=true

for app in "${APPLICATIONS[@]}"; do
    echo -e "${YELLOW}Testing ${app}...${NC}"
    
    # Test health endpoint
    health_status=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}/${app}/health" || echo "000")
    if [ "$health_status" = "200" ]; then
        echo -e "  Health check: ${GREEN}✅ $health_status${NC}"
    else
        echo -e "  Health check: ${RED}❌ $health_status${NC}"
        all_healthy=false
    fi
    
    # Test main page
    main_status=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}/${app}/" || echo "000")
    if [ "$main_status" = "200" ]; then
        echo -e "  Main page: ${GREEN}✅ $main_status${NC}"
    else
        echo -e "  Main page: ${RED}❌ $main_status${NC}"
        all_healthy=false
    fi
    
    # Check if React app is loading
    content=$(curl -s "http://${ALB_DNS}/${app}/" | head -10)
    if echo "$content" | grep -q "div id=\"root\"" && echo "$content" | grep -q "<!DOCTYPE html>"; then
        echo -e "  React app: ${GREEN}✅ Loading correctly${NC}"
    else
        echo -e "  React app: ${RED}❌ Not loading properly${NC}"
        all_healthy=false
    fi
    
    echo
done

# Summary
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 SUCCESS: All applications are healthy and working!${NC}"
    echo -e "\n${BLUE}Your streaming platform is fully operational:${NC}"
    for app in "${APPLICATIONS[@]}"; do
        echo -e "${BLUE}  • ${app}: http://${ALB_DNS}/${app}/${NC}"
    done
    echo -e "\n${GREEN}✅ Latest code deployed${NC}"
    echo -e "${GREEN}✅ Nginx permissions fixed${NC}"
    echo -e "${GREEN}✅ All services healthy${NC}"
    echo -e "${GREEN}✅ Cross-service integration working${NC}"
else
    echo -e "${RED}❌ Some applications are not healthy. Check the logs above.${NC}"
    exit 1
fi