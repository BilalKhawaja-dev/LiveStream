#!/bin/bash

echo "=== FIXING ALL IMPORTS CORRECTLY ==="

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Fixing imports for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Fix imports in src/ (main level) - path is ./stubs/
    find "$service_dir/src" -maxdepth 1 -name "*.tsx" -o -name "*.ts" | while read -r file; do
        sed -i "s|from '[^']*stubs/auth'|from './stubs/auth'|g" "$file"
        sed -i "s|from '[^']*stubs/shared'|from './stubs/shared'|g" "$file"
        sed -i "s|from '[^']*stubs/ui'|from './stubs/ui'|g" "$file"
        sed -i "s|import('[^']*stubs/shared')|import('./stubs/shared')|g" "$file"
        echo "  Fixed $(basename "$file") (root level)"
    done
    
    # Fix imports in src/components/ (one level deep) - path is ../stubs/
    find "$service_dir/src/components" -maxdepth 1 -name "*.tsx" -o -name "*.ts" | while read -r file; do
        sed -i "s|from '[^']*stubs/auth'|from '../stubs/auth'|g" "$file"
        sed -i "s|from '[^']*stubs/shared'|from '../stubs/shared'|g" "$file"
        sed -i "s|from '[^']*stubs/ui'|from '../stubs/ui'|g" "$file"
        sed -i "s|import('[^']*stubs/shared')|import('../stubs/shared')|g" "$file"
        echo "  Fixed $(basename "$file") (components level)"
    done
    
    # Fix imports in src/components/*/ (two levels deep) - path is ../../stubs/
    find "$service_dir/src/components" -mindepth 2 -name "*.tsx" -o -name "*.ts" | while read -r file; do
        sed -i "s|from '[^']*stubs/auth'|from '../../stubs/auth'|g" "$file"
        sed -i "s|from '[^']*stubs/shared'|from '../../stubs/shared'|g" "$file"
        sed -i "s|from '[^']*stubs/ui'|from '../../stubs/ui'|g" "$file"
        sed -i "s|import('[^']*stubs/shared')|import('../../stubs/shared')|g" "$file"
        echo "  Fixed $(basename "$file") (deep level)"
    done
    
    echo "✅ Fixed all imports for $service"
done

echo "=== ALL IMPORTS FIXED ==="