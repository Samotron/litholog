package main

import (
	"fmt"

	"github.com/samotron/litholog/bindings/go"
)

func main() {
	fmt.Println("=== Batch Parsing Example ===\n")

	descriptions := []string{
		"Firm CLAY",
		"Dense SAND",
		"Strong LIMESTONE",
		"Firm to stiff slightly sandy gravelly CLAY",
		"Very dense slightly silty fine to coarse SAND",
		"Moderately strong slightly weathered SANDSTONE",
		"Weak highly weathered MUDSTONE",
		"Stiff CLAY",
		"Medium dense GRAVEL",
		"Extremely strong GRANITE",
	}

	// Parse all descriptions at once
	results := litholog.ParseBatch(descriptions)

	fmt.Printf("Parsed %d descriptions:\n\n", len(results))

	for i, result := range results {
		if result != nil {
			fmt.Printf("%d. %s\n", i+1, result.RawDescription)
			fmt.Printf("   Material: %s", result.MaterialType.String())

			if result.Consistency != nil {
				fmt.Printf(", Consistency: %s", result.Consistency.String())
			}
			if result.Density != nil {
				fmt.Printf(", Density: %s", result.Density.String())
			}
			if result.RockStrength != nil {
				fmt.Printf(", Strength: %s", result.RockStrength.String())
			}

			fmt.Printf(", Confidence: %.2f\n", result.Confidence)
		} else {
			fmt.Printf("%d. FAILED: %s\n", i+1, descriptions[i])
		}
	}

	// Parse with error handling
	fmt.Println("\n=== Batch Parsing with Error Handling ===\n")

	descriptions2 := []string{
		"Firm CLAY",
		"Invalid description xyz",
		"Dense SAND",
		"",
		"Strong LIMESTONE",
	}

	results2, errors := litholog.ParseBatchWithErrors(descriptions2)

	for i := range descriptions2 {
		if errors[i] != nil {
			fmt.Printf("%d. ERROR: %v\n", i+1, errors[i])
		} else if results2[i] != nil {
			fmt.Printf("%d. SUCCESS: %s (Confidence: %.2f)\n",
				i+1, results2[i].RawDescription, results2[i].Confidence)
		} else {
			fmt.Printf("%d. FAILED: %s\n", i+1, descriptions2[i])
		}
	}

	// Summary statistics
	fmt.Println("\n=== Summary Statistics ===\n")

	successCount := 0
	totalConfidence := 0.0

	for i, result := range results {
		if result != nil && errors[i] == nil {
			successCount++
			totalConfidence += result.Confidence
		}
	}

	if successCount > 0 {
		avgConfidence := totalConfidence / float64(successCount)
		fmt.Printf("Success Rate: %d/%d (%.1f%%)\n",
			successCount, len(results), float64(successCount)/float64(len(results))*100)
		fmt.Printf("Average Confidence: %.2f\n", avgConfidence)
	}
}
