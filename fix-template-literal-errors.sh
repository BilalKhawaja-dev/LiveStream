#!/bin/bash

echo "=== FIXING TEMPLATE LITERAL ERRORS ==="

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Fixing template literals for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Fix common template literal issues
    find "$service_dir/src" -name "*.tsx" -o -name "*.ts" | while read -r file; do
        # Skip the stub files themselves
        if [[ "$file" == *"/stubs/"* ]]; then
            continue
        fi
        
        # Fix common template literal syntax errors
        # Fix: ${condition ? 'value' : '}`} -> ${condition ? 'value' : ''}`}
        sed -i "s/\${[^}]*? '[^']*' : '}\`}/\${&''}\`}/g" "$file"
        
        # More specific fix for the pattern we saw
        sed -i "s/\${sidebarOpen ? 'open' : '}\`}/\${sidebarOpen ? 'open' : ''}\`}/g" "$file"
        sed -i "s/\${[^}]*Open ? 'open' : '}\`}/\${&''}\`}/g" "$file"
        
        # Fix any other similar patterns
        sed -i "s/: '}\`}/: ''}\`}/g" "$file"
        
        echo "  Fixed template literals in $(basename "$file")"
    done
    
    echo "✅ Fixed template literals for $service"
done

echo "=== TEMPLATE LITERAL ERRORS FIXED ==="