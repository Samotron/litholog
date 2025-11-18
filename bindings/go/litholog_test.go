package litholog

import (
	"testing"
)

func TestParseSimpleSoilDescription(t *testing.T) {
	tests := []struct {
		name        string
		description string
		wantMat     MaterialType
		wantCons    *Consistency
		wantSoil    *SoilType
	}{
		{
			name:        "Firm clay",
			description: "Firm CLAY",
			wantMat:     MaterialTypeSoil,
			wantCons:    ptrConsistency(ConsistencyFirm),
			wantSoil:    ptrSoilType(SoilTypeClay),
		},
		{
			name:        "Stiff clay",
			description: "Stiff CLAY",
			wantMat:     MaterialTypeSoil,
			wantCons:    ptrConsistency(ConsistencyStiff),
			wantSoil:    ptrSoilType(SoilTypeClay),
		},
		{
			name:        "Very soft clay",
			description: "Very soft CLAY",
			wantMat:     MaterialTypeSoil,
			wantCons:    ptrConsistency(ConsistencyVerySoft),
			wantSoil:    ptrSoilType(SoilTypeClay),
		},
		{
			name:        "Hard clay",
			description: "Hard CLAY",
			wantMat:     MaterialTypeSoil,
			wantCons:    ptrConsistency(ConsistencyHard),
			wantSoil:    ptrSoilType(SoilTypeClay),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			desc, err := Parse(tt.description)
			if err != nil {
				t.Fatalf("Parse() error = %v", err)
			}
			if desc == nil {
				t.Fatal("Parse() returned nil description")
			}

			if desc.MaterialType != tt.wantMat {
				t.Errorf("MaterialType = %v, want %v", desc.MaterialType, tt.wantMat)
			}

			if tt.wantCons != nil {
				if desc.Consistency == nil {
					t.Errorf("Consistency = nil, want %v", *tt.wantCons)
				} else if *desc.Consistency != *tt.wantCons {
					t.Errorf("Consistency = %v, want %v", *desc.Consistency, *tt.wantCons)
				}
			}

			if tt.wantSoil != nil {
				if desc.PrimarySoilType == nil {
					t.Errorf("PrimarySoilType = nil, want %v", *tt.wantSoil)
				} else if *desc.PrimarySoilType != *tt.wantSoil {
					t.Errorf("PrimarySoilType = %v, want %v", *desc.PrimarySoilType, *tt.wantSoil)
				}
			}
		})
	}
}

func TestParseSoilWithDensity(t *testing.T) {
	tests := []struct {
		name        string
		description string
		wantDens    *Density
		wantSoil    *SoilType
	}{
		{
			name:        "Dense sand",
			description: "Dense SAND",
			wantDens:    ptrDensity(DensityDense),
			wantSoil:    ptrSoilType(SoilTypeSand),
		},
		{
			name:        "Very loose sand",
			description: "Very loose SAND",
			wantDens:    ptrDensity(DensityVeryLoose),
			wantSoil:    ptrSoilType(SoilTypeSand),
		},
		{
			name:        "Very dense gravel",
			description: "Very dense GRAVEL",
			wantDens:    ptrDensity(DensityVeryDense),
			wantSoil:    ptrSoilType(SoilTypeGravel),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			desc, err := Parse(tt.description)
			if err != nil {
				t.Fatalf("Parse() error = %v", err)
			}
			if desc == nil {
				t.Fatal("Parse() returned nil description")
			}

			if tt.wantDens != nil {
				if desc.Density == nil {
					t.Errorf("Density = nil, want %v", *tt.wantDens)
				} else if *desc.Density != *tt.wantDens {
					t.Errorf("Density = %v, want %v", *desc.Density, *tt.wantDens)
				}
			}

			if tt.wantSoil != nil {
				if desc.PrimarySoilType == nil {
					t.Errorf("PrimarySoilType = nil, want %v", *tt.wantSoil)
				} else if *desc.PrimarySoilType != *tt.wantSoil {
					t.Errorf("PrimarySoilType = %v, want %v", *desc.PrimarySoilType, *tt.wantSoil)
				}
			}
		})
	}
}

func TestParseRockDescription(t *testing.T) {
	tests := []struct {
		name         string
		description  string
		wantMat      MaterialType
		wantStrength *RockStrength
		wantRock     *RockType
	}{
		{
			name:         "Strong limestone",
			description:  "Strong LIMESTONE",
			wantMat:      MaterialTypeRock,
			wantStrength: ptrRockStrength(RockStrengthStrong),
			wantRock:     ptrRockType(RockTypeLimestone),
		},
		{
			name:         "Weak sandstone",
			description:  "Weak SANDSTONE",
			wantMat:      MaterialTypeRock,
			wantStrength: ptrRockStrength(RockStrengthWeak),
			wantRock:     ptrRockType(RockTypeSandstone),
		},
		{
			name:         "Extremely strong granite",
			description:  "Extremely strong GRANITE",
			wantMat:      MaterialTypeRock,
			wantStrength: ptrRockStrength(RockStrengthExtremelyStrong),
			wantRock:     ptrRockType(RockTypeGranite),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			desc, err := Parse(tt.description)
			if err != nil {
				t.Fatalf("Parse() error = %v", err)
			}
			if desc == nil {
				t.Fatal("Parse() returned nil description")
			}

			if desc.MaterialType != tt.wantMat {
				t.Errorf("MaterialType = %v, want %v", desc.MaterialType, tt.wantMat)
			}

			if tt.wantStrength != nil {
				if desc.RockStrength == nil {
					t.Errorf("RockStrength = nil, want %v", *tt.wantStrength)
				} else if *desc.RockStrength != *tt.wantStrength {
					t.Errorf("RockStrength = %v, want %v", *desc.RockStrength, *tt.wantStrength)
				}
			}

			if tt.wantRock != nil {
				if desc.PrimaryRockType == nil {
					t.Errorf("PrimaryRockType = nil, want %v", *tt.wantRock)
				} else if *desc.PrimaryRockType != *tt.wantRock {
					t.Errorf("PrimaryRockType = %v, want %v", *desc.PrimaryRockType, *tt.wantRock)
				}
			}
		})
	}
}

func TestParseWeatheredRock(t *testing.T) {
	tests := []struct {
		name           string
		description    string
		wantWeathering *WeatheringGrade
		wantRock       *RockType
	}{
		{
			name:           "Slightly weathered limestone",
			description:    "Strong slightly weathered LIMESTONE",
			wantWeathering: ptrWeatheringGrade(WeatheringGradeSlightly),
			wantRock:       ptrRockType(RockTypeLimestone),
		},
		{
			name:           "Highly weathered mudstone",
			description:    "Weak highly weathered MUDSTONE",
			wantWeathering: ptrWeatheringGrade(WeatheringGradeHighly),
			wantRock:       ptrRockType(RockTypeMudstone),
		},
		{
			name:           "Moderately weathered sandstone",
			description:    "Moderately strong moderately weathered SANDSTONE",
			wantWeathering: ptrWeatheringGrade(WeatheringGradeModerately),
			wantRock:       ptrRockType(RockTypeSandstone),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			desc, err := Parse(tt.description)
			if err != nil {
				t.Fatalf("Parse() error = %v", err)
			}
			if desc == nil {
				t.Fatal("Parse() returned nil description")
			}

			if tt.wantWeathering != nil {
				if desc.WeatheringGrade == nil {
					t.Errorf("WeatheringGrade = nil, want %v", *tt.wantWeathering)
				} else if *desc.WeatheringGrade != *tt.wantWeathering {
					t.Errorf("WeatheringGrade = %v, want %v", *desc.WeatheringGrade, *tt.wantWeathering)
				}
			}

			if tt.wantRock != nil {
				if desc.PrimaryRockType == nil {
					t.Errorf("PrimaryRockType = nil, want %v", *tt.wantRock)
				} else if *desc.PrimaryRockType != *tt.wantRock {
					t.Errorf("PrimaryRockType = %v, want %v", *desc.PrimaryRockType, *tt.wantRock)
				}
			}
		})
	}
}

func TestParseComplexSoilDescription(t *testing.T) {
	desc, err := Parse("Firm to stiff slightly sandy gravelly CLAY")
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}
	if desc == nil {
		t.Fatal("Parse() returned nil description")
	}

	if desc.MaterialType != MaterialTypeSoil {
		t.Errorf("MaterialType = %v, want %v", desc.MaterialType, MaterialTypeSoil)
	}

	if desc.PrimarySoilType == nil || *desc.PrimarySoilType != SoilTypeClay {
		t.Errorf("PrimarySoilType = %v, want CLAY", desc.PrimarySoilType)
	}

	if len(desc.SecondaryConstituents) == 0 {
		t.Error("Expected secondary constituents, got none")
	}
}

func TestParseJointedRock(t *testing.T) {
	desc, err := Parse("Moderately strong jointed SANDSTONE")
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}
	if desc == nil {
		t.Fatal("Parse() returned nil description")
	}

	if desc.MaterialType != MaterialTypeRock {
		t.Errorf("MaterialType = %v, want Rock", desc.MaterialType)
	}

	if desc.RockStructure == nil || *desc.RockStructure != RockStructureJointed {
		t.Errorf("RockStructure = %v, want jointed", desc.RockStructure)
	}

	if desc.PrimaryRockType == nil || *desc.PrimaryRockType != RockTypeSandstone {
		t.Errorf("PrimaryRockType = %v, want SANDSTONE", desc.PrimaryRockType)
	}
}

func TestParseStrengthParameters(t *testing.T) {
	tests := []struct {
		name        string
		description string
		wantParam   bool
	}{
		{
			name:        "Firm clay with strength",
			description: "Firm CLAY",
			wantParam:   true,
		},
		{
			name:        "Dense sand with strength",
			description: "Dense SAND",
			wantParam:   true,
		},
		{
			name:        "Strong limestone with strength",
			description: "Strong LIMESTONE",
			wantParam:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			desc, err := Parse(tt.description)
			if err != nil {
				t.Fatalf("Parse() error = %v", err)
			}
			if desc == nil {
				t.Fatal("Parse() returned nil description")
			}

			if tt.wantParam {
				if desc.StrengthParameters == nil {
					t.Error("Expected strength parameters, got nil")
				} else {
					if desc.StrengthParameters.ValueRange.LowerBound <= 0 {
						t.Error("Expected positive lower bound for strength")
					}
					if desc.StrengthParameters.ValueRange.UpperBound <= desc.StrengthParameters.ValueRange.LowerBound {
						t.Error("Expected upper bound > lower bound")
					}
				}
			}
		})
	}
}

func TestToJSON(t *testing.T) {
	desc, err := Parse("Firm CLAY")
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}
	if desc == nil {
		t.Fatal("Parse() returned nil description")
	}

	json := desc.ToJSON()
	if json == "" {
		t.Error("ToJSON() returned empty string")
	}

	// Check for basic JSON structure
	if json[0] != '{' || json[len(json)-1] != '}' {
		t.Error("ToJSON() did not return valid JSON structure")
	}
}

func TestEnumStringConversion(t *testing.T) {
	tests := []struct {
		name string
		test func(t *testing.T)
	}{
		{
			name: "MaterialType",
			test: func(t *testing.T) {
				if MaterialTypeSoil.String() != "soil" {
					t.Errorf("MaterialTypeSoil.String() = %s, want soil", MaterialTypeSoil.String())
				}
				if MaterialTypeRock.String() != "rock" {
					t.Errorf("MaterialTypeRock.String() = %s, want rock", MaterialTypeRock.String())
				}
			},
		},
		{
			name: "Consistency",
			test: func(t *testing.T) {
				if ConsistencyFirm.String() != "firm" {
					t.Errorf("ConsistencyFirm.String() = %s, want firm", ConsistencyFirm.String())
				}
			},
		},
		{
			name: "Density",
			test: func(t *testing.T) {
				if DensityDense.String() != "dense" {
					t.Errorf("DensityDense.String() = %s, want dense", DensityDense.String())
				}
			},
		},
		{
			name: "RockStrength",
			test: func(t *testing.T) {
				if RockStrengthStrong.String() != "strong" {
					t.Errorf("RockStrengthStrong.String() = %s, want strong", RockStrengthStrong.String())
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, tt.test)
	}
}

func TestParseRangeDescriptions(t *testing.T) {
	tests := []struct {
		name        string
		description string
		wantCons    *Consistency
	}{
		{
			name:        "Firm to stiff",
			description: "Firm to stiff CLAY",
			wantCons:    ptrConsistency(ConsistencyFirmToStiff),
		},
		{
			name:        "Soft to firm",
			description: "Soft to firm CLAY",
			wantCons:    ptrConsistency(ConsistencySoftToFirm),
		},
		{
			name:        "Stiff to very stiff",
			description: "Stiff to very stiff CLAY",
			wantCons:    ptrConsistency(ConsistencyStiffToVeryStiff),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			desc, err := Parse(tt.description)
			if err != nil {
				t.Fatalf("Parse() error = %v", err)
			}
			if desc == nil {
				t.Fatal("Parse() returned nil description")
			}

			if tt.wantCons != nil {
				if desc.Consistency == nil {
					t.Errorf("Consistency = nil, want %v", *tt.wantCons)
				} else if *desc.Consistency != *tt.wantCons {
					t.Errorf("Consistency = %v, want %v", *desc.Consistency, *tt.wantCons)
				}
			}
		})
	}
}

func TestConfidenceScores(t *testing.T) {
	tests := []struct {
		name        string
		description string
		minConf     float64
	}{
		{
			name:        "Simple description",
			description: "Firm CLAY",
			minConf:     0.8,
		},
		{
			name:        "Complex description",
			description: "Firm to stiff slightly sandy gravelly CLAY",
			minConf:     0.6,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			desc, err := Parse(tt.description)
			if err != nil {
				t.Fatalf("Parse() error = %v", err)
			}
			if desc == nil {
				t.Fatal("Parse() returned nil description")
			}

			if desc.Confidence < tt.minConf {
				t.Errorf("Confidence = %v, want >= %v", desc.Confidence, tt.minConf)
			}
		})
	}
}

// Helper functions for creating pointers to enum values
func ptrConsistency(c Consistency) *Consistency {
	return &c
}

func ptrDensity(d Density) *Density {
	return &d
}

func ptrRockStrength(rs RockStrength) *RockStrength {
	return &rs
}

func ptrSoilType(st SoilType) *SoilType {
	return &st
}

func ptrRockType(rt RockType) *RockType {
	return &rt
}

func ptrWeatheringGrade(wg WeatheringGrade) *WeatheringGrade {
	return &wg
}

func ptrRockStructure(rs RockStructure) *RockStructure {
	return &rs
}
