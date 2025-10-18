#!/bin/bash

# Build Lambda layer with correct structure
set -e

echo "🔧 Building Lambda layer with dependencies..."

# Clean up previous builds
rm -rf /tmp/lambda-layer
rm -f modules/lambda/layers/shared-dependencies.zip

# Create proper layer structure
mkdir -p /tmp/lambda-layer/python

# Install dependencies to the correct location
pip install -r modules/lambda/layers/python/requirements.txt -t /tmp/lambda-layer/python --no-deps --force-reinstall

echo "📦 Installed packages:"
ls -la /tmp/lambda-layer/python/

# Create the layer zip
cd /tmp/lambda-layer
zip -r shared-dependencies.zip python/

# Move back to original directory and copy the zip
cd -
cp /tmp/lambda-layer/shared-dependencies.zip modules/lambda/layers/

echo "✅ Layer built successfully!"
echo "📊 Layer size: $(du -h modules/lambda/layers/shared-dependencies.zip)"

# Verify the structure
echo "🔍 Layer structure:"
unzip -l modules/lambda/layers/shared-dependencies.zip | head -10