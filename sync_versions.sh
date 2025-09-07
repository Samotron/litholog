#!/bin/bash

# Sync all binding versions with Zig source version

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔄 Syncing all package versions with Zig source..."

# Extract version from Zig
VERSION_FILE="$SCRIPT_DIR/src/version.zig"
if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ Version file not found: $VERSION_FILE"
    exit 1
fi

VERSION=$(grep 'VERSION_STRING' "$VERSION_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

if [ -z "$VERSION" ]; then
    echo "❌ Could not extract version from Zig source"
    exit 1
fi

echo "📦 Zig version: $VERSION"

# Sync Python version
echo "🐍 Syncing Python version..."
cd "$SCRIPT_DIR/bindings/python"
python sync_version.py
echo "✅ Python version synced"

# Sync Go version  
echo "🐹 Syncing Go version..."
cd "$SCRIPT_DIR/bindings/go"
./sync_version.sh
echo "✅ Go version synced"

# Generate VERSION file for CI/CD
echo "$VERSION" > "$SCRIPT_DIR/VERSION"
echo "📝 Created VERSION file: $VERSION"

echo "🎉 All versions synced successfully to $VERSION"