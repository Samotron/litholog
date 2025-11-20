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

**Key Features:**
- 🚀 High-performance parsing (~1M descriptions/second)
- 🖥️ Web-based GUI (double-click to launch on Windows)
- 📊 CSV/Excel file processing with configurable output columns
- 🏗️ Geological unit identification across multiple boreholes
- 🔍 Intelligent spelling correction for common typos
- 🎯 Confidence scoring and validation
- 🌐 Cross-platform CLI and language bindings for Go and Python
- 📝 BS 5930 compliant output

## Quick Start

### Web Interface (GUI)

**Easiest way to get started:**

1. Download the executable for your platform from [releases](https://github.com/samotron/litholog/releases)
2. **Double-click the executable** to launch the web interface
3. Your browser will open automatically at `http://localhost:8080`

Or launch manually:
```bash
litholog web    # Starts web server at http://localhost:8080
litholog gui    # Alternative command
```

The web interface provides:
- **Single description parsing** with live results and confidence scores
- **Batch processing** with JSON export for multiple descriptions
- **CSV upload/download** - upload your CSV files, select the description column, and download results with parsed data appended
- **Modern, clean UI** with gradient design and responsive layout
- Works on any device - desktop, tablet, or mobile
- No installation or configuration needed - 100% local processing

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

### Intelligent Spelling Correction

Litholog includes robust spelling correction to handle common typos and data entry errors:

- **Automatic correction**: Common misspellings are automatically corrected
  - "Firn" → "firm"
  - "stif" → "stiff"  
  - "CLAI" → "clay"
  - "limstone" → "limestone"
- **Typo dictionary**: Fast-path lookup for ~80+ common typos
- **Fuzzy matching**: Levenshtein distance-based matching for unknown typos (80% similarity threshold)
- **Anomaly reporting**: All corrections are tracked and reported
- **Performance optimized**: Corrections add minimal overhead (~5% slower than exact matching)

Example with typos:
```bash
litholog "Firn CLAI"           # ✓ Corrects to: Firm CLAY
litholog "Stif brown SNAD"      # ✓ Corrects to: Stiff brown SAND
litholog "Strong LIMSTONE"      # ✓ Corrects to: Strong LIMESTONE
```

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

## Usage Modes

Litholog offers multiple interfaces to suit your workflow:

### Web Interface

```bash
# Launch web UI (auto-opens browser)
litholog web

# Alternative command
litholog gui

# Or simply double-click the executable (no terminal needed)
```

Access at `http://localhost:8080` with features:
- Interactive single description parsing
- Batch processing with downloadable JSON results
- Clean, modern interface
- No dependencies or configuration required

### CLI Usage

```bash
# Basic parsing
litholog "Firm CLAY"

# JSON output
litholog --mode compact "Dense SAND"

# Batch processing
litholog --file descriptions.txt

# CSV/Excel file processing
litholog --csv input.csv --csv-output output.csv \
         --column "Description" \
         --output-columns "material_type,consistency,primary_soil_type,confidence"

# Interactive terminal UI
litholog tui

# Help
litholog --help
```

### CSV/Excel Processing

Litholog can process CSV files (or Excel files saved as CSV) with geological descriptions and append parsed results as new columns:

```bash
# Process CSV with header row
litholog --csv data.csv --csv-output results.csv \
         --column "Soil_Description" \
         --output-columns "material_type,consistency,primary_soil_type,density,confidence"

# Use column index (0-based) instead of name
litholog --csv data.csv --csv-output results.csv \
         --column 2 \
         --output-columns "material_type,json"

# Process CSV without header row
litholog --csv data.csv --csv-output results.csv \
         --column 0 --csv-no-header \
         --output-columns "primary_soil_type,strength_typical,strength_unit"
```

**Available output columns:**
- `material_type` - Soil or rock classification
- `consistency` - Consistency (very soft to hard)
- `density` - Density (very loose to very dense)
- `primary_soil_type` - Primary soil type (clay, silt, sand, gravel)
- `primary_rock_type` - Primary rock type (limestone, sandstone, etc.)
- `rock_strength` - Rock strength (very weak to extremely strong)
- `weathering_grade` - Weathering grade (fresh to completely weathered)
- `color` - Color description
- `moisture_content` - Moisture content description
- `confidence` - Confidence score (0-1)
- `is_valid` - Validation status (true/false)
- `strength_lower` - Lower bound of strength parameter
- `strength_upper` - Upper bound of strength parameter
- `strength_typical` - Typical strength value
- `strength_unit` - Unit of strength measurement
- `json` - Full JSON output

**Example CSV input:**
```csv
ID,Depth,Description,Notes
1,1.0,Firm CLAY,Sample 1
2,2.5,Dense SAND,Sample 2
3,3.0,Strong LIMESTONE,Sample 3
```

**Command:**
```bash
litholog --csv input.csv --csv-output output.csv \
         --column "Description" \
         --output-columns "material_type,consistency,primary_soil_type,confidence"
```

**Output:**
```csv
ID,Depth,Description,Notes,material_type,consistency,primary_soil_type,confidence
1,1.0,Firm CLAY,Sample 1,soil,firm,CLAY,1.000
2,2.5,Dense SAND,Sample 2,soil,,SAND,1.000
3,3.0,Strong LIMESTONE,Sample 3,rock,,,1.000
```

### Geological Unit Identification

Litholog can automatically identify geological units across multiple boreholes by clustering similar descriptions and analyzing their spatial distribution:

```bash
# Identify units from borehole logs
litholog --csv boreholes.csv --csv-output results.csv \
         --column "Description" \
         --identify-units \
         --borehole-id "BH_ID" \
         --depth-top "Depth_Top" \
         --depth-bottom "Depth_Bottom"
```

This will:
- **Cluster similar descriptions** into geological units (UNIT 1, UNIT 2, etc.)
- **Generate a summary table** showing unit characteristics, depth ranges, and occurrence
- **Add a unit_id column** to the output CSV for correlation
- **Display typical descriptions** for each identified unit

**Example input:**
```csv
BH_ID,Depth_Top,Depth_Bottom,Description
BH01,0.0,1.5,Firm brown slightly sandy CLAY
BH01,1.5,3.0,Medium dense brown SAND and GRAVEL
BH02,0.0,1.2,Firm to stiff brown sandy CLAY
BH02,1.2,2.8,Dense brown SAND and GRAVEL
```

**Output summary:**
```
═══════════════════════════════════════════════════════════════════
                    GEOLOGICAL UNIT SUMMARY
═══════════════════════════════════════════════════════════════════
Total Boreholes: 2
Units Identified: 2

───────────────────────────────────────────────────────────────────
UNIT 1
───────────────────────────────────────────────────────────────────
Typical Description:  Medium dense brown SAND and GRAVEL
Material Type:        soil
Primary Soil Type:    SAND
Density:              medium dense

Depth Range (Top):    1.20m - 1.50m
Depth Range (Bottom): 2.80m - 3.00m
Average Thickness:    1.48m

Found in 2/2 boreholes (2 occurrences total)
Boreholes: BH01, BH02

───────────────────────────────────────────────────────────────────
UNIT 2
───────────────────────────────────────────────────────────────────
Typical Description:  Firm brown slightly sandy CLAY
Material Type:        soil
Primary Soil Type:    CLAY
Consistency:          firm

Depth Range (Top):    0.00m - 0.00m
Depth Range (Bottom): 1.20m - 1.50m
Average Thickness:    1.35m

Found in 2/2 boreholes (2 occurrences total)
Boreholes: BH01, BH02
═══════════════════════════════════════════════════════════════════
```

**Output CSV includes unit assignments:**
```csv
BH_ID,Depth_Top,Depth_Bottom,Description,unit_id
BH01,0.0,1.5,Firm brown slightly sandy CLAY,2
BH01,1.5,3.0,Medium dense brown SAND and GRAVEL,1
BH02,0.0,1.2,Firm to stiff brown sandy CLAY,2
BH02,1.2,2.8,Dense brown SAND and GRAVEL,1
```

The unit identification feature uses intelligent clustering based on:
- Material type (soil vs rock)
- Primary constituent similarity
- Consistency/density/strength compatibility
- Stratigraphic position (depth ordering)

### JSON Input/Output (Roundtrip)

Litholog can convert between text descriptions and JSON in both directions, enabling programmatic description generation and data transformation workflows:

```bash
# Parse description to JSON
litholog "Firm slightly sandy CLAY" --mode compact > description.json

# Generate description from JSON
litholog --from-json description.json
# Output: firm slightly sandy CLAY

# Different output formats
litholog --from-json description.json --json-format bs5930
litholog --from-json description.json --json-format verbose
litholog --from-json description.json --json-format concise

# From stdin (useful for piping)
echo '{"material_type":"soil","consistency":"firm","primary_soil_type":"clay"}' | litholog --from-json -

# Complete roundtrip
litholog "Dense SAND" --mode compact | litholog --from-json - --json-format bs5930
```

**JSON Input Format:**

Single description:
```json
{
  "material_type": "soil",
  "consistency": "firm",
  "primary_soil_type": "clay",
  "secondary_constituents": [
    {"amount": "slightly", "soil_type": "sandy"}
  ]
}
```

Multiple descriptions (array):
```json
[
  {"material_type": "soil", "consistency": "firm", "primary_soil_type": "clay"},
  {"material_type": "rock", "rock_strength": "strong", "primary_rock_type": "limestone"}
]
```

**Format Options:**
- `standard` - Default format with all details
- `concise` - Minimal format (just key properties)
- `verbose` - Includes color, moisture, and additional properties
- `bs5930` - BS 5930 compliant format

**Use Cases:**
- **Data transformation**: Convert JSON logs to readable descriptions
- **Template system**: Store description templates as JSON
- **API integration**: Easy integration with web services
- **Quality control**: Verify parsing accuracy with roundtrip tests
- **Programmatic generation**: Build descriptions from code


### CLI Options

- `-h, --help`: Show help information
- `-f, --file <FILE>`: Process descriptions from a file (one per line)
- `-m, --mode <MODE>`: Output format (compact, verbose, pretty, summary)
- `-C, --no-color`: Disable colorized output
- `-a, --check-anomalies`: Check for anomalies in descriptions
- `-g, --generate <MODE>`: Generate descriptions (random|variations)
- `-n, --count <N>`: Number of descriptions to generate
- `-s, --seed <SEED>`: Seed for random generation

**JSON Input Options:**
- `--from-json <FILE>`: Generate description from JSON file (use `-` for stdin)
- `--json-format <FORMAT>`: Output format (standard|concise|verbose|bs5930)

**CSV Options:**
- `--csv <FILE>`: Input CSV file to process
- `--csv-output <FILE>`: Output CSV file with results
- `--column <NAME|INDEX>`: Column name (or 0-based index) containing descriptions
- `--output-columns <COLS>`: Comma-separated list of result columns to add
- `--csv-no-header`: Treat file as having no header row

**Unit Identification Options:**
- `--identify-units`: Identify geological units across boreholes
- `--borehole-id <COL>`: Column name (or index) for borehole ID
- `--depth-top <COL>`: Column name (or index) for depth top (m)
- `--depth-bottom <COL>`: Column name (or index) for depth bottom (m)

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
│   ├── csv_processor.zig # CSV/Excel file processing
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
- **CSV processing**: Handles files up to 100MB with thousands of rows efficiently

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