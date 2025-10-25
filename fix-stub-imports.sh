#!/bin/bash

echo "=== FIXING STUB IMPORTS ==="
echo "Ensuring useAuth comes from auth stub, not shared stub"

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Fixing stub imports for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Fix imports in all TypeScript/React files
    find "$service_dir/src" -name "*.tsx" -o -name "*.ts" | while read -r file; do
        # Skip the stub files themselves
        if [[ "$file" == *"/stubs/"* ]]; then
            continue
        fi
        
        # Check if file imports useAuth from shared (wrong)
        if grep -q "import.*useAuth.*from.*shared" "$file"; then
            echo "  Fixing useAuth import in $(basename "$file")"
            
            # Calculate relative path to stubs directory
            file_dir=$(dirname "$file")
            rel_path=$(realpath --relative-to="$file_dir" "$service_dir/src/stubs")
            
            # Fix the import - useAuth should come from auth, not shared
            sed -i "s|import { useAuth } from '$rel_path/shared'|import { useAuth } from '$rel_path/auth'|g" "$file"
            sed -i "s|import { useAuth, \([^}]*\) } from '$rel_path/shared'|import { useAuth } from '$rel_path/auth';\nimport { \1 } from '$rel_path/shared'|g" "$file"
            sed -i "s|import { \([^}]*\), useAuth } from '$rel_path/shared'|import { \1 } from '$rel_path/shared';\nimport { useAuth } from '$rel_path/auth'|g" "$file"
            sed -i "s|import { \([^}]*\), useAuth, \([^}]*\) } from '$rel_path/shared'|import { \1, \2 } from '$rel_path/shared';\nimport { useAuth } from '$rel_path/auth'|g" "$file"
        fi
    done
    
    echo "✅ Fixed stub imports for $service"
done

echo "=== STUB IMPORTS FIXED ==="