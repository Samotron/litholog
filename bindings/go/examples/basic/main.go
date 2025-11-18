package main

import (
	"fmt"
	"log"

	"github.com/samotron/litholog/bindings/go"
)

func main() {
	// Parse a simple soil description
	fmt.Println("=== Basic Parsing Example ===\n")

	desc, err := litholog.Parse("Firm CLAY")
	if err != nil {
		log.Fatal(err)
	}

	if desc == nil {
		log.Fatal("Failed to parse description")
	}

	fmt.Printf("Raw Description: %s\n", desc.RawDescription)
	fmt.Printf("Material Type: %s\n", desc.MaterialType.String())

	if desc.Consistency != nil {
		fmt.Printf("Consistency: %s\n", desc.Consistency.String())
	}

	if desc.PrimarySoilType != nil {
		fmt.Printf("Soil Type: %s\n", desc.PrimarySoilType.String())
	}

	if desc.StrengthParameters != nil {
		sp := desc.StrengthParameters
		fmt.Printf("\nStrength Parameters:\n")
		fmt.Printf("  Type: %s\n", sp.ParameterType.String())
		fmt.Printf("  Range: %.1f - %.1f\n",
			sp.ValueRange.LowerBound,
			sp.ValueRange.UpperBound)
		if sp.ValueRange.HasTypical {
			fmt.Printf("  Typical: %.1f\n", sp.ValueRange.TypicalValue)
		}
		fmt.Printf("  Confidence: %.2f\n", sp.Confidence)
	}

	fmt.Printf("\nOverall Confidence: %.2f\n", desc.Confidence)

	// Parse a rock description
	fmt.Println("\n=== Rock Description ===\n")

	rockDesc, err := litholog.Parse("Strong slightly weathered LIMESTONE")
	if err != nil {
		log.Fatal(err)
	}

	if rockDesc != nil {
		fmt.Printf("Raw Description: %s\n", rockDesc.RawDescription)
		fmt.Printf("Material Type: %s\n", rockDesc.MaterialType.String())

		if rockDesc.RockStrength != nil {
			fmt.Printf("Rock Strength: %s\n", rockDesc.RockStrength.String())
		}

		if rockDesc.WeatheringGrade != nil {
			fmt.Printf("Weathering: %s\n", rockDesc.WeatheringGrade.String())
		}

		if rockDesc.PrimaryRockType != nil {
			fmt.Printf("Rock Type: %s\n", rockDesc.PrimaryRockType.String())
		}
	}

	// Parse a complex soil description
	fmt.Println("\n=== Complex Soil Description ===\n")

	complexDesc, err := litholog.Parse("Firm to stiff slightly sandy gravelly CLAY")
	if err != nil {
		log.Fatal(err)
	}

	if complexDesc != nil {
		fmt.Printf("Raw Description: %s\n", complexDesc.RawDescription)

		if complexDesc.Consistency != nil {
			fmt.Printf("Consistency: %s\n", complexDesc.Consistency.String())
		}

		if complexDesc.PrimarySoilType != nil {
			fmt.Printf("Primary Soil Type: %s\n", complexDesc.PrimarySoilType.String())
		}

		if len(complexDesc.SecondaryConstituents) > 0 {
			fmt.Println("\nSecondary Constituents:")
			for _, sc := range complexDesc.SecondaryConstituents {
				fmt.Printf("  - %s %s\n", sc.Amount, sc.SoilType)
			}
		}
	}
}
