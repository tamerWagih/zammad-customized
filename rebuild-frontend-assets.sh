#!/bin/bash
# Script to rebuild frontend assets in Docker after CoffeeScript/JS changes

set -e

echo "🔄 Rebuilding Zammad frontend assets..."
echo ""

# Navigate to the correct directory
cd "$(dirname "$0")"

echo "📦 Step 1: Stopping and removing zammad-assets container..."
docker compose stop zammad-assets 2>/dev/null || true
docker compose rm -f zammad-assets 2>/dev/null || true

echo ""
echo "🗑️  Step 2: Removing old assets volume to force fresh build..."
docker volume rm zammad-customized_zammad-assets 2>/dev/null || echo "Volume doesn't exist or in use, continuing..."

echo ""
echo "🏗️  Step 3: Rebuilding zammad-assets container (this will take a few minutes)..."
docker compose build --no-cache zammad-assets

echo ""
echo "▶️  Step 4: Running asset precompilation..."
docker compose up zammad-assets

echo ""
echo "🔄 Step 5: Restarting services to pick up new assets..."
docker compose restart zammad-nginx zammad-railsserver zammad-websocket

echo ""
echo "✅ Frontend assets rebuilt successfully!"
echo ""
echo "📝 Note: Clear your browser cache (Ctrl+Shift+R) to see the changes"
echo ""

