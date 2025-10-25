#!/bin/bash

ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"
SERVICES=("viewer-portal" "creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

echo "=== COMPREHENSIVE ENDPOINT TESTING ==="
echo "ALB DNS: $ALB_DNS"
echo "Date: $(date)"
echo

echo "=== 1. TESTING MAIN ENDPOINTS ==="
for service in "${SERVICES[@]}"; do
    echo "--- Testing $service ---"
    url="http://$ALB_DNS/$service/"
    
    # Test main page with detailed response
    echo "URL: $url"
    response=$(curl -s -w "HTTPSTATUS:%{http_code}|SIZE:%{size_download}|TIME:%{time_total}" "$url")
    status=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    size=$(echo "$response" | grep -o "SIZE:[0-9]*" | cut -d: -f2)
    time=$(echo "$response" | grep -o "TIME:[0-9.]*" | cut -d: -f2)
    
    echo "Status: $status | Size: ${size} bytes | Time: ${time}s"
    
    # Check if it's just HTML or actual content
    content=$(echo "$response" | sed 's/HTTPSTATUS:.*//g')
    if [[ ${#content} -lt 1000 ]]; then
        echo "⚠️  Small response size - likely minimal HTML"
    fi
    
    # Test for common white page indicators
    if echo "$content" | grep -q "<div id=\"root\"></div>" && ! echo "$content" | grep -q "script"; then
        echo "❌ WHITE PAGE DETECTED - Empty React root with no scripts"
    elif echo "$content" | grep -q "script" && echo "$content" | grep -q "assets"; then
        echo "✅ Proper React app with assets"
    fi
    
    echo
done

echo "=== 2. TESTING ASSET PATHS ==="
for service in "${SERVICES[@]}"; do
    echo "--- Testing $service assets ---"
    
    # Test assets directory
    assets_url="http://$ALB_DNS/$service/assets/"
    assets_status=$(curl -s -o /dev/null -w "%{http_code}" "$assets_url")
    echo "Assets directory: $assets_status"
    
    # Try to find actual JS files by checking the HTML
    main_page=$(curl -s "http://$ALB_DNS/$service/")
    js_files=$(echo "$main_page" | grep -o '/[^"]*\.js' | head -3)
    
    if [[ -n "$js_files" ]]; then
        echo "Found JS files in HTML:"
        while IFS= read -r js_file; do
            if [[ -n "$js_file" ]]; then
                js_url="http://$ALB_DNS$js_file"
                js_status=$(curl -s -o /dev/null -w "%{http_code}" "$js_url")
                echo "  $js_file -> $js_status"
            fi
        done <<< "$js_files"
    else
        echo "❌ No JS files found in HTML"
    fi
    echo
done

echo "=== 3. ALB PATH CONFIGURATION ANALYSIS ==="
echo "Checking ALB listener rules..."