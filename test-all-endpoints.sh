#!/bin/bash

# Comprehensive endpoint testing script
set -e

# Configuration
API_BASE="https://xq0g6h6670.execute-api.eu-west-2.amazonaws.com/dev"
FRONTEND_BASE="https://xq0g6h6670.execute-api.eu-west-2.amazonaws.com/dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Testing All Streaming Platform Endpoints${NC}"
echo "API Base: $API_BASE"
echo "Frontend Base: $FRONTEND_BASE"
echo

# Function to test endpoint
test_endpoint() {
    local method=$1
    local url=$2
    local description=$3
    local expected_status=${4:-200}
    
    echo -e "${YELLOW}Testing: $description${NC}"
    echo "  $method $url"
    
    response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" 2>/dev/null || echo -e "\nERROR")
    
    if [[ "$response" == *"ERROR"* ]]; then
        echo -e "  ${RED}❌ Connection failed${NC}"
        return 1
    fi
    
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [[ "$status_code" == "$expected_status" ]] || [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
        echo -e "  ${GREEN}✅ Status: $status_code${NC}"
        if [[ ${#body} -gt 100 ]]; then
            echo "  Response: ${body:0:100}..."
        else
            echo "  Response: $body"
        fi
    else
        echo -e "  ${RED}❌ Status: $status_code (expected $expected_status)${NC}"
        echo "  Response: $body"
    fi
    echo
}

echo -e "${BLUE}📡 API Endpoints${NC}"
echo "==============="

# Authentication endpoints
test_endpoint "POST" "$API_BASE/auth/login" "User Login" 200
test_endpoint "POST" "$API_BASE/auth/register" "User Registration" 200
test_endpoint "POST" "$API_BASE/auth/refresh" "Token Refresh" 200
test_endpoint "POST" "$API_BASE/auth/logout" "User Logout" 200

# User management endpoints
test_endpoint "GET" "$API_BASE/users" "Get Users" 200
test_endpoint "GET" "$API_BASE/users/profile" "Get User Profile" 200
test_endpoint "GET" "$API_BASE/users/preferences" "Get User Preferences" 200
test_endpoint "GET" "$API_BASE/users/subscription" "Get User Subscription" 200

# Streaming endpoints
test_endpoint "GET" "$API_BASE/streams" "Get Streams" 200
test_endpoint "GET" "$API_BASE/streams/live" "Get Live Streams" 200
test_endpoint "GET" "$API_BASE/streams/archive" "Get Archived Streams" 200
test_endpoint "GET" "$API_BASE/streams/schedule" "Get Stream Schedule" 200
test_endpoint "GET" "$API_BASE/streams/metrics" "Get Stream Metrics" 200

# Media endpoints
test_endpoint "GET" "$API_BASE/media" "Get Media" 200
test_endpoint "GET" "$API_BASE/media/cdn" "Get CDN Media" 200
test_endpoint "POST" "$API_BASE/media/upload" "Upload Media" 200
test_endpoint "POST" "$API_BASE/media/transcode" "Transcode Media" 200

# Analytics endpoints
test_endpoint "GET" "$API_BASE/analytics" "Get Analytics" 200
test_endpoint "GET" "$API_BASE/analytics/users" "Get User Analytics" 200
test_endpoint "GET" "$API_BASE/analytics/streams" "Get Stream Analytics" 200
test_endpoint "GET" "$API_BASE/analytics/revenue" "Get Revenue Analytics" 200
test_endpoint "GET" "$API_BASE/analytics/reports" "Get Analytics Reports" 200

# Support endpoints
test_endpoint "GET" "$API_BASE/support" "Get Support" 200
test_endpoint "GET" "$API_BASE/support/tickets" "Get Support Tickets" 200
test_endpoint "GET" "$API_BASE/support/chat" "Get Support Chat" 200
test_endpoint "GET" "$API_BASE/support/ai" "Get AI Support" 200

echo -e "${BLUE}🌐 Frontend Applications${NC}"
echo "======================="

# Frontend applications
test_endpoint "GET" "$FRONTEND_BASE/" "Root/Viewer Portal" 200
test_endpoint "GET" "$FRONTEND_BASE/viewer-portal/" "Viewer Portal" 200
test_endpoint "GET" "$FRONTEND_BASE/creator-dashboard/" "Creator Dashboard" 200
test_endpoint "GET" "$FRONTEND_BASE/admin-portal/" "Admin Portal" 200
test_endpoint "GET" "$FRONTEND_BASE/support-system/" "Support System" 200
test_endpoint "GET" "$FRONTEND_BASE/analytics-dashboard/" "Analytics Dashboard" 200
test_endpoint "GET" "$FRONTEND_BASE/developer-console/" "Developer Console" 200

echo -e "${BLUE}🏥 Health Check Endpoints${NC}"
echo "========================"

# Health checks for frontend apps (if accessible)
test_endpoint "GET" "$FRONTEND_BASE/health" "API Gateway Health" 200
test_endpoint "GET" "$FRONTEND_BASE/viewer-portal/health" "Viewer Portal Health" 200
test_endpoint "GET" "$FRONTEND_BASE/creator-dashboard/health" "Creator Dashboard Health" 200
test_endpoint "GET" "$FRONTEND_BASE/admin-portal/health" "Admin Portal Health" 200
test_endpoint "GET" "$FRONTEND_BASE/support-system/health" "Support System Health" 200
test_endpoint "GET" "$FRONTEND_BASE/analytics-dashboard/health" "Analytics Dashboard Health" 200
test_endpoint "GET" "$FRONTEND_BASE/developer-console/health" "Developer Console Health" 200

echo -e "${BLUE}📊 Summary${NC}"
echo "=========="
echo "All endpoint tests completed!"
echo ""
echo "Note: Some endpoints may return 401/403 (authentication required) which is expected behavior."
echo "The important thing is that they respond and don't return 502/503/504 (infrastructure issues)."
echo ""
echo -e "${GREEN}✅ Infrastructure is properly deployed if most endpoints respond with 2xx, 401, or 403 status codes.${NC}"
echo -e "${RED}❌ Infrastructure issues if you see 502, 503, 504, or connection timeouts.${NC}"