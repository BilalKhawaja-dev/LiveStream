#!/bin/bash

ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

echo "=== SIMPLE ENDPOINT TEST ==="
echo "Testing all frontend services to identify white page issue"
echo "ALB DNS: $ALB_DNS"
echo

# Test each service
SERVICES=("viewer-portal" "creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "--- Testing $service ---"
    url="http://$ALB_DNS/$service/"
    
    # Get response with headers and content
    echo "URL: $url"
    
    # Test HTTP status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    echo "HTTP Status: $status"
    
    # Get content size
    size=$(curl -s -w "%{size_download}" -o /dev/null "$url")
    echo "Content Size: $size bytes"
    
    # Get actual content to check for white page indicators
    content=$(curl -s "$url")
    
    # Check for React app indicators
    if echo "$content" | grep -q "<div id=\"root\"></div>"; then
        echo "✅ React root div found"
    else
        echo "❌ No React root div found"
    fi
    
    # Check for JavaScript files
    js_count=$(echo "$content" | grep -o 'src="[^"]*\.js"' | wc -l)
    echo "JavaScript files referenced: $js_count"
    
    # Check for CSS files  
    css_count=$(echo "$content" | grep -o 'href="[^"]*\.css"' | wc -l)
    echo "CSS files referenced: $css_count"
    
    # Check if it's a white page (minimal content)
    if [[ $size -lt 1000 ]] && [[ $js_count -eq 0 ]]; then
        echo "🚨 WHITE PAGE DETECTED - Minimal content, no JS"
    elif [[ $js_count -gt 0 ]]; then
        echo "✅ Proper app - Has JavaScript references"
        
        # Test if JS files are accessible
        js_file=$(echo "$content" | grep -o 'src="[^"]*\.js"' | head -1 | cut -d'"' -f2)
        if [[ -n "$js_file" ]]; then
            js_url="http://$ALB_DNS$js_file"
            js_status=$(curl -s -o /dev/null -w "%{http_code}" "$js_url")
            echo "First JS file status: $js_status ($js_file)"
        fi
    fi
    
    echo
done

echo "=== SUMMARY ==="
echo "If services show 'WHITE PAGE DETECTED', the issue is likely:"
echo "1. Vite build configuration problems"
echo "2. Asset path misalignment" 
echo "3. Container build issues"
echo "4. Nginx configuration problems"