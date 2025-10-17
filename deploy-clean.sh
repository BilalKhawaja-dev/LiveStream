#!/bin/bash

# Clean Terraform Deployment Script
# This script ensures a clean deployment after infrastructure teardown

set -e

echo "🚀 Starting Clean Terraform Deployment..."

# Step 1: Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Step 2: Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Step 3: Plan deployment
echo "📋 Planning deployment..."
terraform plan -out=tfplan

# Step 4: Show what will be created
echo "📊 Deployment Summary:"
terraform show -json tfplan | jq -r '.planned_values.root_module.resources[] | select(.type != null) | .type' | sort | uniq -c | sort -nr

echo ""
echo "🎯 Key Infrastructure to be Created:"
echo "   - VPC and Networking"
echo "   - ECS Cluster with Fargate Services"
echo "   - Application Load Balancer"
echo "   - Aurora Serverless Database"
echo "   - ECR Repository"
echo "   - Lambda Functions"
echo "   - S3 Buckets"
echo "   - CloudFront Distribution"
echo ""

read -p "🤔 Do you want to apply this plan? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Applying Terraform plan..."
    terraform apply tfplan
    
    echo ""
    echo "✅ Deployment Complete!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Build and push container images to ECR"
    echo "   2. Update ECS services with new images"
    echo "   3. Configure DNS if using custom domain"
    echo ""
    
    # Show outputs
    echo "🔗 Infrastructure Outputs:"
    terraform output
else
    echo "❌ Deployment cancelled."
    rm -f tfplan
fi