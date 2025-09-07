# Litholog Python Bindings

Python bindings for the litholog geological description parser.

## Installation

### Prerequisites

1. Build the litholog C library first:
   ```bash
   cd ../..
   zig build lib
   ```

2. Copy the shared library to this directory:
   ```bash
   cp ../../zig-out/lib/liblitholog.so ./
   ```

### Install the Python package

```bash
pip install -e .
```

## Usage

```python
import litholog

# Parse a geological description
description = litholog.parse("Firm CLAY")

if description:
    print(f"Material Type: {description.material_type.name}")
    print(f"Consistency: {description.consistency.name}")
    print(f"Soil Type: {description.primary_soil_type.name}")
    print(f"Confidence: {description.confidence}")
```

## API Reference

### Main Functions

- `litholog.parse(description: str)` - Parse a geological description string
- `litholog.get_library(library_path: str)` - Get the library instance

### Classes

- `SoilDescription` - Represents a parsed geological description
- `LithologLibrary` - Interface to the C library
- Various enum classes for geological properties

## Examples

```python
import litholog

# Parse various types of descriptions
descriptions = [
    "Firm CLAY",
    "Dense SAND", 
    "Strong LIMESTONE",
    "Firm to stiff slightly sandy gravelly CLAY"
]

for desc in descriptions:
    result = litholog.parse(desc)
    if result:
        print(f"'{desc}' -> {result.material_type.name}")
```

## Development

Run tests:
```bash
python -m pytest tests/
```

Format code:
```bash
black litholog.py
```

Type checking:
```bash
mypy litholog.py
```