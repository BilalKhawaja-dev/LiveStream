#!/bin/bash

ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"
SERVICES=("viewer-portal" "creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

echo "=== QUICK STATUS CHECK ==="
echo "Testing all services to confirm which ones show white pages"
echo

for service in "${SERVICES[@]}"; do
    url="http://$ALB_DNS/$service/"
    
    # Get basic response info
    response=$(curl -s -w "STATUS:%{http_code}|SIZE:%{size_download}" "$url")
    status=$(echo "$response" | grep -o "STATUS:[0-9]*" | cut -d: -f2)
    size=$(echo "$response" | grep -o "SIZE:[0-9]*" | cut -d: -f2)
    
    # Get content to check for JS files
    content=$(echo "$response" | sed 's/STATUS:.*//g')
    js_count=$(echo "$content" | grep -o 'src="[^"]*\.js"' | wc -l)
    
    printf "%-20s | Status: %-3s | Size: %-6s | JS Files: %-2s | " "$service" "$status" "${size}b" "$js_count"
    
    # Determine status
    if [[ $status == "200" ]]; then
        if [[ $js_count -gt 0 ]]; then
            echo "✅ WORKING"
        else
            echo "🚨 WHITE PAGE"
        fi
    else
        echo "❌ ERROR ($status)"
    fi
done

echo
echo "Services showing 🚨 WHITE PAGE need to be fixed."