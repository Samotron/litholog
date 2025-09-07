# Litholog Go Bindings

Go language bindings for the litholog geological description parser.

## Installation

```bash
go get github.com/samotron/litholog/bindings/go
```

## Prerequisites

- Go 1.21 or later
- CGO enabled
- C compiler (gcc, clang, or MSVC)
- The litholog C library (automatically built during installation)

## Usage

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
        fmt.Printf("Material Type: %s\n", desc.MaterialType.String())
        
        if desc.Consistency != nil {
            fmt.Printf("Consistency: %s\n", desc.Consistency.String())
        }
        
        if desc.PrimarySoilType != nil {
            fmt.Printf("Soil Type: %s\n", desc.PrimarySoilType.String())
        }
        
        if desc.StrengthParameters != nil {
            sp := desc.StrengthParameters
            fmt.Printf("Strength: %s (%.1f-%.1f)\n", 
                sp.ParameterType.String(),
                sp.ValueRange.LowerBound,
                sp.ValueRange.UpperBound)
        }
        
        fmt.Printf("Confidence: %.2f\n", desc.Confidence)
        
        // Convert to JSON
        jsonStr := desc.ToJSON()
        fmt.Printf("JSON: %s\n", jsonStr)
    }
}
```

## API Reference

### Types

#### Enums

- `MaterialType` - Soil or Rock
- `Consistency` - Soil consistency (very soft to hard)
- `Density` - Soil density (very loose to very dense)
- `RockStrength` - Rock strength (very weak to extremely strong)
- `SoilType` - Primary soil types (clay, silt, sand, gravel, peat, organic)
- `RockType` - Primary rock types (limestone, sandstone, etc.)
- `WeatheringGrade` - Rock weathering grade
- `RockStructure` - Rock structure
- `StrengthParameterType` - Type of strength parameter

#### Structs

```go
type SoilDescription struct {
    RawDescription           string
    MaterialType             MaterialType
    Consistency              *Consistency
    Density                  *Density
    PrimarySoilType          *SoilType
    RockStrength             *RockStrength
    WeatheringGrade          *WeatheringGrade
    RockStructure            *RockStructure
    PrimaryRockType          *RockType
    SecondaryConstituents    []SecondaryConstituent
    StrengthParameters       *StrengthParameters
    Confidence               float64
}

type SecondaryConstituent struct {
    Amount   string
    SoilType string
}

type StrengthParameters struct {
    ParameterType StrengthParameterType
    ValueRange    StrengthValueRange
    Confidence    float64
}

type StrengthValueRange struct {
    LowerBound   float64
    UpperBound   float64
    TypicalValue float64
    HasTypical   bool
}
```

### Functions

```go
// Parse a geological description string
func Parse(description string) (*SoilDescription, error)
```

### Methods

```go
// Convert description to JSON
func (d *SoilDescription) ToJSON() string
```

## Examples

### Basic Parsing

```go
desc, _ := litholog.Parse("Dense SAND")
if desc != nil {
    fmt.Printf("Material: %s, Density: %s, Type: %s\n",
        desc.MaterialType.String(),
        desc.Density.String(),
        desc.PrimarySoilType.String())
}
```

### Rock Description

```go
desc, _ := litholog.Parse("Strong slightly weathered LIMESTONE")
if desc != nil {
    fmt.Printf("Rock: %s, Strength: %s, Weathering: %s\n",
        desc.PrimaryRockType.String(),
        desc.RockStrength.String(),
        desc.WeatheringGrade.String())
}
```

### Complex Soil

```go
desc, _ := litholog.Parse("Firm to stiff slightly sandy gravelly CLAY")
if desc != nil {
    fmt.Printf("Primary: %s %s\n", 
        desc.Consistency.String(), 
        desc.PrimarySoilType.String())
    
    for _, sc := range desc.SecondaryConstituents {
        fmt.Printf("Secondary: %s %s\n", sc.Amount, sc.SoilType)
    }
}
```

## Building from Source

If you need to build the C library yourself:

```bash
# Clone the repository
git clone https://github.com/samotron/litholog.git
cd litholog

# Build the C library
zig build lib

# Copy files to Go bindings
cp zig-out/lib/liblitholog.so bindings/go/
cp zig-out/include/litholog.h bindings/go/

# Test the bindings
cd bindings/go
go test -v
```

## Error Handling

The `Parse` function returns `(result, error)`. Check for errors:

```go
desc, err := litholog.Parse("Invalid description")
if err != nil {
    log.Printf("Parse error: %v", err)
    return
}

if desc == nil {
    log.Println("Failed to parse description")
    return
}
```

## Memory Management

Memory is automatically managed through Go's garbage collector and CGO finalizers. You don't need to manually free resources.

## Platform Support

- Linux (x86_64, ARM64)
- macOS (Intel, Apple Silicon)  
- Windows (x86_64)

## License

This package follows the same license as the main litholog project.