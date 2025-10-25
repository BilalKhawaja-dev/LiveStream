# 🚀 Manual Deployment Instructions

Since AWS credentials need to be configured in your local environment, here are the exact commands to run:

## Option 1: Complete Rebuild & Deploy (Recommended)

Run this in your local terminal where AWS credentials are configured:

```bash
# Navigate to your project directory
cd /path/to/your/streaming-platform

# Make script executable
chmod +x rebuild-and-deploy.sh

# Run the complete rebuild and deployment
./rebuild-and-deploy.sh
```

This will:
1. ✅ Build new Docker images with latest code
2. ✅ Push them to ECR
3. ✅ Force ECS to use the new images
4. ✅ Verify deployment

## Option 2: Force ECS Update Only

If you just want to force ECS to redeploy existing images:

```bash
# Make script executable
chmod +x force-ecs-update.sh

# Run the force update
./force-ecs-update.sh
```

## Option 3: Manual Step-by-Step Process

If the scripts don't work, here are the manual commands:

### Step 1: Build and Push Images

```bash
# Login to ECR
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 981686514879.dkr.ecr.eu-west-2.amazonaws.com

# Build and push each application
cd streaming-platform-frontend

# Applications to build
APPS=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

for app in "${APPS[@]}"; do
    echo "Building $app..."
    docker build -f "packages/$app/Dockerfile" -t "981686514879.dkr.ecr.eu-west-2.amazonaws.com/stream-dev:$app-latest" .
    docker push "981686514879.dkr.ecr.eu-west-2.amazonaws.com/stream-dev:$app-latest"
done
```

### Step 2: Force ECS Deployment

```bash
# Go back to root directory
cd ..

# Force ECS services to redeploy
SERVICES=("stream-dev-admin-portal" "stream-dev-viewer-portal" "stream-dev-creator-dashboard" "stream-dev-support-system" "stream-dev-analytics-dashboard" "stream-dev-developer-console")

for service in "${SERVICES[@]}"; do
    aws ecs update-service \
        --cluster stream-dev-cluster \
        --service $service \
        --force-new-deployment \
        --region eu-west-2
done
```

### Step 3: Verify Deployment

```bash
# Wait a few minutes, then test
./final-verification.sh
```

## Expected Results

After successful deployment, you should see:

- ✅ All 6 applications responding with HTTP 200
- ✅ React apps loading correctly
- ✅ Latest code deployed
- ✅ Cross-service navigation working

## Troubleshooting

If you encounter issues:

1. **ECR Login Issues**: Make sure AWS credentials are configured with `aws configure`
2. **Docker Build Issues**: Ensure Docker is running
3. **ECS Update Issues**: Check ECS service status in AWS Console
4. **Health Check Issues**: Wait 2-3 minutes for services to fully restart

## Quick Verification

After deployment, test your applications:

- Admin Portal: http://stream-dev-fe-alb-471778558.eu-west-2.elb.amazonaws.com/admin-portal/
- Viewer Portal: http://stream-dev-fe-alb-471778558.eu-west-2.elb.amazonaws.com/viewer-portal/
- Creator Dashboard: http://stream-dev-fe-alb-471778558.eu-west-2.elb.amazonaws.com/creator-dashboard/
- Support System: http://stream-dev-fe-alb-471778558.eu-west-2.elb.amazonaws.com/support-system/
- Analytics Dashboard: http://stream-dev-fe-alb-471778558.eu-west-2.elb.amazonaws.com/analytics-dashboard/
- Developer Console: http://stream-dev-fe-alb-471778558.eu-west-2.elb.amazonaws.com/developer-console/

All should return HTTP 200 and load the React applications correctly.