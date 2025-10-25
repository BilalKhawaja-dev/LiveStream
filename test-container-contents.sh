#!/bin/bash
# Test what's actually inside the Docker container

set -e

echo "🔍 Testing Container Contents"
echo "============================"

# Pull the latest image
echo "📥 Pulling latest viewer-portal image..."
docker pull 981686514879.dkr.ecr.eu-west-2.amazonaws.com/stream-dev:viewer-portal-latest

# Run container and check contents
echo "🐳 Starting container to inspect contents..."
CONTAINER_ID=$(docker run -d 981686514879.dkr.ecr.eu-west-2.amazonaws.com/stream-dev:viewer-portal-latest)

echo "📁 Checking nginx html directory contents..."
docker exec $CONTAINER_ID ls -la /usr/share/nginx/html/

echo "📁 Checking if assets directory exists..."
docker exec $CONTAINER_ID ls -la /usr/share/nginx/html/assets/ || echo "❌ Assets directory not found"

echo "📄 Checking index.html content..."
docker exec $CONTAINER_ID cat /usr/share/nginx/html/index.html

echo "🔧 Checking nginx config..."
docker exec $CONTAINER_ID cat /etc/nginx/conf.d/default.conf

echo "🧹 Cleaning up..."
docker stop $CONTAINER_ID
docker rm $CONTAINER_ID

echo "✅ Container inspection complete"