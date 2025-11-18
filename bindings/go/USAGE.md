# Using Litholog in Your Go Project

## Installation

### Option 1: Using Go Modules (Recommended)

```bash
go get github.com/samotron/litholog/bindings/go
```

### Option 2: Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/samotron/litholog.git
cd litholog
```

2. Build the C library:
```bash
zig build lib
```

3. Copy the library files to your system:
```bash
# Linux
sudo cp zig-out/lib/liblitholog.so /usr/local/lib/
sudo cp zig-out/include/litholog.h /usr/local/include/
sudo ldconfig

# macOS
sudo cp zig-out/lib/liblitholog.dylib /usr/local/lib/
sudo cp zig-out/include/litholog.h /usr/local/include/

# Windows
# Copy liblitholog.dll to C:\Windows\System32 or add to PATH
```

## Prerequisites

### Required
- Go 1.21 or later
- CGO enabled (`CGO_ENABLED=1`)
- C compiler (gcc, clang, or MSVC)

### Verify CGO is enabled:
```bash
go env CGO_ENABLED
# Should output: 1
```

## Quick Start

### 1. Create a new Go project

```bash
mkdir my-geology-project
cd my-geology-project
go mod init my-geology-project
```

### 2. Import litholog

```go
package main

import (
    "fmt"
    "log"
    
    "github.com/samotron/litholog/bindings/go"
)

func main() {
    // Parse a geological description
    desc, err := litholog.Parse("Firm CLAY")
    if err != nil {
        log.Fatal(err)
    }
    
    if desc != nil {
        fmt.Printf("Material: %s\n", desc.MaterialType.String())
        fmt.Printf("Consistency: %s\n", desc.Consistency.String())
        fmt.Printf("Soil Type: %s\n", desc.PrimarySoilType.String())
        fmt.Printf("Confidence: %.2f\n", desc.Confidence)
    }
}
```

### 3. Build and run

```bash
go mod tidy
go build
./my-geology-project
```

## Common Usage Patterns

### Basic Parsing

```go
package main

import (
    "fmt"
    "github.com/samotron/litholog/bindings/go"
)

func main() {
    descriptions := []string{
        "Firm CLAY",
        "Dense SAND",
        "Strong LIMESTONE",
    }
    
    for _, desc := range descriptions {
        result, _ := litholog.Parse(desc)
        if result != nil {
            fmt.Printf("%s -> %s\n", desc, result.MaterialType.String())
        }
    }
}
```

### Batch Processing

```go
package main

import (
    "fmt"
    "github.com/samotron/litholog/bindings/go"
)

func main() {
    descriptions := []string{
        "Firm CLAY",
        "Dense SAND",
        "Strong LIMESTONE",
        "Stiff CLAY",
        "Medium dense GRAVEL",
    }
    
    // Parse all at once
    results := litholog.ParseBatch(descriptions)
    
    fmt.Printf("Parsed %d descriptions\n", len(results))
    for i, result := range results {
        if result != nil {
            fmt.Printf("%d. %s (Confidence: %.2f)\n", 
                i+1, result.RawDescription, result.Confidence)
        }
    }
}
```

### Using the Builder Pattern

```go
package main

import (
    "fmt"
    "github.com/samotron/litholog/bindings/go"
)

func main() {
    // Build a description programmatically
    builder := litholog.NewSoilBuilder(litholog.SoilTypeClay).
        WithConsistency(litholog.ConsistencyFirm).
        WithSecondaryConstituent("slightly", "sandy")
    
    description := builder.Build()
    fmt.Printf("Built: %s\n", description)
    
    // Parse it
    result, _ := builder.BuildAndParse()
    if result != nil {
        fmt.Printf("Parsed: %s\n", result.ToJSON())
    }
}
```

### Validation

```go
package main

import (
    "fmt"
    "github.com/samotron/litholog/bindings/go"
)

func main() {
    descriptions := []string{
        "Firm CLAY",
        "",  // Invalid
        "Dense SAND",
    }
    
    for _, desc := range descriptions {
        result := litholog.Validate(desc)
        
        if result.Valid {
            fmt.Printf("✓ %s is valid\n", desc)
        } else {
            fmt.Printf("✗ %s is invalid:\n", desc)
            for _, err := range result.Errors {
                fmt.Printf("  - %s\n", err.Error())
            }
        }
    }
}
```

### Streaming (Large Files)

```go
package main

import (
    "fmt"
    "sync"
    "github.com/samotron/litholog/bindings/go"
)

func main() {
    // Simulate large dataset
    descriptions := make([]string, 1000)
    for i := 0; i < 1000; i++ {
        descriptions[i] = "Firm CLAY"
    }
    
    var mu sync.Mutex
    successCount := 0
    
    worker := func(desc *litholog.SoilDescription, err error) {
        mu.Lock()
        defer mu.Unlock()
        
        if desc != nil {
            successCount++
        }
    }
    
    processor := litholog.NewStreamProcessor(50, worker)
    processor.ProcessDescriptions(descriptions)
    
    fmt.Printf("Processed %d descriptions\n", successCount)
}
```

## Project Structure

Your project should look like this:

```
my-geology-project/
├── go.mod
├── go.sum
├── main.go
└── README.md
```

## go.mod Example

```go
module my-geology-project

go 1.21

require github.com/samotron/litholog/bindings/go v0.0.4
```

## Troubleshooting

### Issue: "undefined reference to litholog_parse"

**Solution:** Ensure the C library is installed and CGO can find it:

```bash
# Linux
export CGO_LDFLAGS="-L/usr/local/lib -llitholog"
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# macOS
export CGO_LDFLAGS="-L/usr/local/lib -llitholog"
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH

# Or specify in your code:
// #cgo LDFLAGS: -L/path/to/lib -llitholog
```

### Issue: "CGO_ENABLED=0"

**Solution:** Enable CGO:

```bash
export CGO_ENABLED=1
go build
```

### Issue: "cannot find -llitholog"

**Solution:** The library path is not in your linker's search path:

```bash
# Add library path
export CGO_LDFLAGS="-L/path/to/litholog/zig-out/lib -llitholog"

# Or use local library
cd litholog
zig build lib
export CGO_LDFLAGS="-L$(pwd)/zig-out/lib -llitholog"
export LD_LIBRARY_PATH=$(pwd)/zig-out/lib:$LD_LIBRARY_PATH
```

### Issue: Library not found at runtime

**Solution:** Ensure the shared library is in your system's library path:

```bash
# Linux
sudo cp zig-out/lib/liblitholog.so /usr/local/lib/
sudo ldconfig

# macOS
sudo cp zig-out/lib/liblitholog.dylib /usr/local/lib/
sudo update_dyld_shared_cache

# Or use RPATH
go build -ldflags="-r /usr/local/lib"
```

## Building for Production

### Static Linking

To avoid runtime library dependencies:

```bash
# Build with static linking
CGO_ENABLED=1 go build -ldflags="-linkmode external -extldflags '-static'"
```

### Docker Example

```dockerfile
FROM golang:1.21 as builder

# Install Zig
RUN wget https://ziglang.org/download/0.12.0/zig-linux-x86_64-0.12.0.tar.xz
RUN tar -xf zig-linux-x86_64-0.12.0.tar.xz
ENV PATH="/zig-linux-x86_64-0.12.0:${PATH}"

# Clone and build litholog
WORKDIR /litholog
RUN git clone https://github.com/samotron/litholog.git .
RUN zig build lib
RUN cp zig-out/lib/liblitholog.so /usr/local/lib/
RUN cp zig-out/include/litholog.h /usr/local/include/
RUN ldconfig

# Build your app
WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=1 go build -o myapp

FROM debian:bookworm-slim
COPY --from=builder /usr/local/lib/liblitholog.so /usr/local/lib/
COPY --from=builder /app/myapp /myapp
RUN ldconfig
CMD ["/myapp"]
```

## Testing Your Integration

Create a test file `main_test.go`:

```go
package main

import (
    "testing"
    "github.com/samotron/litholog/bindings/go"
)

func TestParsing(t *testing.T) {
    desc, err := litholog.Parse("Firm CLAY")
    if err != nil {
        t.Fatalf("Parse failed: %v", err)
    }
    
    if desc == nil {
        t.Fatal("Expected description, got nil")
    }
    
    if desc.MaterialType != litholog.MaterialTypeSoil {
        t.Errorf("Expected soil, got %v", desc.MaterialType)
    }
}

func BenchmarkParsing(b *testing.B) {
    for i := 0; i < b.N; i++ {
        litholog.Parse("Firm CLAY")
    }
}
```

Run tests:
```bash
go test -v
go test -bench=.
```

## Performance Tips

1. **Use Batch Parsing** for multiple descriptions
2. **Use Streaming** for large datasets (>1000 items)
3. **Reuse SoilDescription** objects where possible
4. **Enable compiler optimizations** in production builds
5. **Profile your application** to identify bottlenecks

## Example Applications

Check out the examples directory for complete working examples:

```bash
cd litholog/bindings/go/examples

# Basic parsing
cd basic && go run main.go

# Batch processing
cd batch && go run main.go

# Builder pattern
cd builder && go run main.go

# Validation
cd validation && go run main.go

# Streaming
cd streaming && go run main.go
```

## API Documentation

For complete API documentation, see:
- [Go bindings README](https://github.com/samotron/litholog/blob/main/bindings/go/README.md)
- [Main README](https://github.com/samotron/litholog/blob/main/README.md)
- [Feature Summary](https://github.com/samotron/litholog/blob/main/FEATURE_SUMMARY.md)

## Support

- 📖 [Documentation](https://github.com/samotron/litholog/wiki)
- 🐛 [Issue Tracker](https://github.com/samotron/litholog/issues)
- 💬 [Discussions](https://github.com/samotron/litholog/discussions)

## License

MIT License - see [LICENSE](https://github.com/samotron/litholog/blob/main/LICENSE) file for details.
