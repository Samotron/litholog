package main

import (
	"fmt"

	"github.com/samotron/litholog/bindings/go"
)

func main() {
	fmt.Println("=== Validation Example ===\n")

	descriptions := []string{
		"Firm CLAY",
		"",
		"Invalid xyz description",
		"Dense SAND",
		"Strong LIMESTONE",
		"Extremely weak super CLAY", // This might have low confidence
	}

	fmt.Println("Validating descriptions:\n")

	for i, desc := range descriptions {
		result := litholog.Validate(desc)

		fmt.Printf("%d. Description: \"%s\"\n", i+1, desc)
		fmt.Printf("   Valid: %v\n", result.Valid)

		if len(result.Errors) > 0 {
			fmt.Println("   Errors:")
			for _, err := range result.Errors {
				fmt.Printf("     - %s\n", err.Error())
			}
		}

		if len(result.Warning) > 0 {
			fmt.Println("   Warnings:")
			for _, warn := range result.Warning {
				fmt.Printf("     - %s\n", warn)
			}
		}

		fmt.Println()
	}

	// Batch validation
	fmt.Println("=== Batch Validation ===\n")

	results := litholog.ValidateBatch(descriptions)

	validCount := 0
	for _, result := range results {
		if result.Valid {
			validCount++
		}
	}

	fmt.Printf("Valid descriptions: %d/%d (%.1f%%)\n",
		validCount, len(results), float64(validCount)/float64(len(results))*100)

	// Show only invalid descriptions
	fmt.Println("\nInvalid descriptions:")
	for i, result := range results {
		if !result.Valid {
			fmt.Printf("  - \"%s\"\n", descriptions[i])
			for _, err := range result.Errors {
				fmt.Printf("    Error: %s\n", err.Error())
			}
		}
	}
}
