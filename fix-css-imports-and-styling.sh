#!/bin/bash

echo "🎨 Fixing CSS imports and styling for all frontend services..."

# Services to fix
SERVICES=("admin-portal" "creator-dashboard" "developer-console" "analytics-dashboard" "support-system")

cd streaming-platform-frontend

for SERVICE in "${SERVICES[@]}"; do
    echo "📦 Fixing CSS imports for $SERVICE..."
    
    # Check if CSS file exists
    CSS_FILE="packages/$SERVICE/src/styles/${SERVICE//-/_}-theme.css"
    if [ ! -f "$CSS_FILE" ]; then
        CSS_FILE="packages/$SERVICE/src/styles/${SERVICE}-theme.css"
    fi
    
    if [ -f "$CSS_FILE" ]; then
        echo "✅ Found CSS file: $CSS_FILE"
        
        # Update main.tsx to import CSS
        MAIN_FILE="packages/$SERVICE/src/main.tsx"
        if [ -f "$MAIN_FILE" ]; then
            echo "🔧 Adding CSS import to $MAIN_FILE..."
            
            # Create backup
            cp "$MAIN_FILE" "$MAIN_FILE.backup"
            
            # Add CSS import at the top (after React imports)
            cat > "$MAIN_FILE" << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import { ChakraProvider } from '@chakra-ui/react'
import App from './App.tsx'
import './styles/SERVICE_NAME-theme.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ChakraProvider>
      <App />
    </ChakraProvider>
  </React.StrictMode>,
)
EOF
            
            # Replace SERVICE_NAME with actual service name
            sed -i "s/SERVICE_NAME/${SERVICE}/g" "$MAIN_FILE"
            
            echo "✅ Updated $MAIN_FILE with CSS import"
        fi
        
        # Also check if we need to update App.tsx
        APP_FILE="packages/$SERVICE/src/App.tsx"
        if [ -f "$APP_FILE" ]; then
            echo "🔧 Ensuring App.tsx has proper ChakraProvider wrapper..."
            
            # Check if ChakraProvider is already imported
            if ! grep -q "ChakraProvider" "$APP_FILE"; then
                echo "📝 Adding ChakraProvider to App.tsx..."
                
                # Create backup
                cp "$APP_FILE" "$APP_FILE.backup"
                
                # Add ChakraProvider import and wrapper
                sed -i '1i import { ChakraProvider } from "@chakra-ui/react";' "$APP_FILE"
                
                # Wrap the return statement with ChakraProvider if not already wrapped
                if ! grep -q "<ChakraProvider>" "$APP_FILE"; then
                    # This is a simple approach - might need manual adjustment for complex cases
                    sed -i 's/return (/return (\n    <ChakraProvider>/' "$APP_FILE"
                    sed -i 's/);$/    <\/ChakraProvider>\n  );/' "$APP_FILE"
                fi
            fi
        fi
        
    else
        echo "⚠️  No CSS file found for $SERVICE, creating basic one..."
        
        # Create styles directory if it doesn't exist
        mkdir -p "packages/$SERVICE/src/styles"
        
        # Create basic CSS file
        cat > "packages/$SERVICE/src/styles/${SERVICE}-theme.css" << 'EOF'
/* Basic styling for SERVICE_NAME */
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

.app-container {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 20px;
}

.main-content {
  max-width: 1200px;
  margin: 0 auto;
  background: white;
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
  padding: 30px;
}

.header {
  text-align: center;
  margin-bottom: 30px;
  padding-bottom: 20px;
  border-bottom: 2px solid #e2e8f0;
}

.header h1 {
  color: #2d3748;
  font-size: 2.5rem;
  margin-bottom: 10px;
  font-weight: 700;
}

.header p {
  color: #718096;
  font-size: 1.1rem;
}

.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 20px;
  margin-top: 30px;
}

.dashboard-card {
  background: #f7fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 20px;
  transition: all 0.3s ease;
}

.dashboard-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 5px 15px rgba(0, 0, 0, 0.1);
}

.dashboard-card h3 {
  color: #2d3748;
  margin-bottom: 15px;
  font-size: 1.3rem;
}

.dashboard-card p {
  color: #4a5568;
  line-height: 1.6;
}

.status-indicator {
  display: inline-block;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  margin-right: 8px;
}

.status-online {
  background-color: #48bb78;
}

.status-offline {
  background-color: #f56565;
}

.status-warning {
  background-color: #ed8936;
}

.btn {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 600;
  transition: all 0.3s ease;
}

.btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
}

.metric-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 20px;
  text-align: center;
}

.metric-value {
  font-size: 2rem;
  font-weight: 700;
  color: #2d3748;
  margin-bottom: 5px;
}

.metric-label {
  color: #718096;
  font-size: 0.9rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
EOF
        
        # Replace SERVICE_NAME placeholder
        sed -i "s/SERVICE_NAME/${SERVICE}/g" "packages/$SERVICE/src/styles/${SERVICE}-theme.css"
        
        echo "✅ Created basic CSS file for $SERVICE"
    fi
done

echo ""
echo "🔧 Ensuring all services have proper package.json dependencies..."

for SERVICE in "${SERVICES[@]}"; do
    PACKAGE_JSON="packages/$SERVICE/package.json"
    if [ -f "$PACKAGE_JSON" ]; then
        echo "📦 Checking dependencies for $SERVICE..."
        
        # Ensure Chakra UI is in dependencies
        if ! grep -q "@chakra-ui/react" "$PACKAGE_JSON"; then
            echo "➕ Adding Chakra UI dependencies to $SERVICE..."
            
            # Create backup
            cp "$PACKAGE_JSON" "$PACKAGE_JSON.backup"
            
            # Add Chakra UI dependencies (this is a simple approach)
            sed -i '/"dependencies": {/a\    "@chakra-ui/react": "^2.8.2",' "$PACKAGE_JSON"
            sed -i '/"dependencies": {/a\    "@emotion/react": "^11.11.1",' "$PACKAGE_JSON"
            sed -i '/"dependencies": {/a\    "@emotion/styled": "^11.11.0",' "$PACKAGE_JSON"
            sed -i '/"dependencies": {/a\    "framer-motion": "^10.16.4",' "$PACKAGE_JSON"
        fi
    fi
done

echo ""
echo "🏗️  Building services with proper CSS imports..."

for SERVICE in "${SERVICES[@]}"; do
    echo "🔨 Building $SERVICE..."
    cd "packages/$SERVICE"
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ] || [ ! -f "node_modules/.package-lock.json" ]; then
        echo "📦 Installing dependencies for $SERVICE..."
        npm install --silent
    fi
    
    # Build the service
    echo "🏗️  Building $SERVICE..."
    npm run build
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully built $SERVICE"
        
        # Check if CSS files were generated
        if [ -d "dist/assets" ]; then
            CSS_COUNT=$(find dist/assets -name "*.css" | wc -l)
            echo "📄 Generated $CSS_COUNT CSS files in dist/assets"
            
            # List the CSS files
            find dist/assets -name "*.css" -exec basename {} \; | head -3
        fi
    else
        echo "❌ Failed to build $SERVICE"
    fi
    
    cd ../..
done

echo ""
echo "🐳 Rebuilding Docker images with proper styling..."

for SERVICE in "${SERVICES[@]}"; do
    echo "🐳 Building Docker image for $SERVICE..."
    
    cd "packages/$SERVICE"
    
    # Build Docker image
    docker build -t "streaming-$SERVICE:latest" .
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully built Docker image for $SERVICE"
        
        # Test the container briefly to see if it starts
        echo "🧪 Testing container startup..."
        CONTAINER_ID=$(docker run -d -p 0:3000 "streaming-$SERVICE:latest")
        sleep 3
        
        if docker ps | grep -q "$CONTAINER_ID"; then
            echo "✅ Container starts successfully"
            docker stop "$CONTAINER_ID" > /dev/null 2>&1
            docker rm "$CONTAINER_ID" > /dev/null 2>&1
        else
            echo "⚠️  Container may have issues"
            docker logs "$CONTAINER_ID" 2>/dev/null | tail -5
            docker rm "$CONTAINER_ID" > /dev/null 2>&1
        fi
    else
        echo "❌ Failed to build Docker image for $SERVICE"
    fi
    
    cd ../..
done

echo ""
echo "📋 CSS Import Fix Summary:"
echo "=========================="

for SERVICE in "${SERVICES[@]}"; do
    echo "📦 $SERVICE:"
    
    # Check if CSS file exists
    CSS_FILE="packages/$SERVICE/src/styles/${SERVICE}-theme.css"
    if [ -f "$CSS_FILE" ]; then
        echo "  ✅ CSS file exists"
    else
        echo "  ❌ CSS file missing"
    fi
    
    # Check if main.tsx imports CSS
    MAIN_FILE="packages/$SERVICE/src/main.tsx"
    if [ -f "$MAIN_FILE" ] && grep -q "\.css" "$MAIN_FILE"; then
        echo "  ✅ CSS imported in main.tsx"
    else
        echo "  ❌ CSS not imported in main.tsx"
    fi
    
    # Check if build succeeded
    if [ -d "packages/$SERVICE/dist" ]; then
        echo "  ✅ Build successful"
        CSS_COUNT=$(find "packages/$SERVICE/dist/assets" -name "*.css" 2>/dev/null | wc -l)
        echo "  📄 Generated $CSS_COUNT CSS files"
    else
        echo "  ❌ Build failed or missing"
    fi
    
    echo ""
done

echo "🎨 CSS import fix completed!"
echo ""
echo "Next steps:"
echo "1. Push the updated images to ECR"
echo "2. Update ECS services to use new images"
echo "3. Test the services in browser"