package main

import (
	"fmt"
	"log"

	"github.com/samotron/litholog/bindings/go"
)

func main() {
	fmt.Println("=== Description Builder Example ===\n")

	// Build a soil description
	fmt.Println("1. Building a soil description:")

	soilBuilder := litholog.NewSoilBuilder(litholog.SoilTypeClay).
		WithConsistency(litholog.ConsistencyFirm).
		WithSecondaryConstituent("slightly", "sandy")

	description := soilBuilder.Build()
	fmt.Printf("Built description: %s\n", description)

	// Parse the built description
	desc, err := soilBuilder.BuildAndParse()
	if err != nil {
		log.Fatal(err)
	}

	if desc != nil {
		fmt.Printf("Material Type: %s\n", desc.MaterialType.String())
		fmt.Printf("Confidence: %.2f\n\n", desc.Confidence)
	}

	// Build a rock description
	fmt.Println("2. Building a rock description:")

	rockBuilder := litholog.NewRockBuilder(litholog.RockTypeLimestone).
		WithRockStrength(litholog.RockStrengthStrong).
		WithWeathering(litholog.WeatheringGradeSlightly).
		WithStructure(litholog.RockStructureJointed)

	rockDescription := rockBuilder.Build()
	fmt.Printf("Built description: %s\n", rockDescription)

	rockDesc, err := rockBuilder.BuildAndParse()
	if err != nil {
		log.Fatal(err)
	}

	if rockDesc != nil {
		fmt.Printf("Material Type: %s\n", rockDesc.MaterialType.String())
		if rockDesc.RockStrength != nil {
			fmt.Printf("Rock Strength: %s\n", rockDesc.RockStrength.String())
		}
		fmt.Printf("Confidence: %.2f\n\n", rockDesc.Confidence)
	}

	// Build a complex soil description
	fmt.Println("3. Building a complex soil description:")

	complexBuilder := litholog.NewSoilBuilder(litholog.SoilTypeSand).
		WithDensity(litholog.DensityDense).
		WithSecondaryConstituent("slightly", "silty").
		WithParticleSize("fine to coarse")

	complexDescription := complexBuilder.Build()
	fmt.Printf("Built description: %s\n", complexDescription)

	complexDesc, err := complexBuilder.BuildAndParse()
	if err != nil {
		log.Fatal(err)
	}

	if complexDesc != nil {
		fmt.Printf("Material Type: %s\n", complexDesc.MaterialType.String())
		if complexDesc.Density != nil {
			fmt.Printf("Density: %s\n", complexDesc.Density.String())
		}
		if len(complexDesc.SecondaryConstituents) > 0 {
			fmt.Println("Secondary Constituents:")
			for _, sc := range complexDesc.SecondaryConstituents {
				fmt.Printf("  - %s %s\n", sc.Amount, sc.SoilType)
			}
		}
		fmt.Printf("Confidence: %.2f\n", complexDesc.Confidence)
	}
}
