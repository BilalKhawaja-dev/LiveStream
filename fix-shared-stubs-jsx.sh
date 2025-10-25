#!/bin/bash

echo "=== FIXING SHARED STUBS JSX ==="
echo "Converting shared stubs to use proper JSX files"

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Fixing shared stub for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Create shared.ts without JSX components
    cat > "$service_dir/src/stubs/shared.ts" << 'EOF'
import { create } from 'zustand';

interface GlobalState {
  theme: 'light' | 'dark';
  notifications: any[];
  setTheme: (theme: 'light' | 'dark') => void;
  addNotification: (notification: any) => void;
}

export const useGlobalStore = create<GlobalState>((set) => ({
  theme: 'light',
  notifications: [],
  setTheme: (theme) => set({ theme }),
  addNotification: (notification) => set((state) => ({ 
    notifications: [...state.notifications, notification] 
  })),
}));

export const secureLogger = {
  info: (message: string, data?: any, context?: any) => {
    console.log(`[INFO] ${message}`, data, context);
  },
  error: (message: string, error?: any, context?: any) => {
    console.error(`[ERROR] ${message}`, error, context);
  },
  warn: (message: string, data?: any, context?: any) => {
    console.warn(`[WARN] ${message}`, data, context);
  },
};

export interface LogContext {
  component?: string;
  userId?: string;
  action?: string;
}
EOF

    # Create shared-components.tsx for JSX components
    cat > "$service_dir/src/stubs/shared-components.tsx" << 'EOF'
import React from 'react';

export const ServiceNavigationMenu: React.FC<{ currentService?: string }> = ({ currentService }) => {
  return (
    <nav style={{ padding: '1rem', backgroundColor: '#f0f0f0', marginBottom: '1rem' }}>
      <div style={{ display: 'flex', gap: '1rem' }}>
        <a href="/viewer-portal/" style={{ textDecoration: 'none', color: currentService === 'viewer-portal' ? '#007bff' : '#333' }}>
          Viewer Portal
        </a>
        <a href="/creator-dashboard/" style={{ textDecoration: 'none', color: currentService === 'creator-dashboard' ? '#007bff' : '#333' }}>
          Creator Dashboard
        </a>
        <a href="/admin-portal/" style={{ textDecoration: 'none', color: currentService === 'admin-portal' ? '#007bff' : '#333' }}>
          Admin Portal
        </a>
        <a href="/developer-console/" style={{ textDecoration: 'none', color: currentService === 'developer-console' ? '#007bff' : '#333' }}>
          Developer Console
        </a>
        <a href="/analytics-dashboard/" style={{ textDecoration: 'none', color: currentService === 'analytics-dashboard' ? '#007bff' : '#333' }}>
          Analytics Dashboard
        </a>
        <a href="/support-system/" style={{ textDecoration: 'none', color: currentService === 'support-system' ? '#007bff' : '#333' }}>
          Support System
        </a>
      </div>
    </nav>
  );
};

export const CrossServiceProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return <div>{children}</div>;
};

export const SupportButton: React.FC = () => {
  return (
    <button 
      style={{ 
        position: 'fixed', 
        bottom: '20px', 
        right: '20px', 
        backgroundColor: '#007bff', 
        color: 'white', 
        border: 'none', 
        borderRadius: '50%', 
        width: '60px', 
        height: '60px', 
        cursor: 'pointer' 
      }}
      onClick={() => window.open('/support-system/', '_blank')}
    >
      ?
    </button>
  );
};
EOF

    # Update imports in files that use ServiceNavigationMenu
    find "$service_dir/src" -name "*.tsx" -o -name "*.ts" | while read -r file; do
        # Skip the stub files themselves
        if [[ "$file" == *"/stubs/"* ]]; then
            continue
        fi
        
        # Replace ServiceNavigationMenu imports
        if grep -q "ServiceNavigationMenu.*from.*shared" "$file"; then
            echo "  Fixing ServiceNavigationMenu import in $(basename "$file")"
            
            # Calculate relative path to stubs directory
            file_dir=$(dirname "$file")
            rel_path=$(realpath --relative-to="$file_dir" "$service_dir/src/stubs")
            
            sed -i "s|import { ServiceNavigationMenu } from '$rel_path/shared'|import { ServiceNavigationMenu } from '$rel_path/shared-components'|g" "$file"
            sed -i "s|import { \([^}]*\), ServiceNavigationMenu } from '$rel_path/shared'|import { \1 } from '$rel_path/shared';\nimport { ServiceNavigationMenu } from '$rel_path/shared-components'|g" "$file"
            sed -i "s|import { ServiceNavigationMenu, \([^}]*\) } from '$rel_path/shared'|import { ServiceNavigationMenu } from '$rel_path/shared-components';\nimport { \1 } from '$rel_path/shared'|g" "$file"
        fi
        
        # Also fix any other cross-service component imports
        sed -i "s|CrossServiceProvider.*from.*shared|CrossServiceProvider } from '$rel_path/shared-components'|g" "$file"
        sed -i "s|SupportButton.*from.*shared|SupportButton } from '$rel_path/shared-components'|g" "$file"
    done
    
    echo "✅ Fixed shared stub for $service"
done

echo "=== SHARED STUBS JSX FIXED ==="