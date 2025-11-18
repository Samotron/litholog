#ifndef LITHOLOG_H
#define LITHOLOG_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    LITHOLOG_MATERIAL_SOIL = 0,
    LITHOLOG_MATERIAL_ROCK = 1
} litholog_material_type_t;

typedef enum {
    LITHOLOG_CONSISTENCY_VERY_SOFT = 0,
    LITHOLOG_CONSISTENCY_SOFT = 1,
    LITHOLOG_CONSISTENCY_FIRM = 2,
    LITHOLOG_CONSISTENCY_STIFF = 3,
    LITHOLOG_CONSISTENCY_VERY_STIFF = 4,
    LITHOLOG_CONSISTENCY_HARD = 5,
    LITHOLOG_CONSISTENCY_SOFT_TO_FIRM = 6,
    LITHOLOG_CONSISTENCY_FIRM_TO_STIFF = 7,
    LITHOLOG_CONSISTENCY_STIFF_TO_VERY_STIFF = 8
} litholog_consistency_t;

typedef enum {
    LITHOLOG_DENSITY_VERY_LOOSE = 0,
    LITHOLOG_DENSITY_LOOSE = 1,
    LITHOLOG_DENSITY_MEDIUM_DENSE = 2,
    LITHOLOG_DENSITY_DENSE = 3,
    LITHOLOG_DENSITY_VERY_DENSE = 4
} litholog_density_t;

typedef enum {
    LITHOLOG_ROCK_STRENGTH_VERY_WEAK = 0,
    LITHOLOG_ROCK_STRENGTH_WEAK = 1,
    LITHOLOG_ROCK_STRENGTH_MODERATELY_WEAK = 2,
    LITHOLOG_ROCK_STRENGTH_MODERATELY_STRONG = 3,
    LITHOLOG_ROCK_STRENGTH_STRONG = 4,
    LITHOLOG_ROCK_STRENGTH_VERY_STRONG = 5,
    LITHOLOG_ROCK_STRENGTH_EXTREMELY_STRONG = 6
} litholog_rock_strength_t;

typedef enum {
    LITHOLOG_SOIL_TYPE_CLAY = 0,
    LITHOLOG_SOIL_TYPE_SILT = 1,
    LITHOLOG_SOIL_TYPE_SAND = 2,
    LITHOLOG_SOIL_TYPE_GRAVEL = 3,
    LITHOLOG_SOIL_TYPE_PEAT = 4,
    LITHOLOG_SOIL_TYPE_ORGANIC = 5
} litholog_soil_type_t;

typedef enum {
    LITHOLOG_ROCK_TYPE_LIMESTONE = 0,
    LITHOLOG_ROCK_TYPE_SANDSTONE = 1,
    LITHOLOG_ROCK_TYPE_MUDSTONE = 2,
    LITHOLOG_ROCK_TYPE_SHALE = 3,
    LITHOLOG_ROCK_TYPE_GRANITE = 4,
    LITHOLOG_ROCK_TYPE_BASALT = 5,
    LITHOLOG_ROCK_TYPE_CHALK = 6,
    LITHOLOG_ROCK_TYPE_DOLOMITE = 7,
    LITHOLOG_ROCK_TYPE_QUARTZITE = 8,
    LITHOLOG_ROCK_TYPE_SLATE = 9,
    LITHOLOG_ROCK_TYPE_SCHIST = 10,
    LITHOLOG_ROCK_TYPE_GNEISS = 11,
    LITHOLOG_ROCK_TYPE_MARBLE = 12,
    LITHOLOG_ROCK_TYPE_CONGLOMERATE = 13,
    LITHOLOG_ROCK_TYPE_BRECCIA = 14
} litholog_rock_type_t;

typedef enum {
    LITHOLOG_WEATHERING_FRESH = 0,
    LITHOLOG_WEATHERING_SLIGHTLY = 1,
    LITHOLOG_WEATHERING_MODERATELY = 2,
    LITHOLOG_WEATHERING_HIGHLY = 3,
    LITHOLOG_WEATHERING_COMPLETELY = 4
} litholog_weathering_grade_t;

typedef enum {
    LITHOLOG_ROCK_STRUCTURE_MASSIVE = 0,
    LITHOLOG_ROCK_STRUCTURE_BEDDED = 1,
    LITHOLOG_ROCK_STRUCTURE_JOINTED = 2,
    LITHOLOG_ROCK_STRUCTURE_FRACTURED = 3,
    LITHOLOG_ROCK_STRUCTURE_FOLIATED = 4,
    LITHOLOG_ROCK_STRUCTURE_LAMINATED = 5
} litholog_rock_structure_t;

typedef enum {
    LITHOLOG_STRENGTH_PARAM_UCS = 0,
    LITHOLOG_STRENGTH_PARAM_UNDRAINED_SHEAR = 1,
    LITHOLOG_STRENGTH_PARAM_SPT_N_VALUE = 2,
    LITHOLOG_STRENGTH_PARAM_FRICTION_ANGLE = 3
} litholog_strength_parameter_type_t;

typedef struct {
    char* amount;
    char* soil_type;
} litholog_secondary_constituent_t;

typedef struct {
    double lower_bound;
    double upper_bound;
    double typical_value;
    int has_typical_value;
} litholog_strength_range_t;

typedef struct {
    litholog_strength_parameter_type_t parameter_type;
    litholog_strength_range_t value_range;
    double confidence;
} litholog_strength_parameters_t;

typedef struct {
    char* raw_description;
    litholog_material_type_t material_type;
    
    // Soil properties (values < 0 indicate not set)
    int consistency;
    int density;
    int primary_soil_type;
    
    // Rock properties (values < 0 indicate not set)
    int rock_strength;
    int weathering_grade;
    int rock_structure;
    int primary_rock_type;
    
    // Secondary constituents
    litholog_secondary_constituent_t* secondary_constituents;
    int secondary_constituents_count;
    
    // Strength parameters (null if not available)
    litholog_strength_parameters_t* strength_parameters;
    int has_strength_parameters;
    
    double confidence;
} litholog_soil_description_t;

// Core functions
litholog_soil_description_t* litholog_parse(const char* description);
void litholog_free_description(litholog_soil_description_t* description);
char* litholog_description_to_json(const litholog_soil_description_t* description);
void litholog_free_string(char* str);

// Utility functions
const char* litholog_material_type_to_string(litholog_material_type_t type);
const char* litholog_consistency_to_string(litholog_consistency_t consistency);
const char* litholog_density_to_string(litholog_density_t density);
const char* litholog_rock_strength_to_string(litholog_rock_strength_t strength);
const char* litholog_soil_type_to_string(litholog_soil_type_t type);
const char* litholog_rock_type_to_string(litholog_rock_type_t type);
const char* litholog_weathering_grade_to_string(litholog_weathering_grade_t grade);
const char* litholog_rock_structure_to_string(litholog_rock_structure_t structure);
const char* litholog_strength_parameter_type_to_string(litholog_strength_parameter_type_t type);

// Version functions
unsigned int litholog_version_major(void);
unsigned int litholog_version_minor(void);
unsigned int litholog_version_patch(void);
const char* litholog_version_string(void);

// Advanced features
char* litholog_generate_description(const litholog_soil_description_t* description);
char* litholog_generate_concise(const litholog_soil_description_t* description);
char* litholog_fuzzy_match(const char* target, const char** options, int options_count, float threshold);
float litholog_similarity(const char* s1, const char* s2);

#ifdef __cplusplus
}
#endif

#endif // LITHOLOG_H