#!/bin/bash

echo "=== CHECKING ACTUAL HTML CONTENT AND CSS LOADING ==="

ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"
SERVICES=("viewer-portal" "creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "=== $service ==="
    
    # Get HTML content
    html_content=$(curl -s "http://$ALB_DNS/$service/")
    
    # Check for CSS files
    css_files=$(echo "$html_content" | grep -o 'href="[^"]*\.css"' | sed 's/href="//g' | sed 's/"//g')
    
    echo "CSS files found:"
    if [ -n "$css_files" ]; then
        echo "$css_files"
        
        # Test first CSS file
        first_css=$(echo "$css_files" | head -1)
        if [[ $first_css == /* ]]; then
            css_url="http://$ALB_DNS$first_css"
        else
            css_url="http://$ALB_DNS/$service/$first_css"
        fi
        
        css_status=$(curl -s -w "%{http_code}" -o /dev/null "$css_url")
        echo "CSS Status: $css_status"
        
        if [ "$css_status" = "200" ]; then
            echo "✅ CSS loading correctly"
        else
            echo "❌ CSS failing to load"
        fi
    else
        echo "❌ No CSS files found in HTML"
    fi
    
    # Check if Chakra UI is being used
    if echo "$html_content" | grep -q "chakra"; then
        echo "✅ Chakra UI detected"
    else
        echo "⚠️  No Chakra UI detected"
    fi
    
    echo "---"
done

echo
echo "=== DIAGNOSIS ==="
echo "If CSS files are missing or returning 404, that explains the missing colors/styling"