#!/bin/bash

# Enhanced API Gateway Deployment Script
# This script deploys the comprehensive API Gateway configuration with enhanced features

set -e

echo "🚀 Starting enhanced API Gateway deployment..."

# Function to check if AWS CLI is available
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
}

# Function to check if Terraform is available
check_terraform() {
    if ! command -v terraform &> /dev/null; then
        echo "❌ Terraform not found. Please install Terraform first."
        exit 1
    fi
}

# Function to validate Terraform configuration
validate_terraform() {
    echo "🔍 Validating Terraform configuration..."
    
    if ! terraform validate; then
        echo "❌ Terraform validation failed"
        exit 1
    fi
    
    echo "✅ Terraform configuration is valid"
}

# Function to plan Terraform deployment
plan_terraform() {
    echo "📋 Planning Terraform deployment..."
    
    terraform plan -out=tfplan -var-file=terraform.tfvars
    
    echo ""
    echo "📊 Terraform plan completed. Review the changes above."
    echo ""
    
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled by user"
        exit 1
    fi
}

# Function to apply Terraform configuration
apply_terraform() {
    echo "🔧 Applying Terraform configuration..."
    
    if terraform apply tfplan; then
        echo "✅ Terraform deployment completed successfully"
    else
        echo "❌ Terraform deployment failed"
        exit 1
    fi
}

# Function to test API Gateway endpoints
test_api_gateway() {
    echo "🧪 Testing API Gateway endpoints..."
    
    # Get API Gateway URL from Terraform output
    API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
    
    if [ -z "$API_URL" ]; then
        echo "⚠️  Could not retrieve API Gateway URL from Terraform output"
        return
    fi
    
    echo "Testing API Gateway at: $API_URL"
    
    # Test health endpoint
    echo "Testing health endpoint..."
    if curl -s -f "$API_URL/health" > /dev/null; then
        echo "✅ Health endpoint is responding"
    else
        echo "⚠️  Health endpoint is not responding"
    fi
    
    # Test CORS preflight
    echo "Testing CORS preflight..."
    if curl -s -f -X OPTIONS "$API_URL/auth/login" \
        -H "Origin: https://example.com" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type,Authorization" > /dev/null; then
        echo "✅ CORS preflight is working"
    else
        echo "⚠️  CORS preflight is not working properly"
    fi
}

# Function to display deployment summary
display_summary() {
    echo ""
    echo "📊 Deployment Summary"
    echo "===================="
    
    # API Gateway information
    API_ID=$(terraform output -raw api_gateway_id 2>/dev/null || echo "N/A")
    API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "N/A")
    STAGE_NAME=$(terraform output -raw api_gateway_stage_name 2>/dev/null || echo "N/A")
    
    echo "API Gateway ID: $API_ID"
    echo "API Gateway URL: $API_URL"
    echo "Stage Name: $STAGE_NAME"
    
    # Usage plans
    echo ""
    echo "Usage Plans:"
    echo "- Basic Plan: Rate limit with per-method throttling"
    echo "- Premium Plan: Enhanced limits for creators"
    echo "- Admin Plan: Unrestricted access for administrators"
    
    # Security features
    echo ""
    echo "Security Features Enabled:"
    echo "- Cognito User Pool Authorization"
    echo "- JWT Token Validation"
    echo "- WAF Protection with Rate Limiting"
    echo "- Request/Response Validation"
    echo "- CORS Configuration"
    
    # Monitoring
    echo ""
    echo "Monitoring Features:"
    echo "- CloudWatch Alarms for 4XX/5XX errors"
    echo "- Latency monitoring"
    echo "- Custom CloudWatch Dashboard"
    echo "- X-Ray Tracing enabled"
    
    echo ""
    echo "✅ Enhanced API Gateway deployment completed successfully!"
}

# Main execution
main() {
    echo "🔧 Enhanced API Gateway Deployment"
    echo "=================================="
    
    check_aws_cli
    check_terraform
    
    echo "Current AWS identity:"
    aws sts get-caller-identity
    
    echo ""
    echo "Current directory: $(pwd)"
    echo "Terraform workspace: $(terraform workspace show)"
    echo ""
    
    validate_terraform
    plan_terraform
    apply_terraform
    test_api_gateway
    display_summary
    
    echo ""
    echo "🎉 Deployment completed! Your enhanced API Gateway is ready."
    echo ""
    echo "Next steps:"
    echo "1. Update your frontend applications to use the new API Gateway URL"
    echo "2. Configure DNS records if using a custom domain"
    echo "3. Set up monitoring alerts and dashboards"
    echo "4. Test all endpoints with proper authentication"
}

# Run main function
main "$@"