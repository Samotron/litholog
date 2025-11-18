#!/bin/bash
set -e

echo "Building litholog library..."

# Detect OS
OS=$(uname -s)
ARCH=$(uname -m)

# Navigate to project root
cd "$(dirname "$0")/.."

# Build the library
echo "Building with Zig..."
zig build lib

# Copy library to bindings/go directory
echo "Copying library files..."
if [ "$OS" = "Darwin" ]; then
    cp zig-out/lib/liblitholog.dylib bindings/go/
elif [ "$OS" = "Linux" ]; then
    cp zig-out/lib/liblitholog.so bindings/go/
else
    echo "Unsupported OS: $OS"
    exit 1
fi

cp zig-out/include/litholog.h bindings/go/

echo "Library built and copied to bindings/go/"
echo ""
echo "To use in your Go project:"
echo "  go get github.com/samotron/litholog/bindings/go"
echo ""
echo "Or for local development:"
echo "  export CGO_LDFLAGS=\"-L$(pwd)/bindings/go -llitholog\""
echo "  export LD_LIBRARY_PATH=$(pwd)/bindings/go:\$LD_LIBRARY_PATH"
