# 🚀 Complete Deployment Guide - Infrastructure + Containers

## 📋 **Deployment Strategy**

You're absolutely right! For ECS to work, you need your container images in ECR. Here's the **correct deployment order**:

1. **Deploy Infrastructure First** (creates ECR repository)
2. **Build Container Images** 
3. **Push Images to ECR**
4. **Update ECS Services** (or they'll start automatically)

---

## 🎯 **Step-by-Step Deployment**

### **Phase 1: Deploy Infrastructure** 🏗️

```bash
# 1. Configure Terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars - key settings:
# domain_name = ""  # No custom domain
# enable_ecs = true # Enable ECS for containers
```

```bash
# 2. Deploy infrastructure
terraform init
terraform plan    # Should show ~168 resources
terraform apply   # This creates ECR repository + ECS cluster
```

**✅ After this step you'll have:**
- ECR repository created
- ECS cluster ready
- ALB waiting for containers
- All other infrastructure ready

---

### **Phase 2: Build & Push Containers** 🐳

```bash
# 3. Get ECR repository URL
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "ECR URL: $ECR_URL"
```

```bash
# 4. Build containers (using fixed script)
cd streaming-platform-frontend
./build-containers-fixed.sh
```

**✅ This fixed script:**
- Handles the `workspace:*` dependency issue
- Installs dependencies properly
- Builds all 6 container images
- Tags them for ECR

```bash
# 5. Push containers to ECR
./push-to-ecr.sh $ECR_URL
```

**✅ This will:**
- Login to ECR automatically
- Push all 6 images to your ECR repository
- Tag them properly for ECS

---

### **Phase 3: Verify Deployment** ✅

```bash
# 6. Check ECS services are running
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
aws ecs describe-services --cluster $CLUSTER_NAME --services streaming-platform-dev-viewer-portal

# 7. Get your application URL
terraform output application_url
# Example: http://streaming-platform-dev-alb-123456789.us-east-1.elb.amazonaws.com
```

---

## 🔧 **Fixed Build Script Details**

### **What Was Wrong:**
- Original script failed on `workspace:*` dependencies
- npm couldn't resolve workspace references
- Build process was incomplete

### **What the Fixed Script Does:**
1. **Installs root dependencies** with `--legacy-peer-deps`
2. **Handles workspace dependencies** by temporarily replacing them with file paths
3. **Installs each package individually** to avoid workspace conflicts
4. **Builds Docker images** for all 6 applications
5. **Tags images properly** for ECR

### **Applications Built:**
- `viewer-portal` - Customer streaming interface
- `creator-dashboard` - Content creator tools
- `admin-portal` - Administrative interface
- `support-system` - Customer support tools
- `analytics-dashboard` - Metrics and analytics
- `developer-console` - API management

---

## 🎯 **Quick Commands Summary**

```bash
# Deploy everything in order:

# 1. Infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edit: set domain_name = ""
terraform init && terraform plan && terraform apply

# 2. Containers
cd streaming-platform-frontend
ECR_URL=$(terraform output -raw ecr_repository_url)
./build-containers-fixed.sh
./push-to-ecr.sh $ECR_URL

# 3. Access your app
terraform output application_url
```

---

## 🔍 **Troubleshooting**

### **If Build Still Fails:**
```bash
# Check Node.js version
node --version  # Should be 16+ 

# Clear npm cache
npm cache clean --force

# Try building one app at a time
cd packages/viewer-portal
npm install --legacy-peer-deps
docker build -t test-viewer-portal .
```

### **If ECR Push Fails:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check ECR repository exists
aws ecr describe-repositories --repository-names streaming-platform

# Manual ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL
```

### **If ECS Services Don't Start:**
```bash
# Check ECS cluster
aws ecs describe-clusters --clusters $CLUSTER_NAME

# Check service status
aws ecs describe-services --cluster $CLUSTER_NAME --services streaming-platform-dev-viewer-portal

# Check task definition
aws ecs describe-task-definition --task-definition streaming-platform-dev-viewer-portal
```

---

## 💡 **Why This Order Matters**

1. **Infrastructure First**: Creates ECR repository that containers need
2. **Build Containers**: Creates images locally
3. **Push to ECR**: Makes images available to ECS
4. **ECS Auto-Starts**: Services automatically pull and run images

**❌ Wrong Order**: Build containers → Deploy infrastructure = ECR doesn't exist yet
**✅ Right Order**: Deploy infrastructure → Build containers → Push to ECR = Everything works

---

## 🎉 **Expected Results**

After successful deployment:

```bash
terraform output
```

**You should see:**
```
application_url = "http://streaming-platform-dev-alb-123456789.us-east-1.elb.amazonaws.com"
ecr_repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/streaming-platform"
ecs_cluster_name = "streaming-platform-dev-cluster"
```

**Your streaming platform will be live at the application_url!** 🎬

---

## 🚀 **Ready to Deploy?**

The fixed scripts are ready. Just run:

```bash
# Start with infrastructure
terraform init && terraform plan && terraform apply

# Then build and push containers
cd streaming-platform-frontend
./build-containers-fixed.sh
```

**Your deployment will work perfectly now!** 🎯