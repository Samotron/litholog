package main

import (
	"fmt"
	"sync"

	"github.com/samotron/litholog/bindings/go"
)

func main() {
	fmt.Println("=== Streaming Processing Example ===")

	// Create a large set of descriptions
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

	// Duplicate to create more items
	largeSet := make([]string, 0)
	for i := 0; i < 10; i++ {
		largeSet = append(largeSet, descriptions...)
	}

	fmt.Printf("\nProcessing %d descriptions...\n", len(largeSet))

	// Use mutex for thread-safe counting
	var mu sync.Mutex
	successCount := 0
	errorCount := 0
	totalConfidence := 0.0

	// Create a worker function
	worker := func(desc *litholog.SoilDescription, err error) {
		mu.Lock()
		defer mu.Unlock()

		if err != nil {
			errorCount++
		} else if desc != nil {
			successCount++
			totalConfidence += desc.Confidence
		} else {
			errorCount++
		}
	}

	// Process descriptions concurrently
	processor := litholog.NewStreamProcessor(50, worker)
	processor.ProcessDescriptions(largeSet)

	// Display results
	fmt.Println("\n=== Processing Results ===")
	fmt.Printf("Total descriptions: %d\n", len(largeSet))
	fmt.Printf("Successfully parsed: %d\n", successCount)
	fmt.Printf("Errors: %d\n", errorCount)

	if successCount > 0 {
		avgConfidence := totalConfidence / float64(successCount)
		fmt.Printf("Average confidence: %.2f\n", avgConfidence)
	}

	// Example with file-like processing
	fmt.Println("\n=== File Stream Processing ===")

	fileLines := []string{
		"Firm CLAY",
		"Dense SAND",
		"Strong LIMESTONE",
		"Stiff CLAY",
		"Medium dense GRAVEL",
	}

	mu2 := sync.Mutex{}
	results := make([]*litholog.SoilDescription, 0)

	fileWorker := func(desc *litholog.SoilDescription, err error) {
		mu2.Lock()
		defer mu2.Unlock()

		if desc != nil {
			results = append(results, desc)
		}
	}

	fileProcessor := litholog.NewFileStreamProcessor(fileWorker)
	fileProcessor.ProcessFile(fileLines)

	fmt.Printf("Processed %d lines from file\n", len(results))
	fmt.Println("\nResults:")
	for i, result := range results {
		fmt.Printf("%d. %s (Confidence: %.2f)\n",
			i+1, result.RawDescription, result.Confidence)
	}
}
