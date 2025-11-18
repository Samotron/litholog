const std = @import("std");
const types = @import("types.zig");

/// Parser configuration options
pub const ParserConfig = struct {
    /// Minimum confidence threshold for accepting parse results
    min_confidence: f32 = 0.5,

    /// Enable fuzzy matching for typo tolerance
    enable_fuzzy_matching: bool = true,

    /// Fuzzy match threshold (0.0 to 1.0)
    fuzzy_threshold: f32 = 0.8,

    /// Enable strict BS5930 compliance checking
    strict_bs5930: bool = false,

    /// Custom soil types dictionary
    custom_soil_types: []const []const u8 = &[_][]const u8{},

    /// Custom rock types dictionary
    custom_rock_types: []const []const u8 = &[_][]const u8{},

    /// Enable warnings for ambiguous descriptions
    enable_warnings: bool = true,

    /// Maximum number of warnings to generate
    max_warnings: usize = 10,

    /// Confidence boost for exact matches
    exact_match_boost: f32 = 0.1,

    /// Confidence penalty for fuzzy matches
    fuzzy_match_penalty: f32 = 0.1,

    /// Enable verbose logging
    verbose: bool = false,

    pub fn default() ParserConfig {
        return ParserConfig{};
    }

    pub fn withMinConfidence(self: ParserConfig, min_confidence: f32) ParserConfig {
        var config = self;
        config.min_confidence = min_confidence;
        return config;
    }

    pub fn withFuzzyMatching(self: ParserConfig, enabled: bool) ParserConfig {
        var config = self;
        config.enable_fuzzy_matching = enabled;
        return config;
    }

    pub fn withFuzzyThreshold(self: ParserConfig, threshold: f32) ParserConfig {
        var config = self;
        config.fuzzy_threshold = threshold;
        return config;
    }

    pub fn withStrictBS5930(self: ParserConfig, strict: bool) ParserConfig {
        var config = self;
        config.strict_bs5930 = strict;
        return config;
    }

    pub fn withCustomSoilTypes(self: ParserConfig, soil_types: []const []const u8) ParserConfig {
        var config = self;
        config.custom_soil_types = soil_types;
        return config;
    }

    pub fn withCustomRockTypes(self: ParserConfig, rock_types: []const []const u8) ParserConfig {
        var config = self;
        config.custom_rock_types = rock_types;
        return config;
    }

    pub fn withVerbose(self: ParserConfig, verbose: bool) ParserConfig {
        var config = self;
        config.verbose = verbose;
        return config;
    }

    /// Validate configuration values
    pub fn validate(self: ParserConfig) !void {
        if (self.min_confidence < 0.0 or self.min_confidence > 1.0) {
            return error.InvalidMinConfidence;
        }

        if (self.fuzzy_threshold < 0.0 or self.fuzzy_threshold > 1.0) {
            return error.InvalidFuzzyThreshold;
        }

        if (self.exact_match_boost < 0.0 or self.exact_match_boost > 1.0) {
            return error.InvalidExactMatchBoost;
        }

        if (self.fuzzy_match_penalty < 0.0 or self.fuzzy_match_penalty > 1.0) {
            return error.InvalidFuzzyMatchPenalty;
        }
    }
};

/// Custom dictionary for geological terms
pub const CustomDictionary = struct {
    soil_types: std.StringHashMap(types.SoilType),
    rock_types: std.StringHashMap(types.RockType),
    consistency_terms: std.StringHashMap(types.Consistency),
    density_terms: std.StringHashMap(types.Density),
    rock_strength_terms: std.StringHashMap(types.RockStrength),
    weathering_terms: std.StringHashMap(types.WeatheringGrade),
    structure_terms: std.StringHashMap(types.RockStructure),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CustomDictionary {
        return CustomDictionary{
            .soil_types = std.StringHashMap(types.SoilType).init(allocator),
            .rock_types = std.StringHashMap(types.RockType).init(allocator),
            .consistency_terms = std.StringHashMap(types.Consistency).init(allocator),
            .density_terms = std.StringHashMap(types.Density).init(allocator),
            .rock_strength_terms = std.StringHashMap(types.RockStrength).init(allocator),
            .weathering_terms = std.StringHashMap(types.WeatheringGrade).init(allocator),
            .structure_terms = std.StringHashMap(types.RockStructure).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CustomDictionary) void {
        // Free all keys
        var soil_iter = self.soil_types.keyIterator();
        while (soil_iter.next()) |key| {
            self.allocator.free(key.*);
        }

        var rock_iter = self.rock_types.keyIterator();
        while (rock_iter.next()) |key| {
            self.allocator.free(key.*);
        }

        var cons_iter = self.consistency_terms.keyIterator();
        while (cons_iter.next()) |key| {
            self.allocator.free(key.*);
        }

        self.soil_types.deinit();
        self.rock_types.deinit();
        self.consistency_terms.deinit();
        self.density_terms.deinit();
        self.rock_strength_terms.deinit();
        self.weathering_terms.deinit();
        self.structure_terms.deinit();
    }

    /// Add a custom soil type mapping
    pub fn addSoilType(self: *CustomDictionary, term: []const u8, soil_type: types.SoilType) !void {
        const term_copy = try self.allocator.dupe(u8, term);
        try self.soil_types.put(term_copy, soil_type);
    }

    /// Add a custom rock type mapping
    pub fn addRockType(self: *CustomDictionary, term: []const u8, rock_type: types.RockType) !void {
        const term_copy = try self.allocator.dupe(u8, term);
        try self.rock_types.put(term_copy, rock_type);
    }

    /// Add a custom consistency term
    pub fn addConsistencyTerm(self: *CustomDictionary, term: []const u8, consistency: types.Consistency) !void {
        const term_copy = try self.allocator.dupe(u8, term);
        try self.consistency_terms.put(term_copy, consistency);
    }

    /// Lookup a soil type
    pub fn lookupSoilType(self: *CustomDictionary, term: []const u8) ?types.SoilType {
        return self.soil_types.get(term);
    }

    /// Lookup a rock type
    pub fn lookupRockType(self: *CustomDictionary, term: []const u8) ?types.RockType {
        return self.rock_types.get(term);
    }

    /// Lookup a consistency term
    pub fn lookupConsistency(self: *CustomDictionary, term: []const u8) ?types.Consistency {
        return self.consistency_terms.get(term);
    }
};

/// Confidence adjuster for fine-tuning parse confidence scores
pub const ConfidenceAdjuster = struct {
    config: ParserConfig,

    pub fn init(config: ParserConfig) ConfidenceAdjuster {
        return ConfidenceAdjuster{
            .config = config,
        };
    }

    /// Adjust confidence based on parse quality
    pub fn adjust(self: ConfidenceAdjuster, base_confidence: f32, exact_match: bool, has_warnings: bool) f32 {
        var confidence = base_confidence;

        // Boost for exact matches
        if (exact_match) {
            confidence = @min(1.0, confidence + self.config.exact_match_boost);
        } else if (self.config.enable_fuzzy_matching) {
            // Penalty for fuzzy matches
            confidence = @max(0.0, confidence - self.config.fuzzy_match_penalty);
        }

        // Reduce confidence if warnings present
        if (has_warnings and self.config.enable_warnings) {
            confidence *= 0.95;
        }

        return confidence;
    }

    /// Check if confidence meets minimum threshold
    pub fn meetsThreshold(self: ConfidenceAdjuster, confidence: f32) bool {
        return confidence >= self.config.min_confidence;
    }
};

test "parser config default" {
    const config = ParserConfig.default();
    try std.testing.expectEqual(@as(f32, 0.5), config.min_confidence);
    try std.testing.expect(config.enable_fuzzy_matching);
}

test "parser config builder pattern" {
    const config = ParserConfig.default()
        .withMinConfidence(0.7)
        .withFuzzyThreshold(0.85)
        .withStrictBS5930(true);

    try std.testing.expectEqual(@as(f32, 0.7), config.min_confidence);
    try std.testing.expectEqual(@as(f32, 0.85), config.fuzzy_threshold);
    try std.testing.expect(config.strict_bs5930);
}

test "parser config validation" {
    const valid_config = ParserConfig.default();
    try valid_config.validate();

    var invalid_config = ParserConfig.default();
    invalid_config.min_confidence = 1.5;
    try std.testing.expectError(error.InvalidMinConfidence, invalid_config.validate());
}

test "custom dictionary" {
    const allocator = std.testing.allocator;

    var dict = CustomDictionary.init(allocator);
    defer dict.deinit();

    try dict.addSoilType("bolder clay", types.SoilType.clay);
    try dict.addRockType("magnesian limestone", types.RockType.limestone);

    const soil_type = dict.lookupSoilType("bolder clay");
    try std.testing.expect(soil_type != null);
    try std.testing.expectEqual(types.SoilType.clay, soil_type.?);
}

test "confidence adjuster" {
    const config = ParserConfig.default();
    const adjuster = ConfidenceAdjuster.init(config);

    // Test exact match boost
    const adjusted1 = adjuster.adjust(0.8, true, false);
    try std.testing.expect(adjusted1 > 0.8);

    // Test fuzzy match penalty
    const adjusted2 = adjuster.adjust(0.8, false, false);
    try std.testing.expect(adjusted2 < 0.8);

    // Test threshold check
    try std.testing.expect(adjuster.meetsThreshold(0.6));
    try std.testing.expect(!adjuster.meetsThreshold(0.4));
}
