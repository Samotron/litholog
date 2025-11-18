package litholog

/*
#cgo CFLAGS: -I${SRCDIR}
#cgo linux LDFLAGS: -L${SRCDIR} -llitholog -Wl,-rpath,${SRCDIR}
#cgo darwin LDFLAGS: -L${SRCDIR} -llitholog -Wl,-rpath,${SRCDIR}
#cgo windows LDFLAGS: -L${SRCDIR} -llitholog
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

// ParseBatch parses multiple geological descriptions efficiently
func ParseBatch(descriptions []string) []*SoilDescription {
	results := make([]*SoilDescription, len(descriptions))
	for i, desc := range descriptions {
		result, _ := Parse(desc)
		results[i] = result
	}
	return results
}

// ParseBatchWithErrors parses multiple descriptions and returns errors for each
func ParseBatchWithErrors(descriptions []string) ([]*SoilDescription, []error) {
	results := make([]*SoilDescription, len(descriptions))
	errors := make([]error, len(descriptions))
	for i, desc := range descriptions {
		result, err := Parse(desc)
		results[i] = result
		errors[i] = err
	}
	return results, errors
}

// ValidationError represents a validation error
type ValidationError struct {
	Message string
	Field   string
}

func (e *ValidationError) Error() string {
	if e.Field != "" {
		return e.Field + ": " + e.Message
	}
	return e.Message
}

// ValidationResult contains validation information
type ValidationResult struct {
	Valid   bool
	Errors  []*ValidationError
	Warning []string
}

// Validate checks if a description string is valid
func Validate(description string) *ValidationResult {
	result := &ValidationResult{
		Valid:   true,
		Errors:  make([]*ValidationError, 0),
		Warning: make([]string, 0),
	}

	// Check for empty description
	if description == "" {
		result.Valid = false
		result.Errors = append(result.Errors, &ValidationError{
			Message: "Description cannot be empty",
			Field:   "description",
		})
		return result
	}

	// Try to parse and check result
	desc, err := Parse(description)
	if err != nil {
		result.Valid = false
		result.Errors = append(result.Errors, &ValidationError{
			Message: err.Error(),
			Field:   "parse",
		})
		return result
	}

	if desc == nil {
		result.Valid = false
		result.Errors = append(result.Errors, &ValidationError{
			Message: "Failed to parse description",
			Field:   "parse",
		})
		return result
	}

	// Check for low confidence
	if desc.Confidence < 0.5 {
		result.Warning = append(result.Warning, "Low confidence score")
	}

	// Check for missing primary type
	if desc.MaterialType == MaterialTypeSoil && desc.PrimarySoilType == nil {
		result.Warning = append(result.Warning, "Missing primary soil type")
	}

	if desc.MaterialType == MaterialTypeRock && desc.PrimaryRockType == nil {
		result.Warning = append(result.Warning, "Missing primary rock type")
	}

	return result
}

// ValidateBatch validates multiple descriptions
func ValidateBatch(descriptions []string) []*ValidationResult {
	results := make([]*ValidationResult, len(descriptions))
	for i, desc := range descriptions {
		results[i] = Validate(desc)
	}
	return results
}

// DescriptionBuilder helps construct geological descriptions programmatically
type DescriptionBuilder struct {
	materialType          MaterialType
	consistency           *Consistency
	density               *Density
	soilType              *SoilType
	rockStrength          *RockStrength
	weatheringGrade       *WeatheringGrade
	rockStructure         *RockStructure
	rockType              *RockType
	secondaryConstituents []string
	particleSize          string
}

// NewSoilBuilder creates a builder for soil descriptions
func NewSoilBuilder(soilType SoilType) *DescriptionBuilder {
	return &DescriptionBuilder{
		materialType:          MaterialTypeSoil,
		soilType:              &soilType,
		secondaryConstituents: make([]string, 0),
	}
}

// NewRockBuilder creates a builder for rock descriptions
func NewRockBuilder(rockType RockType) *DescriptionBuilder {
	return &DescriptionBuilder{
		materialType: MaterialTypeRock,
		rockType:     &rockType,
	}
}

// WithConsistency sets the consistency for soil
func (b *DescriptionBuilder) WithConsistency(consistency Consistency) *DescriptionBuilder {
	b.consistency = &consistency
	return b
}

// WithDensity sets the density for granular soils
func (b *DescriptionBuilder) WithDensity(density Density) *DescriptionBuilder {
	b.density = &density
	return b
}

// WithRockStrength sets the rock strength
func (b *DescriptionBuilder) WithRockStrength(strength RockStrength) *DescriptionBuilder {
	b.rockStrength = &strength
	return b
}

// WithWeathering sets the weathering grade
func (b *DescriptionBuilder) WithWeathering(weathering WeatheringGrade) *DescriptionBuilder {
	b.weatheringGrade = &weathering
	return b
}

// WithStructure sets the rock structure
func (b *DescriptionBuilder) WithStructure(structure RockStructure) *DescriptionBuilder {
	b.rockStructure = &structure
	return b
}

// WithSecondaryConstituent adds a secondary constituent
func (b *DescriptionBuilder) WithSecondaryConstituent(amount, soilType string) *DescriptionBuilder {
	b.secondaryConstituents = append(b.secondaryConstituents, amount+" "+soilType)
	return b
}

// WithParticleSize sets particle size for granular soils
func (b *DescriptionBuilder) WithParticleSize(size string) *DescriptionBuilder {
	b.particleSize = size
	return b
}

// Build constructs the description string
func (b *DescriptionBuilder) Build() string {
	parts := make([]string, 0)

	// Add strength/consistency/density
	if b.consistency != nil {
		parts = append(parts, b.consistency.String())
	}
	if b.density != nil {
		parts = append(parts, b.density.String())
	}
	if b.rockStrength != nil {
		parts = append(parts, b.rockStrength.String())
	}

	// Add weathering
	if b.weatheringGrade != nil {
		parts = append(parts, b.weatheringGrade.String()+" weathered")
	}

	// Add structure
	if b.rockStructure != nil {
		parts = append(parts, b.rockStructure.String())
	}

	// Add secondary constituents
	for _, sc := range b.secondaryConstituents {
		parts = append(parts, sc)
	}

	// Add particle size
	if b.particleSize != "" {
		parts = append(parts, b.particleSize)
	}

	// Add primary type
	if b.soilType != nil {
		parts = append(parts, b.soilType.String())
	}
	if b.rockType != nil {
		parts = append(parts, b.rockType.String())
	}

	description := ""
	for i, part := range parts {
		if i > 0 {
			description += " "
		}
		description += part
	}

	return description
}

// BuildAndParse constructs the description and parses it
func (b *DescriptionBuilder) BuildAndParse() (*SoilDescription, error) {
	description := b.Build()
	return Parse(description)
}

// StreamProcessor processes descriptions from a stream
type StreamProcessor struct {
	bufferSize int
	worker     func(*SoilDescription, error)
}

// NewStreamProcessor creates a new stream processor
func NewStreamProcessor(bufferSize int, worker func(*SoilDescription, error)) *StreamProcessor {
	return &StreamProcessor{
		bufferSize: bufferSize,
		worker:     worker,
	}
}

// ProcessDescriptions processes descriptions concurrently
func (sp *StreamProcessor) ProcessDescriptions(descriptions []string) {
	ch := make(chan string, sp.bufferSize)
	done := make(chan bool)

	// Start workers
	numWorkers := 4
	for i := 0; i < numWorkers; i++ {
		go func() {
			for desc := range ch {
				result, err := Parse(desc)
				sp.worker(result, err)
			}
			done <- true
		}()
	}

	// Send work
	for _, desc := range descriptions {
		ch <- desc
	}
	close(ch)

	// Wait for completion
	for i := 0; i < numWorkers; i++ {
		<-done
	}
}

// FileStreamProcessor processes descriptions from a file line by line
type FileStreamProcessor struct {
	processor *StreamProcessor
}

// NewFileStreamProcessor creates a file stream processor
func NewFileStreamProcessor(worker func(*SoilDescription, error)) *FileStreamProcessor {
	return &FileStreamProcessor{
		processor: NewStreamProcessor(100, worker),
	}
}

// ProcessFile reads descriptions from a file and processes them
func (fsp *FileStreamProcessor) ProcessFile(lines []string) {
	fsp.processor.ProcessDescriptions(lines)
}

// GenerateDescription generates a description string from a parsed SoilDescription
func GenerateDescription(desc *SoilDescription) string {
	if desc == nil || desc.cPtr == nil {
		return ""
	}

	cStr := C.litholog_generate_description((*C.litholog_soil_description_t)(desc.cPtr))
	if cStr == nil {
		return ""
	}
	defer C.litholog_free_string(cStr)

	return C.GoString(cStr)
}

// GenerateConcise generates a concise description string
func GenerateConcise(desc *SoilDescription) string {
	if desc == nil || desc.cPtr == nil {
		return ""
	}

	cStr := C.litholog_generate_concise((*C.litholog_soil_description_t)(desc.cPtr))
	if cStr == nil {
		return ""
	}
	defer C.litholog_free_string(cStr)

	return C.GoString(cStr)
}

// FuzzyMatch finds the closest matching string from options
func FuzzyMatch(target string, options []string, threshold float32) string {
	if len(options) == 0 {
		return ""
	}

	cTarget := C.CString(target)
	defer C.free(unsafe.Pointer(cTarget))

	// Convert Go string array to C array
	cOptions := make([]*C.char, len(options))
	for i, opt := range options {
		cOptions[i] = C.CString(opt)
		defer C.free(unsafe.Pointer(cOptions[i]))
	}

	cResult := C.litholog_fuzzy_match(cTarget, &cOptions[0], C.int(len(options)), C.float(threshold))
	if cResult == nil {
		return ""
	}
	defer C.litholog_free_string(cResult)

	return C.GoString(cResult)
}

// Similarity calculates the similarity ratio between two strings (0.0 to 1.0)
func Similarity(s1, s2 string) float32 {
	cS1 := C.CString(s1)
	defer C.free(unsafe.Pointer(cS1))

	cS2 := C.CString(s2)
	defer C.free(unsafe.Pointer(cS2))

	return float32(C.litholog_similarity(cS1, cS2))
}
