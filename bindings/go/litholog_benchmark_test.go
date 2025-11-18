package litholog

import (
	"testing"
)

func BenchmarkParseSimpleSoil(b *testing.B) {
	description := "Firm CLAY"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		desc, _ := Parse(description)
		if desc != nil {
			_ = desc
		}
	}
}

func BenchmarkParseComplexSoil(b *testing.B) {
	description := "Firm to stiff slightly sandy gravelly CLAY"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		desc, _ := Parse(description)
		if desc != nil {
			_ = desc
		}
	}
}

func BenchmarkParseRock(b *testing.B) {
	description := "Strong slightly weathered jointed LIMESTONE"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		desc, _ := Parse(description)
		if desc != nil {
			_ = desc
		}
	}
}

func BenchmarkParseMultipleDifferentDescriptions(b *testing.B) {
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

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		desc := descriptions[i%len(descriptions)]
		result, _ := Parse(desc)
		if result != nil {
			_ = result
		}
	}
}

func BenchmarkToJSON(b *testing.B) {
	desc, _ := Parse("Firm to stiff slightly sandy gravelly CLAY")
	if desc == nil {
		b.Fatal("Failed to parse description for benchmark")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = desc.ToJSON()
	}
}

func BenchmarkParseWithStrengthParameters(b *testing.B) {
	description := "Very stiff CLAY"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		desc, _ := Parse(description)
		if desc != nil && desc.StrengthParameters != nil {
			_ = desc.StrengthParameters.ValueRange.LowerBound
			_ = desc.StrengthParameters.ValueRange.UpperBound
		}
	}
}

func BenchmarkEnumStringConversion(b *testing.B) {
	consistency := ConsistencyFirm
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = consistency.String()
	}
}

func BenchmarkBatchParse10(b *testing.B) {
	descriptions := []string{
		"Firm CLAY",
		"Dense SAND",
		"Strong LIMESTONE",
		"Stiff CLAY",
		"Very dense GRAVEL",
		"Weak SANDSTONE",
		"Soft SILT",
		"Hard CLAY",
		"Loose SAND",
		"Extremely strong GRANITE",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		results := ParseBatch(descriptions)
		_ = results
	}
}

func BenchmarkBatchParse100(b *testing.B) {
	// Create 100 descriptions
	baseDescriptions := []string{
		"Firm CLAY",
		"Dense SAND",
		"Strong LIMESTONE",
		"Stiff CLAY",
		"Very dense GRAVEL",
	}

	descriptions := make([]string, 100)
	for i := 0; i < 100; i++ {
		descriptions[i] = baseDescriptions[i%len(baseDescriptions)]
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		results := ParseBatch(descriptions)
		_ = results
	}
}

func BenchmarkValidate(b *testing.B) {
	description := "Firm CLAY"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = Validate(description)
	}
}

func BenchmarkParseParallel(b *testing.B) {
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

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		i := 0
		for pb.Next() {
			desc := descriptions[i%len(descriptions)]
			result, _ := Parse(desc)
			if result != nil {
				_ = result
			}
			i++
		}
	})
}
