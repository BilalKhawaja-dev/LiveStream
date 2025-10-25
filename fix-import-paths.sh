#!/bin/bash

echo "=== FIXING IMPORT PATHS ==="

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Fixing import paths for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Fix imports in all TypeScript/React files
    find "$service_dir/src" -name "*.tsx" -o -name "*.ts" | while read -r file; do
        # Skip the stub files themselves
        if [[ "$file" == *"/stubs/"* ]]; then
            continue
        fi
        
        # Calculate relative path to stubs directory
        file_dir=$(dirname "$file")
        rel_path=$(realpath --relative-to="$file_dir" "$service_dir/src/stubs")
        
        # Replace imports with correct relative paths
        sed -i "s|from '@streaming/auth'|from '$rel_path/auth'|g" "$file"
        sed -i "s|from '@streaming/shared'|from '$rel_path/shared'|g" "$file"
        sed -i "s|from '@streaming/ui'|from '$rel_path/ui'|g" "$file"
        
        # Handle dynamic imports
        sed -i "s|import('@streaming/shared')|import('$rel_path/shared')|g" "$file"
        
        echo "  Fixed imports in $(basename "$file")"
    done
    
    echo "✅ Fixed import paths for $service"
done

echo "=== IMPORT PATHS FIXED ==="