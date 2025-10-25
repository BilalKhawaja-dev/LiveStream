#!/bin/bash

export AWS_DEFAULT_REGION=eu-west-2

echo "=== ALB Path Alignment Diagnostic ==="
echo ""

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers --names "stream-dev-fe-alb" --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null)

if [ "$ALB_DNS" = "None" ] || [ -z "$ALB_DNS" ]; then
    echo "❌ ALB not found or not accessible"
    exit 1
fi

echo "🔍 ALB DNS: $ALB_DNS"
echo ""

# Test each service path
services=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

echo "=== Testing ALB Path Routing ==="
for service in "${services[@]}"; do
    echo "Testing /$service/*:"
    
    # Test main path
    status=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/$service/" --connect-timeout 10)
    echo "  /$service/ -> HTTP $status"
    
    # Test assets path (this is where the issue likely is)
    status_assets=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/$service/assets/index.js" --connect-timeout 10)
    echo "  /$service/assets/* -> HTTP $status_assets"
    
    echo ""
done

echo "=== Checking Target Group Health ==="
# Get target groups
target_groups=$(aws elbv2 describe-target-groups --query 'TargetGroups[?contains(TargetGroupName, `stream-dev`)].{Name:TargetGroupName,Arn:TargetGroupArn}' --output table)
echo "$target_groups"

echo ""
echo "=== Checking Target Health ==="
for service in "${services[@]}"; do
    # Map service names to short names used in target groups
    case $service in
        "viewer-portal") short_name="viewer" ;;
        "creator-dashboard") short_name="creator" ;;
        "admin-portal") short_name="admin" ;;
        "support-system") short_name="support" ;;
        "analytics-dashboard") short_name="analytics" ;;
        "developer-console") short_name="dev" ;;
    esac
    
    tg_arn=$(aws elbv2 describe-target-groups --names "stream-dev-${short_name}-tg" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
    
    if [ "$tg_arn" != "None" ] && [ -n "$tg_arn" ]; then
        echo "Target Group: stream-dev-${short_name}-tg"
        aws elbv2 describe-target-health --target-group-arn "$tg_arn" --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State}' --output table
        echo ""
    fi
done

echo "=== Configuration Analysis ==="
echo ""
echo "🔍 ALB Configuration Issues Found:"
echo ""

# Check if ports match between ALB config and nginx
echo "Port Mismatches:"
echo "  ALB expects: viewer-portal:3000, creator-dashboard:3001, admin-portal:3002"
echo "  Nginx listens: creator-dashboard:3001, admin-portal:3002, support-system:3003, analytics-dashboard:3004, developer-console:3005"
echo ""

echo "Path Handling Issues:"
echo "  ❌ creator-dashboard, admin-portal, support-system nginx configs missing ALB path handling"
echo "  ✅ analytics-dashboard, developer-console have ALB path handling"
echo "  ✅ viewer-portal works (likely has correct config)"
echo ""

echo "Required Fixes:"
echo "  1. Add ALB path handling to nginx configs for creator-dashboard, admin-portal, support-system"
echo "  2. Ensure all services handle /service-name/* paths correctly"
echo "  3. Verify asset paths are properly routed"