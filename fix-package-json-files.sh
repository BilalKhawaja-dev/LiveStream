#!/bin/bash

echo "=== FIXING PACKAGE.JSON FILES ==="

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Fixing package.json for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Restore from backup and fix properly
    if [ -f "$service_dir/package.json.backup" ]; then
        cp "$service_dir/package.json.backup" "$service_dir/package.json"
    fi
    
    # Create a clean package.json
    cat > "$service_dir/package.json" << EOF
{
  "name": "@streaming/$service",
  "version": "1.0.0",
  "description": "$service application",
  "main": "dist/index.js",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "lint": "eslint src --ext .ts,.tsx",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@chakra-ui/react": "^2.8.0",
    "@emotion/react": "^11.11.1",
    "@emotion/styled": "^11.11.0",
    "framer-motion": "^10.16.4",
    "@heroicons/react": "^2.0.18",
    "react-chartjs-2": "^5.2.0",
    "chart.js": "^4.4.0",
    "react-router-dom": "^6.15.0",
    "zustand": "^4.4.1"
  },
  "devDependencies": {
    "@types/react": "^18.2.15",
    "@types/react-dom": "^18.2.7",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "@vitejs/plugin-react": "^4.0.3",
    "eslint": "^8.45.0",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.3",
    "typescript": "^5.1.6",
    "vite": "^4.4.5"
  }
}
EOF

    echo "✅ Fixed package.json for $service"
done

echo "=== PACKAGE.JSON FILES FIXED ==="