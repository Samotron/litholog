# Litholog

A geological description parser for BS5930 standard descriptions, built in Zig with language bindings for Go and Python.

[![CI/CD Pipeline](https://github.com/samotron/litholog/actions/workflows/ci.yml/badge.svg)](https://github.com/samotron/litholog/actions/workflows/ci.yml)
[![Go Reference](https://pkg.go.dev/badge/github.com/samotron/litholog/bindings/go.svg)](https://pkg.go.dev/github.com/samotron/litholog/bindings/go)
[![PyPI version](https://badge.fury.io/py/litholog.svg)](https://badge.fury.io/py/litholog)

## Overview

Litholog is a fast, accurate parser for geological descriptions following the BS5930 standard. It can parse complex soil and rock descriptions and extract structured information including:

- Material type (soil/rock)
- Consistency, density, and strength properties
- Primary and secondary constituents
- Weathering grades and rock structures
- Quantitative strength parameters

## Quick Start

### CLI Tool

```bash
# Download and install the CLI
curl -L https://github.com/samotron/litholog/releases/latest/download/litholog-linux-x86_64 -o litholog
chmod +x litholog
sudo mv litholog /usr/local/bin/

# Parse a description
litholog "Firm CLAY"
litholog "Strong slightly weathered LIMESTONE"
litholog "Firm to stiff slightly sandy gravelly CLAY"
```

### Go Library

```bash
go get github.com/samotron/litholog/bindings/go
```

```go
import "github.com/samotron/litholog/bindings/go"

desc, _ := litholog.Parse("Firm CLAY")
fmt.Printf("Material: %s, Type: %s\n", 
    desc.MaterialType.String(), 
    desc.PrimarySoilType.String())
```

### Python Library

```bash
pip install litholog
```

```python
import litholog

desc = litholog.parse("Firm CLAY")
print(f"Material: {desc.material_type.name}")
print(f"Type: {desc.primary_soil_type.name}")
```

## Features

### Supported Descriptions

- **Soil types**: Clay, silt, sand, gravel, peat, organic materials
- **Rock types**: Limestone, sandstone, mudstone, granite, basalt, and more
- **Consistency**: Very soft to hard (for soils)
- **Density**: Very loose to very dense (for granular soils)
- **Rock strength**: Very weak to extremely strong
- **Weathering**: Fresh to completely weathered
- **Secondary constituents**: Slightly/moderately/very sandy, silty, etc.
- **Strength parameters**: UCS, undrained shear strength, SPT N-values, friction angles

### Example Parseable Descriptions

```
Firm CLAY
Dense SAND
Strong LIMESTONE
Firm to stiff slightly sandy gravelly CLAY
Moderately strong slightly weathered jointed SANDSTONE
Weak highly weathered MUDSTONE
Very dense slightly silty fine to coarse SAND
```

## Installation

### From Releases (Recommended)

Download pre-built binaries from the [releases page](https://github.com/samotron/litholog/releases):

- **Linux**: `litholog-linux-x86_64`, `litholog-linux-aarch64`
- **macOS**: `litholog-macos-x86_64`, `litholog-macos-aarch64`
- **Windows**: `litholog-windows-x86_64.exe`

### From Source

Requirements:
- [Zig](https://ziglang.org/) 0.12.0 or later

```bash
git clone https://github.com/samotron/litholog.git
cd litholog
zig build
```

## Language Bindings

### Go Bindings

Full CGO-based bindings with type safety and automatic memory management.

```bash
go get github.com/samotron/litholog/bindings/go
```

See [Go bindings documentation](bindings/go/README.md) for detailed usage.

### Python Bindings

ctypes-based bindings with comprehensive enum support.

```bash
pip install litholog
```

See [Python bindings documentation](bindings/python/README.md) for detailed usage.

## CLI Usage

```bash
# Basic parsing
litholog "Firm CLAY"

# JSON output
litholog --json "Dense SAND"

# Batch processing
litholog --file descriptions.txt

# Interactive mode
litholog --interactive

# Help
litholog --help
```

### CLI Options

- `--json, -j`: Output results in JSON format
- `--file, -f`: Process descriptions from a file
- `--interactive, -i`: Interactive mode for multiple descriptions
- `--confidence, -c`: Show confidence scores
- `--help, -h`: Show help information
- `--version, -v`: Show version information

## API Reference

### Core Types

All language bindings expose these core types:

- `MaterialType`: Soil, Rock
- `Consistency`: Very soft, soft, firm, stiff, very stiff, hard
- `Density`: Very loose, loose, medium dense, dense, very dense
- `SoilType`: Clay, silt, sand, gravel, peat, organic
- `RockType`: Limestone, sandstone, mudstone, shale, granite, etc.
- `RockStrength`: Very weak to extremely strong
- `WeatheringGrade`: Fresh to completely weathered
- `RockStructure`: Massive, bedded, jointed, fractured, etc.

### Output Format

All parsers return structured data including:

```json
{
  "raw_description": "Firm CLAY",
  "material_type": "soil",
  "consistency": "firm",
  "primary_soil_type": "clay",
  "strength_parameter_type": "undrained_shear_strength",
  "strength_lower_bound": 25.0,
  "strength_upper_bound": 50.0,
  "strength_typical_value": 37.5,
  "confidence": 0.95
}
```

## Development

### Building

```bash
# Build CLI
zig build

# Build library
zig build lib

# Run tests
zig build test

# Build all bindings
zig build lib
cp zig-out/lib/* bindings/go/
cp zig-out/lib/* bindings/python/litholog/lib/
```

### Testing

```bash
# Core library tests
zig build test

# Go binding tests
cd bindings/go && go test

# Python binding tests
cd bindings/python && python -m pytest
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Release Process

Releases are automated via GitHub Actions:

1. **Tag a release**: `git tag v1.0.0 && git push --tags`
2. **CLI binaries** are built for all platforms and attached to the release
3. **Go module** is tagged and published automatically
4. **Python package** is built and published to PyPI

### Manual Release

```bash
# Create and push a tag
git tag v1.0.0
git push origin v1.0.0

# This triggers GitHub Actions to:
# - Build CLI binaries for all platforms
# - Publish Go module
# - Publish Python package to PyPI
```

## Architecture

```
litholog/
├── src/                    # Core Zig library
│   ├── parser/            # BS5930 parser implementation
│   ├── cli.zig           # CLI interface
│   ├── lib.zig           # C-compatible library interface
│   └── main.zig          # CLI entry point
├── include/
│   └── litholog.h        # C header for bindings
├── bindings/
│   ├── go/               # Go bindings (CGO)
│   └── python/           # Python bindings (ctypes)
├── .github/workflows/    # CI/CD automation
└── docs/                 # Documentation
```

## Performance

- **Parsing speed**: ~1M descriptions/second
- **Memory usage**: <10MB for typical workloads
- **Binary size**: <2MB (statically linked)
- **Startup time**: <10ms

## Standards Compliance

This parser implements parsing rules based on:

- **BS 5930:2015** - Code of practice for ground investigations
- **Eurocode 7** - Geotechnical design standards
- **Industry best practices** for geological description

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- 📖 [Documentation](https://github.com/samotron/litholog/wiki)
- 🐛 [Issue Tracker](https://github.com/samotron/litholog/issues)
- 💬 [Discussions](https://github.com/samotron/litholog/discussions)

## Acknowledgments

- BS 5930 standard for geological description formats
- Zig community for excellent tooling
- Contributors and users providing feedback and improvements