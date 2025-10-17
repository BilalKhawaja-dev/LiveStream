#!/bin/bash

# Clean Build and Deploy Script
# This replaces all the previous build scripts with one that works

set -e

echo "🚀 Building and Deploying Streaming Platform"

# Step 1: Build containers
echo "📦 Building containers..."
cd streaming-platform-frontend
./build-working-containers.sh

# Step 2: Push to ECR
echo "📤 Pushing to ECR..."
./push-to-ecr.sh

# Step 3: Deploy infrastructure
echo "🏗️  Deploying infrastructure..."
cd ..
terraform apply -auto-approve

# Step 4: Fix ALB if needed
echo "🔧 Ensuring ALB is healthy..."
./fix-alb-completely.sh

echo "✅ Deployment complete!"
echo "🌐 Your application: $(terraform output -raw application_url)"
