package litholog

/*
#cgo CFLAGS: -I../../include
#cgo LDFLAGS: -L../../ -llitholog
#include "litholog.h"
#include <stdlib.h>
*/
import "C"
import (
	"runtime"
	"unsafe"
)

// MaterialType represents the type of geological material
type MaterialType int

const (
	MaterialTypeSoil MaterialType = iota
	MaterialTypeRock
)

func (m MaterialType) String() string {
	switch m {
	case MaterialTypeSoil:
		return "soil"
	case MaterialTypeRock:
		return "rock"
	default:
		return "unknown"
	}
}

// Consistency represents soil consistency
type Consistency int

const (
	ConsistencyVerySoft Consistency = iota
	ConsistencySoft
	ConsistencyFirm
	ConsistencyStiff
	ConsistencyVeryStiff
	ConsistencyHard
	ConsistencySoftToFirm
	ConsistencyFirmToStiff
	ConsistencyStiffToVeryStiff
)

func (c Consistency) String() string {
	names := []string{
		"very soft", "soft", "firm", "stiff", "very stiff", "hard",
		"soft to firm", "firm to stiff", "stiff to very stiff",
	}
	if int(c) < len(names) {
		return names[c]
	}
	return "unknown"
}

// Density represents soil density
type Density int

const (
	DensityVeryLoose Density = iota
	DensityLoose
	DensityMediumDense
	DensityDense
	DensityVeryDense
)

func (d Density) String() string {
	names := []string{"very loose", "loose", "medium dense", "dense", "very dense"}
	if int(d) < len(names) {
		return names[d]
	}
	return "unknown"
}

// RockStrength represents rock strength
type RockStrength int

const (
	RockStrengthVeryWeak RockStrength = iota
	RockStrengthWeak
	RockStrengthModeratelyWeak
	RockStrengthModeratelyStrong
	RockStrengthStrong
	RockStrengthVeryStrong
	RockStrengthExtremelyStrong
)

func (r RockStrength) String() string {
	names := []string{
		"very weak", "weak", "moderately weak", "moderately strong",
		"strong", "very strong", "extremely strong",
	}
	if int(r) < len(names) {
		return names[r]
	}
	return "unknown"
}

// SoilType represents the primary soil type
type SoilType int

const (
	SoilTypeClay SoilType = iota
	SoilTypeSilt
	SoilTypeSand
	SoilTypeGravel
	SoilTypePeat
	SoilTypeOrganic
)

func (s SoilType) String() string {
	names := []string{"CLAY", "SILT", "SAND", "GRAVEL", "PEAT", "ORGANIC"}
	if int(s) < len(names) {
		return names[s]
	}
	return "unknown"
}

// RockType represents the primary rock type
type RockType int

const (
	RockTypeLimestone RockType = iota
	RockTypeSandstone
	RockTypeMudstone
	RockTypeShale
	RockTypeGranite
	RockTypeBasalt
	RockTypeChalk
	RockTypeDolomite
	RockTypeQuartzite
	RockTypeSlate
	RockTypeSchist
	RockTypeGneiss
	RockTypeMarble
	RockTypeConglomerate
	RockTypeBreccia
)

func (r RockType) String() string {
	names := []string{
		"LIMESTONE", "SANDSTONE", "MUDSTONE", "SHALE", "GRANITE",
		"BASALT", "CHALK", "DOLOMITE", "QUARTZITE", "SLATE",
		"SCHIST", "GNEISS", "MARBLE", "CONGLOMERATE", "BRECCIA",
	}
	if int(r) < len(names) {
		return names[r]
	}
	return "unknown"
}

// WeatheringGrade represents rock weathering grade
type WeatheringGrade int

const (
	WeatheringGradeFresh WeatheringGrade = iota
	WeatheringGradeSlightly
	WeatheringGradeModerately
	WeatheringGradeHighly
	WeatheringGradeCompletely
)

func (w WeatheringGrade) String() string {
	names := []string{"fresh", "slightly weathered", "moderately weathered", "highly weathered", "completely weathered"}
	if int(w) < len(names) {
		return names[w]
	}
	return "unknown"
}

// RockStructure represents rock structure
type RockStructure int

const (
	RockStructureMassive RockStructure = iota
	RockStructureBedded
	RockStructureJointed
	RockStructureFractured
	RockStructureFoliated
	RockStructureLaminated
)

func (r RockStructure) String() string {
	names := []string{"massive", "bedded", "jointed", "fractured", "foliated", "laminated"}
	if int(r) < len(names) {
		return names[r]
	}
	return "unknown"
}

// StrengthParameterType represents the type of strength parameter
type StrengthParameterType int

const (
	StrengthParameterTypeUCS StrengthParameterType = iota
	StrengthParameterTypeUndrainedShear
	StrengthParameterTypeSPTN
	StrengthParameterTypeFrictionAngle
)

func (s StrengthParameterType) String() string {
	names := []string{"UCS", "Undrained Shear Strength", "SPT N-value", "Friction Angle"}
	if int(s) < len(names) {
		return names[s]
	}
	return "unknown"
}

// SecondaryConstituent represents a secondary constituent in the soil
type SecondaryConstituent struct {
	Amount   string
	SoilType string
}

// StrengthValueRange represents a range of strength values
type StrengthValueRange struct {
	LowerBound   float64
	UpperBound   float64
	TypicalValue float64
	HasTypical   bool
}

// StrengthParameters represents strength parameters for the material
type StrengthParameters struct {
	ParameterType StrengthParameterType
	ValueRange    StrengthValueRange
	Confidence    float64
}

// SoilDescription represents a parsed geological description
type SoilDescription struct {
	RawDescription        string
	MaterialType          MaterialType
	Consistency           *Consistency
	Density               *Density
	PrimarySoilType       *SoilType
	RockStrength          *RockStrength
	WeatheringGrade       *WeatheringGrade
	RockStructure         *RockStructure
	PrimaryRockType       *RockType
	SecondaryConstituents []SecondaryConstituent
	StrengthParameters    *StrengthParameters
	Confidence            float64
	cPtr                  unsafe.Pointer
}

// Parse parses a geological description string and returns a SoilDescription
func Parse(description string) (*SoilDescription, error) {
	cDesc := C.CString(description)
	defer C.free(unsafe.Pointer(cDesc))

	result := C.litholog_parse(cDesc)
	if result == nil {
		return nil, nil
	}

	desc := &SoilDescription{}
	runtime.SetFinalizer(desc, (*SoilDescription).finalize)
	desc.fromC(result)

	return desc, nil
}

func (d *SoilDescription) fromC(cDesc *C.litholog_soil_description_t) {
	d.RawDescription = C.GoString(cDesc.raw_description)
	d.MaterialType = MaterialType(cDesc.material_type)
	d.Confidence = float64(cDesc.confidence)

	// Handle optional fields
	if cDesc.consistency >= 0 {
		consistency := Consistency(cDesc.consistency)
		d.Consistency = &consistency
	}
	if cDesc.density >= 0 {
		density := Density(cDesc.density)
		d.Density = &density
	}
	if cDesc.primary_soil_type >= 0 {
		soilType := SoilType(cDesc.primary_soil_type)
		d.PrimarySoilType = &soilType
	}
	if cDesc.rock_strength >= 0 {
		rockStrength := RockStrength(cDesc.rock_strength)
		d.RockStrength = &rockStrength
	}
	if cDesc.weathering_grade >= 0 {
		weatheringGrade := WeatheringGrade(cDesc.weathering_grade)
		d.WeatheringGrade = &weatheringGrade
	}
	if cDesc.rock_structure >= 0 {
		rockStructure := RockStructure(cDesc.rock_structure)
		d.RockStructure = &rockStructure
	}
	if cDesc.primary_rock_type >= 0 {
		rockType := RockType(cDesc.primary_rock_type)
		d.PrimaryRockType = &rockType
	}

	// Secondary constituents
	if cDesc.secondary_constituents_count > 0 {
		constituents := (*[1000]C.litholog_secondary_constituent_t)(unsafe.Pointer(cDesc.secondary_constituents))[:cDesc.secondary_constituents_count:cDesc.secondary_constituents_count]
		d.SecondaryConstituents = make([]SecondaryConstituent, len(constituents))
		for i, sc := range constituents {
			d.SecondaryConstituents[i] = SecondaryConstituent{
				Amount:   C.GoString(sc.amount),
				SoilType: C.GoString(sc.soil_type),
			}
		}
	}

	// Strength parameters
	if cDesc.has_strength_parameters == 1 && cDesc.strength_parameters != nil {
		sp := cDesc.strength_parameters
		d.StrengthParameters = &StrengthParameters{
			ParameterType: StrengthParameterType(sp.parameter_type),
			ValueRange: StrengthValueRange{
				LowerBound:   float64(sp.value_range.lower_bound),
				UpperBound:   float64(sp.value_range.upper_bound),
				TypicalValue: float64(sp.value_range.typical_value),
				HasTypical:   sp.value_range.has_typical_value == 1,
			},
			Confidence: float64(sp.confidence),
		}
	}

	// Store C pointer for cleanup
	d.cPtr = unsafe.Pointer(cDesc)
}

// ToJSON converts the description to JSON format
func (d *SoilDescription) ToJSON() string {
	if d.cPtr == nil {
		return "{}"
	}

	cJSON := C.litholog_description_to_json((*C.litholog_soil_description_t)(d.cPtr))
	if cJSON == nil {
		return "{}"
	}
	defer C.litholog_free_string(cJSON)

	return C.GoString(cJSON)
}

func (d *SoilDescription) finalize() {
	if d.cPtr != nil {
		C.litholog_free_description((*C.litholog_soil_description_t)(d.cPtr))
		d.cPtr = nil
	}
}
