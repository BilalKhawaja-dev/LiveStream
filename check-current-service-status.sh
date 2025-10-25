#!/bin/bash

echo "=== CURRENT SERVICE STATUS CHECK ==="
ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"
SERVICES=("viewer-portal" "creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "=== Testing $service ==="
    
    # Test HTML
    html_url="http://$ALB_DNS/$service/"
    html_response=$(curl -s -w "STATUS:%{http_code}" "$html_url")
    html_status=$(echo "$html_response" | grep -o "STATUS:[0-9]*" | cut -d: -f2)
    html_content=$(echo "$html_response" | sed 's/STATUS:.*//g')
    
    if [[ $html_status == "200" ]]; then
        echo "✅ HTML: $html_status"
        
        # Extract and test first JS asset
        js_files=$(echo "$html_content" | grep -o 'src="[^"]*\.js"' | head -1 | sed 's/src="//g' | sed 's/"//g')
        if [[ -n "$js_files" ]]; then
            if [[ $js_files == /* ]]; then
                js_url="http://$ALB_DNS$js_files"
            else
                js_url="http://$ALB_DNS/$service/$js_files"
            fi
            
            js_status=$(curl -s -w "%{http_code}" -o /dev/null "$js_url")
            if [[ $js_status == "200" ]]; then
                echo "✅ JS Assets: $js_status"
                echo "🎉 $service: WORKING"
            else
                echo "❌ JS Assets: $js_status"
                echo "💥 $service: WHITE PAGE (assets fail)"
            fi
        else
            echo "❌ No JS assets found in HTML"
            echo "💥 $service: BROKEN (no assets)"
        fi
    else
        echo "❌ HTML: $html_status"
        echo "💥 $service: COMPLETELY BROKEN"
    fi
    echo
done

echo "=== SUMMARY ==="
echo "✅ = Working correctly"
echo "💥 = White page / broken"
echo "Fix needed for services showing 💥"