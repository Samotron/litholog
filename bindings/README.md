# Litholog Language Bindings

This directory contains language bindings for the litholog geological description parser library.

## Available Bindings

### Go Bindings (`/bindings/go/`)

CGO-based bindings for Go applications.

**Installation:**
```bash
# First build the C library
zig build lib

# Copy library to Go binding directory  
cp zig-out/lib/liblitholog.so bindings/go/
cp zig-out/include/litholog.h bindings/go/

# Use in your Go project
cd bindings/go
go mod tidy
```

**Usage:**
```go
package main

import (
    "fmt"
    "log"
    "./litholog"
)

func main() {
    desc, err := litholog.Parse("Firm CLAY")
    if err != nil {
        log.Fatal(err)
    }
    
    if desc != nil {
        fmt.Printf("Material: %s\n", desc.MaterialType.String())
        if desc.Consistency != nil {
            fmt.Printf("Consistency: %s\n", desc.Consistency.String())
        }
        if desc.PrimarySoilType != nil {
            fmt.Printf("Soil Type: %s\n", desc.PrimarySoilType.String())
        }
    }
}
```

### Python Bindings (`/bindings/python/`)

ctypes-based bindings for Python applications.

**Installation:**
```bash
# First build the C library
zig build lib

# Copy library to Python binding directory
cp zig-out/lib/liblitholog.so bindings/python/

# Install Python package
cd bindings/python
pip install -e .
```

**Usage:**
```python
import litholog

# Parse a geological description
description = litholog.parse("Firm CLAY")

if description:
    print(f"Material Type: {description.material_type.name}")
    print(f"Consistency: {description.consistency.name}")
    print(f"Soil Type: {description.primary_soil_type.name}")
    print(f"Confidence: {description.confidence}")
    
    # Convert to JSON
    json_output = description.to_json()
    print(json_output)
```

## Building the C Library

The bindings require the litholog shared library. Build it using:

```bash
# From the project root directory
zig build lib
```

This will create:
- `zig-out/lib/liblitholog.so` (or `.dylib` on macOS, `.dll` on Windows)
- `zig-out/include/litholog.h`

## C API Reference

The C library exposes the following functions:

### Core Functions

```c
// Parse a geological description string
litholog_soil_description_t* litholog_parse(const char* description);

// Free memory allocated for a description
void litholog_free_description(litholog_soil_description_t* description);

// Convert description to JSON string
char* litholog_description_to_json(const litholog_soil_description_t* description);

// Free a string returned by the library
void litholog_free_string(char* str);
```

### Utility Functions

```c
// Convert enum values to string representations
const char* litholog_material_type_to_string(litholog_material_type_t type);
const char* litholog_consistency_to_string(litholog_consistency_t consistency);
const char* litholog_density_to_string(litholog_density_t density);
// ... and more
```

### Data Structures

The main structure returned by `litholog_parse()`:

```c
typedef struct {
    char* raw_description;
    litholog_material_type_t material_type;
    
    // Optional fields (< 0 if not set)
    int consistency;
    int density;
    int primary_soil_type;
    int rock_strength;
    int weathering_grade;
    int rock_structure;
    int primary_rock_type;
    
    // Secondary constituents array
    litholog_secondary_constituent_t* secondary_constituents;
    int secondary_constituents_count;
    
    // Strength parameters (null if not available)
    litholog_strength_parameters_t* strength_parameters;
    int has_strength_parameters;
    
    double confidence;
} litholog_soil_description_t;
```

## Examples

See the language-specific directories for complete examples:

- `bindings/go/example/` - Go usage examples
- `bindings/python/examples/` - Python usage examples

## Error Handling

- Go bindings return `(result, error)` tuples
- Python bindings return `None` on parse failure or raise exceptions for library loading issues
- C functions return `NULL` for failures

## Memory Management

- **Go**: Memory is automatically managed via finalizers
- **Python**: Memory is automatically managed via the library interface
- **C**: Use `litholog_free_description()` and `litholog_free_string()` to free allocated memory

## Platform Support

The bindings are tested on:
- Linux (x86_64, ARM64)
- macOS (x86_64, Apple Silicon)
- Windows (x86_64)

## Contributing

To add bindings for a new language:

1. Create a new directory under `bindings/`
2. Implement the C API interface using your language's FFI capabilities
3. Follow the same enum values and structure layouts as defined in `include/litholog.h`
4. Add documentation and examples
5. Update this README

## License

The bindings follow the same license as the main litholog project.