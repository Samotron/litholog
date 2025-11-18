# Example Application

This is a simple example showing how to use litholog in your Go project.

## Quick Start

### Option 1: Run from this directory

```bash
# Make sure the library is built
cd ..
zig build lib

# Set library path and run
export CGO_LDFLAGS="-L$(pwd)/zig-out/lib -llitholog"
export LD_LIBRARY_PATH=$(pwd)/zig-out/lib:$LD_LIBRARY_PATH

cd example-app
go run main.go
```

### Option 2: Install system-wide (Linux/macOS)

```bash
# Build and install library
cd ..
zig build lib
sudo cp zig-out/lib/liblitholog.so /usr/local/lib/  # or .dylib on macOS
sudo cp zig-out/include/litholog.h /usr/local/include/
sudo ldconfig  # Linux only

# Run the example
cd example-app
go run main.go
```

## Using in Your Own Project

### 1. Create a new project

```bash
mkdir my-geology-app
cd my-geology-app
go mod init my-geology-app
```

### 2. Add litholog dependency

```bash
# For local development (if you cloned the repo)
go mod edit -replace github.com/samotron/litholog/bindings/go=/path/to/litholog/bindings/go
go get github.com/samotron/litholog/bindings/go

# For published version
go get github.com/samotron/litholog/bindings/go
```

### 3. Write your code

```go
package main

import (
    "fmt"
    "github.com/samotron/litholog/bindings/go"
)

func main() {
    desc, _ := litholog.Parse("Firm CLAY")
    if desc != nil {
        fmt.Printf("Parsed: %s\n", desc.MaterialType.String())
    }
}
```

### 4. Build and run

```bash
# If library is installed system-wide
go build && ./my-geology-app

# If using local library
export CGO_LDFLAGS="-L/path/to/litholog/zig-out/lib -llitholog"
export LD_LIBRARY_PATH=/path/to/litholog/zig-out/lib:$LD_LIBRARY_PATH
go build && ./my-geology-app
```

## Examples in This File

The `main.go` demonstrates:

1. **Simple Parsing** - Parse a single description
2. **Batch Parsing** - Parse multiple descriptions efficiently
3. **Builder Pattern** - Construct descriptions programmatically
4. **Validation** - Validate descriptions before parsing

## Troubleshooting

### Error: "cannot find package"

Make sure you've run `go mod tidy` and the replace directive points to the correct path.

### Error: "undefined reference to litholog_parse"

The C library isn't found. Set the CGO flags:

```bash
export CGO_LDFLAGS="-L/path/to/lib -llitholog"
export LD_LIBRARY_PATH=/path/to/lib:$LD_LIBRARY_PATH
```

### Error: CGO is disabled

Enable CGO:

```bash
export CGO_ENABLED=1
go build
```

## More Examples

Check out the examples directory for more comprehensive demos:

```bash
cd ../bindings/go/examples/basic
go run main.go
```

See [USAGE.md](../bindings/go/USAGE.md) for complete documentation.
