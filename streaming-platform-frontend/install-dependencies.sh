#!/bin/bash

# Install dependencies for streaming platform frontend
echo "🚀 Installing dependencies for streaming platform frontend..."

# Install root dependencies
echo "📦 Installing root dependencies..."
npm install

# Install dependencies for each package
echo "📦 Installing package dependencies..."

# Shared package
cd packages/shared && npm install && cd ../..

# UI package  
cd packages/ui && npm install && cd ../..

# Auth package
cd packages/auth && npm install && cd ../..

# Viewer portal
cd packages/viewer-portal && npm install && cd ../..

# Creator dashboard
cd packages/creator-dashboard && npm install && cd ../..

# Admin portal
cd packages/admin-portal && npm install && cd ../..

# Support system
cd packages/support-system && npm install && cd ../..

# Analytics dashboard
cd packages/analytics-dashboard && npm install && cd ../..

# Developer console
cd packages/developer-console && npm install && cd ../..

echo "✅ All dependencies installed successfully!"
echo "🎯 Run 'npm run dev' to start all applications in development mode"