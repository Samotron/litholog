#!/bin/bash

# Extract version from Zig source and update Go package version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/../../src/version.zig"
GO_FILE="$SCRIPT_DIR/litholog.go"

# Extract version from Zig version.zig
if [ ! -f "$VERSION_FILE" ]; then
    echo "Version file not found: $VERSION_FILE"
    exit 1
fi

# Extract VERSION_STRING from Zig file
VERSION=$(grep 'VERSION_STRING' "$VERSION_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

if [ -z "$VERSION" ]; then
    echo "Could not extract version from Zig source"
    exit 1
fi

echo "Extracted Zig version: $VERSION"

# Create a version constant in Go
cat > "$SCRIPT_DIR/version.go" << EOF
package litholog

// Version information extracted from Zig source
const (
    Version = "$VERSION"
)

// GetVersion returns the library version
func GetVersion() string {
    return Version
}
EOF

echo "Created version.go with version $VERSION"

# Update Go bindings to include version function
if [ -f "$GO_FILE" ]; then
    echo "Go bindings file exists, version functions available via C library"
else
    echo "Warning: Go bindings file not found: $GO_FILE"
fi

echo "Go version successfully synced with Zig version"