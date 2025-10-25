#!/bin/bash
# Create a simple test app to validate the Docker build process

set -e

echo "🚀 Creating Simple Test App"
echo "=========================="

# Create a minimal test app
mkdir -p test-app/src
mkdir -p test-app/public

# Create package.json
cat > test-app/package.json << 'EOF'
{
  "name": "test-app",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.15",
    "@types/react-dom": "^18.2.7",
    "@vitejs/plugin-react": "^4.0.3",
    "typescript": "^5.1.6",
    "vite": "^4.4.5"
  }
}
EOF

# Create vite.config.ts
cat > test-app/vite.config.ts << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: '/',
  server: {
    port: 3000,
    host: true,
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});
EOF

# Create index.html
cat > test-app/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Test App - Working!</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# Create main.tsx
cat > test-app/src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

# Create App.tsx
cat > test-app/src/App.tsx << 'EOF'
import React from 'react'

function App() {
  return (
    <div style={{ 
      padding: '20px', 
      fontFamily: 'Arial, sans-serif',
      backgroundColor: '#f0f0f0',
      minHeight: '100vh'
    }}>
      <h1 style={{ color: '#333' }}>🎉 Test App Working!</h1>
      <p>If you can see this, the React app is loading correctly.</p>
      <div style={{ 
        backgroundColor: 'white', 
        padding: '15px', 
        borderRadius: '8px',
        marginTop: '20px'
      }}>
        <h2>Status Check:</h2>
        <ul>
          <li>✅ React is working</li>
          <li>✅ JavaScript is loading</li>
          <li>✅ CSS is working</li>
          <li>✅ Assets are being served</li>
        </ul>
      </div>
      <button 
        onClick={() => alert('Button works!')}
        style={{
          padding: '10px 20px',
          backgroundColor: '#007bff',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
          marginTop: '20px'
        }}
      >
        Test Button
      </button>
    </div>
  )
}

export default App
EOF

# Create tsconfig.json
cat > test-app/tsconfig.json << 'EOF'
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
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
EOF

# Create tsconfig.node.json
cat > test-app/tsconfig.node.json << 'EOF'
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

# Create nginx.conf
cat > test-app/nginx.conf << 'EOF'
server {
    listen 3000;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Handle React Router (SPA routing)
    location / {
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Health check endpoints
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location /healthz {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
    
    # Prevent access to sensitive files
    location ~ /\. {
        deny all;
    }
}
EOF

# Create Dockerfile
cat > test-app/Dockerfile << 'EOF'
# Multi-stage build for test app
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig*.json ./
COPY vite.config.ts ./

# Install dependencies
RUN npm install

# Copy source code
COPY src ./src/
COPY index.html ./
COPY public ./public/

# Build the application
RUN npm run build

# Verify build output exists
RUN ls -la dist/ && test -f dist/index.html

# Production stage
FROM nginx:alpine

# Install curl for health checks
RUN apk update && apk upgrade && apk add --no-cache curl

# Copy built application from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create health check endpoint
RUN echo '<!DOCTYPE html><html><body><h1>OK</h1></body></html>' > /usr/share/nginx/html/health

# Expose the application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

echo "✅ Test app created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. cd test-app"
echo "2. npm install"
echo "3. npm run build"
echo "4. docker build -t test-app ."
echo "5. docker run -p 3000:3000 test-app"
echo "6. Open http://localhost:3000"