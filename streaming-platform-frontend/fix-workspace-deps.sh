#!/bin/bash

# Fix workspace dependencies script
set -e

echo "🔧 Fixing workspace dependencies..."

# List of packages that have workspace dependencies
PACKAGES=("viewer-portal" "creator-dashboard" "admin-portal" "support-system" "analytics-dashboard" "developer-console")

# Fix each package.json
for pkg in "${PACKAGES[@]}"; do
    if [ -f "packages/$pkg/package.json" ]; then
        echo "Fixing packages/$pkg/package.json"
        
        # Create backup
        cp "packages/$pkg/package.json" "packages/$pkg/package.json.backup"
        
        # Replace workspace dependencies with file references
        sed -i 's/"@streaming\/shared": "workspace:\*"/"@streaming\/shared": "file:..\/shared"/g' "packages/$pkg/package.json"
        sed -i 's/"@streaming\/ui": "workspace:\*"/"@streaming\/ui": "file:..\/ui"/g' "packages/$pkg/package.json"
        sed -i 's/"@streaming\/auth": "workspace:\*"/"@streaming\/auth": "file:..\/auth"/g' "packages/$pkg/package.json"
        
        echo "✅ Fixed packages/$pkg/package.json"
    fi
done

echo "🎉 All workspace dependencies fixed!"
echo ""
echo "Now you can run: npm install --legacy-peer-deps"