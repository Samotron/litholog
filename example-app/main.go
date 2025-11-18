package main

import (
	"fmt"
	"log"

	"github.com/samotron/litholog/bindings/go"
)

func main() {
	fmt.Println("Litholog Example Application")
	fmt.Println("============================\n")

	// Example 1: Simple parsing
	fmt.Println("1. Simple Parsing:")
	desc, err := litholog.Parse("Firm CLAY")
	if err != nil {
		log.Fatal(err)
	}

	if desc != nil {
		fmt.Printf("   Description: %s\n", desc.RawDescription)
		fmt.Printf("   Material: %s\n", desc.MaterialType.String())
		if desc.Consistency != nil {
			fmt.Printf("   Consistency: %s\n", desc.Consistency.String())
		}
		if desc.PrimarySoilType != nil {
			fmt.Printf("   Soil Type: %s\n", desc.PrimarySoilType.String())
		}
		fmt.Printf("   Confidence: %.2f\n\n", desc.Confidence)
	}

	// Example 2: Batch parsing
	fmt.Println("2. Batch Parsing:")
	descriptions := []string{
		"Firm CLAY",
		"Dense SAND",
		"Strong LIMESTONE",
	}

	results := litholog.ParseBatch(descriptions)
	for i, result := range results {
		if result != nil {
			fmt.Printf("   %d. %s -> %s (%.2f)\n",
				i+1, result.RawDescription,
				result.MaterialType.String(),
				result.Confidence)
		}
	}
	fmt.Println()

	// Example 3: Builder pattern
	fmt.Println("3. Builder Pattern:")
	builder := litholog.NewSoilBuilder(litholog.SoilTypeClay).
		WithConsistency(litholog.ConsistencyStiff)

	builtDesc := builder.Build()
	fmt.Printf("   Built: %s\n", builtDesc)

	parsed, _ := builder.BuildAndParse()
	if parsed != nil {
		fmt.Printf("   Confidence: %.2f\n\n", parsed.Confidence)
	}

	// Example 4: Validation
	fmt.Println("4. Validation:")
	testDescs := []string{"Firm CLAY", "", "Dense SAND"}

	for _, desc := range testDescs {
		result := litholog.Validate(desc)
		if result.Valid {
			fmt.Printf("   ✓ '%s' is valid\n", desc)
		} else {
			fmt.Printf("   ✗ '%s' is invalid\n", desc)
		}
	}

	fmt.Println("\nDone!")
}
