#!/bin/bash

# Project Cleanup Script
# Removes all unnecessary duplicate files and keeps only what's needed for Git

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[CLEANUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_header "Project Cleanup - Removing Unnecessary Files"

# Function to safely remove files
safe_remove() {
    local file="$1"
    if [ -f "$file" ]; then
        print_status "Removing: $file"
        rm -f "$file"
    fi
}

# Function to safely remove directories
safe_remove_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        print_status "Removing directory: $dir"
        rm -rf "$dir"
    fi
}

print_header "1. Cleaning Root Directory - Removing Duplicate Scripts"

# Keep only the working scripts, remove all the failed attempts
SCRIPTS_TO_REMOVE=(
    "check-alb-status.sh"
    "check-service-status.sh" 
    "diagnose-alb-issues.sh"
    "diagnose-ecs-images.sh"
    "fix-alb-health-checks.sh"
    "fix-aurora-permanently.sh"
    "fix-conflicts.sh"
    "fix-container-health-issues.sh"
    "fix-container-vulnerabilities.sh"
    "fix-containers-properly.sh"
    "fix-ecs-image-tags.sh"
    "fix-ecs-task-failures.sh"
    "fix-existing-resources.sh"
    "fix-health-check-ports.sh"
    "fix-infinite-plan-loop.sh"
    "fix-kms-issues.sh"
    "fix-missing-images.sh"
    "fix-nginx-ports.sh"
    "fix-remaining-drift.sh"
    "fix-target-group-ports.sh"
    "force-ecs-update.sh"
    "quick-container-fix.sh"
    "quick-fix-ecs.sh"
    "rebuild-with-correct-ports.sh"
    "test-plan-stability.sh"
    "update-ecs-services.sh"
)

print_status "Removing ${#SCRIPTS_TO_REMOVE[@]} duplicate/failed scripts..."
for script in "${SCRIPTS_TO_REMOVE[@]}"; do
    safe_remove "$script"
done

# Keep fix-alb-completely.sh as it's the one that worked
print_status "Keeping: fix-alb-completely.sh (the working ALB fix)"

print_header "2. Cleaning Documentation - Removing Duplicate Guides"

# Remove duplicate documentation files, keep only the essential ones
DOCS_TO_REMOVE=(
    "COMPLETE_DEPLOYMENT_GUIDE.md"
    "COMPREHENSIVE_VALIDATION_REPORT.md"
    "DEPLOYMENT_ISSUES_ANALYSIS.md"
    "FUNCTIONAL_CONTAINERS_GUIDE.md"
    "NO_DOMAIN_DEPLOYMENT_GUIDE.md"
    "TERRAFORM_DRIFT_SOLUTION.md"
    "VALIDATION_REPORT.md"
)

print_status "Removing ${#DOCS_TO_REMOVE[@]} duplicate documentation files..."
for doc in "${DOCS_TO_REMOVE[@]}"; do
    safe_remove "$doc"
done

# Keep DEPLOYMENT_GUIDE.md and README.md as they're the main docs
print_status "Keeping: DEPLOYMENT_GUIDE.md, README.md (main documentation)"

print_header "3. Cleaning Terraform State Files"

# Remove old terraform state backups (keep only the main state)
TERRAFORM_CLEANUP=(
    "terraform.tfstate.*.backup"
    "tfplan"
    "tfplan.txt" 
    "tfplan2"
)

print_status "Removing old Terraform state backups..."
for pattern in "${TERRAFORM_CLEANUP[@]}"; do
    for file in $pattern; do
        if [ -f "$file" ]; then
            safe_remove "$file"
        fi
    done
done

print_status "Keeping: terraform.tfstate, terraform.tfstate.backup (current state)"

print_header "4. Cleaning Frontend Directory - Removing Duplicate Build Scripts"

cd streaming-platform-frontend

# Remove all the duplicate build scripts except the working one
FRONTEND_SCRIPTS_TO_REMOVE=(
    "build-containers-fixed.sh"
    "build-containers.sh"
    "build-demo.sh"
    "build-functional.sh"
    "build-production-ready.sh"
    "build-simple-containers.sh"
    "build-simple.sh"
    "deploy-all.sh"
    "fix-dockerfiles.sh"
    "fix-workspace-deps.sh"
    "install-dependencies.sh"
)

print_status "Removing ${#FRONTEND_SCRIPTS_TO_REMOVE[@]} duplicate frontend build scripts..."
for script in "${FRONTEND_SCRIPTS_TO_REMOVE[@]}"; do
    safe_remove "$script"
done

# Keep build-working-containers.sh and push-to-ecr.sh as they work
print_status "Keeping: build-working-containers.sh, push-to-ecr.sh (working scripts)"

# Remove duplicate Docker files
DOCKER_FILES_TO_REMOVE=(
    "Dockerfile.simple"
    "Dockerfile.template"
    "docker-compose.dev.yml"
)

print_status "Removing duplicate Docker files..."
for file in "${DOCKER_FILES_TO_REMOVE[@]}"; do
    safe_remove "$file"
done

# Keep main Dockerfile and docker-compose.yml
print_status "Keeping: Dockerfile, docker-compose.yml (main Docker files)"

# Remove analysis files
safe_remove "BUILD_ISSUES_ANALYSIS.md"

cd ..

print_header "5. Cleaning Package-Level Dockerfiles"

# Remove duplicate Dockerfiles in packages, keep only the main ones
PACKAGES=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

for package in "${PACKAGES[@]}"; do
    if [ -d "streaming-platform-frontend/packages/$package" ]; then
        # Remove any temporary or duplicate Dockerfiles
        safe_remove "streaming-platform-frontend/packages/$package/Dockerfile.working"
        safe_remove "streaming-platform-frontend/packages/$package/Dockerfile.simple"
        safe_remove "streaming-platform-frontend/packages/$package/Dockerfile.temp"
        
        # Keep the main Dockerfile if it exists
        if [ -f "streaming-platform-frontend/packages/$package/Dockerfile" ]; then
            print_status "Keeping: streaming-platform-frontend/packages/$package/Dockerfile"
        fi
    fi
done

print_header "6. Cleaning Temporary and Cache Files"

# Remove node_modules and build artifacts (they'll be rebuilt)
safe_remove_dir "streaming-platform-frontend/node_modules"
for package in "${PACKAGES[@]}"; do
    safe_remove_dir "streaming-platform-frontend/packages/$package/node_modules"
    safe_remove_dir "streaming-platform-frontend/packages/$package/dist"
done

# Remove shared package build artifacts
safe_remove_dir "streaming-platform-frontend/packages/shared/node_modules"
safe_remove_dir "streaming-platform-frontend/packages/shared/dist"
safe_remove_dir "streaming-platform-frontend/packages/ui/node_modules"
safe_remove_dir "streaming-platform-frontend/packages/ui/dist"
safe_remove_dir "streaming-platform-frontend/packages/auth/node_modules"
safe_remove_dir "streaming-platform-frontend/packages/auth/dist"

print_status "Removed all node_modules and dist directories (will be rebuilt)"

print_header "7. Creating Clean Build Script"

# Create a simple, clean build script that replaces all the others
cat > build-and-deploy.sh << 'EOF'
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
EOF

chmod +x build-and-deploy.sh
print_status "Created: build-and-deploy.sh (single script to build and deploy everything)"

print_header "8. Summary of Files Kept"

print_status "Essential Terraform files:"
print_status "  - main.tf, variables.tf, outputs.tf, terraform.tfvars"
print_status "  - modules/ directory (all infrastructure modules)"

print_status "Essential scripts:"
print_status "  - fix-alb-completely.sh (working ALB fix)"
print_status "  - build-and-deploy.sh (new unified build/deploy script)"
print_status "  - deploy-clean.sh (clean deployment)"

print_status "Essential frontend files:"
print_status "  - streaming-platform-frontend/build-working-containers.sh"
print_status "  - streaming-platform-frontend/push-to-ecr.sh"
print_status "  - streaming-platform-frontend/package.json, lerna.json"
print_status "  - All source code in packages/"

print_status "Essential documentation:"
print_status "  - README.md"
print_status "  - DEPLOYMENT_GUIDE.md"

print_header "Cleanup Complete!"

print_status "✅ Removed all duplicate and unnecessary files"
print_status "✅ Kept only working scripts and essential files"
print_status "✅ Project is now clean and ready for Git"

echo ""
print_status "Next steps:"
print_status "1. Review the cleaned project structure"
print_status "2. Test the build: ./build-and-deploy.sh"
print_status "3. Commit to Git: git add . && git commit -m 'Clean up project structure'"

echo ""
print_status "🎉 Your project is now clean and production-ready!"