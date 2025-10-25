#!/bin/bash

echo "=== CREATING STANDALONE TSCONFIG FILES ==="

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Creating standalone tsconfig.json for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Backup original
    if [ -f "$service_dir/tsconfig.json" ]; then
        cp "$service_dir/tsconfig.json" "$service_dir/tsconfig.json.backup"
    fi
    
    # Create standalone tsconfig.json
    cat > "$service_dir/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
EOF

    # Create tsconfig.node.json if it doesn't exist
    if [ ! -f "$service_dir/tsconfig.node.json" ]; then
        cat > "$service_dir/tsconfig.node.json" << 'EOF'
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
EOF
    fi
    
    echo "✅ Created standalone tsconfig.json for $service"
done

echo "=== STANDALONE TSCONFIG FILES CREATED ==="