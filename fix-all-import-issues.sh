#!/bin/bash

echo "=== FIXING ALL IMPORT ISSUES ==="

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Fixing all imports for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Fix all files
    find "$service_dir/src" -name "*.tsx" -o -name "*.ts" | while read -r file; do
        # Skip the stub files themselves
        if [[ "$file" == *"/stubs/"* ]]; then
            continue
        fi
        
        # Remove any double quotes
        sed -i "s/''/'/g" "$file"
        
        # Fix AuthProvider imports - should come from auth
        sed -i "s|AuthProvider.*from.*shared|AuthProvider } from './stubs/auth'|g" "$file"
        sed -i "s|import { AuthProvider, \([^}]*\) } from './stubs/shared'|import { AuthProvider } from './stubs/auth';\nimport { \1 } from './stubs/shared'|g" "$file"
        sed -i "s|import { \([^}]*\), AuthProvider } from './stubs/shared'|import { \1 } from './stubs/shared';\nimport { AuthProvider } from './stubs/auth'|g" "$file"
        
        # Fix wrong relative paths (../../stubs should be ./stubs for root level files)
        if [[ "$file" == "$service_dir/src/App.tsx" ]] || [[ "$file" == "$service_dir/src/main.tsx" ]]; then
            sed -i "s|from '../../stubs/|from './stubs/|g" "$file"
        fi
        
        # Remove any unused imports
        sed -i "s|, useAuth, withAuth||g" "$file"
        sed -i "s|useAuth, withAuth, ||g" "$file"
        sed -i "s|, withAuth||g" "$file"
        sed -i "s|withAuth, ||g" "$file"
        
        echo "  Fixed $(basename "$file")"
    done
    
    echo "✅ Fixed all imports for $service"
done

echo "=== ALL IMPORT ISSUES FIXED ==="