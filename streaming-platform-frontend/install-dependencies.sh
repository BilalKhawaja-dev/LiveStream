#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Install dependencies for streaming platform frontend
echo "🚀 Installing dependencies for streaming platform frontend..."

# Function to handle errors
handle_error() {
    echo "❌ Error occurred in: $1"
    echo "💡 Try running: npm cache clean --force"
    exit 1
}

# Function to install package dependencies
install_package() {
    local package_name="$1"
    local package_path="$2"
    
    if [[ -d "$package_path" ]]; then
        echo "📦 Installing $package_name dependencies..."
        cd "$package_path" || handle_error "changing to $package_path"
        npm install || handle_error "installing $package_name dependencies"
        cd - > /dev/null || handle_error "returning from $package_path"
    else
        echo "⚠️  Package directory $package_path not found, skipping..."
    fi
}

# Install root dependencies
echo "📦 Installing root dependencies..."
npm install || handle_error "installing root dependencies"

# Install dependencies for each package
echo "📦 Installing package dependencies..."

# Define packages to install
declare -A packages=(
    ["shared"]="packages/shared"
    ["ui"]="packages/ui"
    ["auth"]="packages/auth"
    ["viewer-portal"]="packages/viewer-portal"
    ["creator-dashboard"]="packages/creator-dashboard"
    ["admin-portal"]="packages/admin-portal"
    ["support-system"]="packages/support-system"
    ["analytics-dashboard"]="packages/analytics-dashboard"
    ["developer-console"]="packages/developer-console"
)

# Install each package
for package_name in "${!packages[@]}"; do
    install_package "$package_name" "${packages[$package_name]}"
done

echo "✅ All dependencies installed successfully!"
echo "🎯 Run 'npm run dev' to start all applications in development mode"