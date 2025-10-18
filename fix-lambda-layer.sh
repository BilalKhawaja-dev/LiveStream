#!/bin/bash

# Fix Lambda layer with correct structure for Python runtime
set -e

echo "🔧 Fixing Lambda layer structure..."

# Clean up
rm -rf /tmp/lambda-layer-fixed
rm -f modules/lambda/layers/shared-dependencies.zip

# Create the correct structure for Lambda layers
# For Python, packages should be in python/lib/python3.x/site-packages/ OR just python/
mkdir -p /tmp/lambda-layer-fixed/python

# Install dependencies directly to the python directory
pip install -r modules/lambda/layers/python/requirements.txt -t /tmp/lambda-layer-fixed/python --no-deps --force-reinstall

echo "📦 Installed packages:"
ls -la /tmp/lambda-layer-fixed/python/ | head -10

# Verify JWT is there
if [ -d "/tmp/lambda-layer-fixed/python/jwt" ]; then
    echo "✅ JWT package found in layer"
else
    echo "❌ JWT package NOT found in layer"
    exit 1
fi

# Create the layer zip
cd /tmp/lambda-layer-fixed
zip -r shared-dependencies.zip python/

# Move back to original directory and copy the zip
cd -
cp /tmp/lambda-layer-fixed/shared-dependencies.zip modules/lambda/layers/

echo "✅ Layer fixed successfully!"
echo "📊 Layer size: $(du -h modules/lambda/layers/shared-dependencies.zip)"

# Verify the structure
echo "🔍 Layer structure:"
unzip -l modules/lambda/layers/shared-dependencies.zip | grep "python/jwt" | head -5