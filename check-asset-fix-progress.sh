#!/bin/bash

echo "=== ASSET FIX PROGRESS CHECK ==="
echo "Checking deployment status and asset accessibility..."
echo

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")
ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

for service in "${SERVICES[@]}"; do
    echo "--- $service ---"
    
    # Check ECS service status
    service_info=$(aws ecs describe-services \
        --cluster stream-dev-cluster \
        --services "stream-dev-$service" \
        --query 'services[0].[runningCount,desiredCount,deployments[0].status]' \
        --output text 2>/dev/null)
    
    if [[ -n "$service_info" ]]; then
        running=$(echo "$service_info" | cut -f1)
        desired=$(echo "$service_info" | cut -f2)
        deployment_status=$(echo "$service_info" | cut -f3)
        echo "ECS Status: $running/$desired tasks, Deployment: $deployment_status"
    fi
    
    # Test main endpoint
    url="http://$ALB_DNS/$service/"
    echo "Testing: $url"
    
    response=$(curl -s -w "STATUS:%{http_code}" "$url")
    http_status=$(echo "$response" | grep -o "STATUS:[0-9]*" | cut -d: -f2)
    content=$(echo "$response" | sed 's/STATUS:.*//g')
    
    if [[ $http_status == "200" ]]; then
        # Check for JavaScript files in HTML
        js_files=$(echo "$content" | grep -o 'src="[^"]*\.js"' | head -3)
        js_count=$(echo "$content" | grep -o 'src="[^"]*\.js"' | wc -l)
        
        echo "HTML Status: ✅ 200 OK"
        echo "JS Files Found: $js_count"
        
        if [[ $js_count -gt 0 ]]; then
            # Test first JS file
            first_js=$(echo "$js_files" | head -1 | sed 's/src="//g' | sed 's/"//g')
            if [[ $first_js == /* ]]; then
                js_url="http://$ALB_DNS$first_js"
            else
                js_url="http://$ALB_DNS/$service/$first_js"
            fi
            
            echo "Testing JS: $js_url"
            js_status=$(curl -s -w "%{http_code}" -o /dev/null "$js_url")
            
            if [[ $js_status == "200" ]]; then
                echo "Assets Status: ✅ JS files accessible"
                echo "Result: 🎉 SERVICE WORKING"
            else
                echo "Assets Status: ❌ JS returns $js_status"
                echo "Result: ⚠️  Still broken (asset path issue)"
            fi
        else
            echo "Assets Status: ❌ No JS files found in HTML"
            echo "Result: ⚠️  Build issue"
        fi
    else
        echo "HTML Status: ❌ $http_status"
        echo "Result: ❌ Service not responding"
    fi
    
    echo
done

echo "=== SUMMARY ==="
echo "🎉 = Service fully working"
echo "⚠️  = Service deployed but assets broken"
echo "❌ = Service not responding"
echo
echo "If services show 'Still broken', the deployment is still in progress."
echo "Run this script again in 2-3 minutes."