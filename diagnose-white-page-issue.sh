#!/bin/bash

ALB_DNS="stream-dev-fe-alb-1307843566.eu-west-2.elb.amazonaws.com"

echo "=== COMPREHENSIVE WHITE PAGE DIAGNOSIS ==="
echo "Date: $(date)"
echo "ALB DNS: $ALB_DNS"
echo

# Test each service endpoint
SERVICES=("viewer-portal" "creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

echo "=== 1. ENDPOINT RESPONSE ANALYSIS ==="
for service in "${SERVICES[@]}"; do
    echo "--- $service ---"
    url="http://$ALB_DNS/$service/"
    
    # Get response details
    response=$(curl -s -w "STATUS:%{http_code}|SIZE:%{size_download}|TIME:%{time_total}" "$url")
    status=$(echo "$response" | grep -o "STATUS:[0-9]*" | cut -d: -f2)
    size=$(echo "$response" | grep -o "SIZE:[0-9]*" | cut -d: -f2)
    time=$(echo "$response" | grep -o "TIME:[0-9.]*" | cut -d: -f2)
    
    echo "Status: $status | Size: ${size}b | Time: ${time}s"
    
    # Get actual content
    content=$(echo "$response" | sed 's/STATUS:.*//g')
    
    # Analyze content
    if [[ $status == "200" ]]; then
        if echo "$content" | grep -q "<title>"; then
            title=$(echo "$content" | grep -o "<title>[^<]*" | cut -d'>' -f2)
            echo "Title: $title"
        fi
        
        # Check for React indicators
        if echo "$content" | grep -q "id=\"root\""; then
            echo "✅ React root found"
        else
            echo "❌ No React root"
        fi
        
        # Check for assets
        js_files=$(echo "$content" | grep -o 'src="[^"]*\.js"' | wc -l)
        css_files=$(echo "$content" | grep -o 'href="[^"]*\.css"' | wc -l)
        echo "Assets: ${js_files} JS, ${css_files} CSS files"
        
        # Test asset accessibility
        if [[ $js_files -gt 0 ]]; then
            first_js=$(echo "$content" | grep -o 'src="[^"]*\.js"' | head -1 | cut -d'"' -f2)
            if [[ -n "$first_js" ]]; then
                js_url="http://$ALB_DNS$first_js"
                js_status=$(curl -s -o /dev/null -w "%{http_code}" "$js_url")
                echo "First JS file ($first_js): $js_status"
                if [[ $js_status != "200" ]]; then
                    echo "🚨 ASSET LOADING ISSUE - JS files not accessible"
                fi
            fi
        fi
        
        # Determine if it's a white page
        if [[ $size -lt 2000 ]] && [[ $js_files -eq 0 ]]; then
            echo "🚨 WHITE PAGE - Small size, no JS"
        elif [[ $js_files -gt 0 ]] && [[ $js_status == "200" ]]; then
            echo "✅ WORKING - Has JS and assets load"
        elif [[ $js_files -gt 0 ]] && [[ $js_status != "200" ]]; then
            echo "⚠️  BROKEN - Has JS but assets don't load"
        fi
    else
        echo "❌ HTTP ERROR - Status $status"
    fi
    echo
done

echo "=== 2. ECS SERVICE STATUS ==="
for service in "${SERVICES[@]}"; do
    service_name="stream-dev-$service"
    echo "--- $service_name ---"
    
    # Get service status
    service_info=$(aws ecs describe-services \
        --cluster stream-dev-cluster \
        --services "$service_name" \
        --query 'services[0].[status,runningCount,desiredCount,taskDefinition]' \
        --output text 2>/dev/null)
    
    if [[ -n "$service_info" ]]; then
        status=$(echo "$service_info" | cut -f1)
        running=$(echo "$service_info" | cut -f2)
        desired=$(echo "$service_info" | cut -f3)
        task_def=$(echo "$service_info" | cut -f4)
        
        echo "Status: $status | Running: $running/$desired"
        echo "Task Definition: $(basename $task_def)"
        
        if [[ "$status" == "ACTIVE" ]] && [[ "$running" == "$desired" ]] && [[ "$running" != "0" ]]; then
            echo "✅ Service healthy"
        else
            echo "❌ Service issues"
        fi
    else
        echo "❌ Service not found"
    fi
    echo
done

echo "=== 3. TARGET GROUP HEALTH ==="
# Get target group ARNs
tg_arns=$(aws elbv2 describe-target-groups \
    --names stream-dev-viewer-tg stream-dev-creator-tg stream-dev-admin-tg stream-dev-support-tg stream-dev-analytics-tg stream-dev-dev-tg \
    --query 'TargetGroups[*].TargetGroupArn' \
    --output text 2>/dev/null)

if [[ -n "$tg_arns" ]]; then
    for tg_arn in $tg_arns; do
        tg_name=$(aws elbv2 describe-target-groups --target-group-arns "$tg_arn" --query 'TargetGroups[0].TargetGroupName' --output text)
        echo "--- $tg_name ---"
        
        # Get target health
        health=$(aws elbv2 describe-target-health --target-group-arn "$tg_arn" --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' --output text 2>/dev/null)
        
        if [[ -n "$health" ]]; then
            echo "$health" | while read target_id state description; do
                echo "Target: $target_id | State: $state"
                if [[ -n "$description" ]] && [[ "$description" != "None" ]]; then
                    echo "Description: $description"
                fi
            done
        else
            echo "No targets registered"
        fi
        echo
    done
else
    echo "❌ Could not retrieve target groups"
fi

echo "=== 4. DIAGNOSIS SUMMARY ==="
echo "Common causes of white pages:"
echo "1. Vite base path mismatch with ALB routing"
echo "2. Assets (JS/CSS) returning 404 errors"
echo "3. Container build issues"
echo "4. ECS service not running or unhealthy"
echo "5. Target group health check failures"
echo
echo "Next steps:"
echo "- If assets return 404: Check Vite base path configuration"
echo "- If service unhealthy: Check ECS logs and container health"
echo "- If targets unhealthy: Check ALB target group configuration"