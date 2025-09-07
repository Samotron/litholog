const std = @import("std");
const types = @import("types.zig");

const SoilDescription = types.SoilDescription;
const SoilType = types.SoilType;
const Consistency = types.Consistency;
const Density = types.Density;
const MaterialType = types.MaterialType;

pub const ValidationError = enum {
    cohesive_soil_missing_consistency,
    granular_soil_missing_density,
    cohesive_soil_has_density,
    granular_soil_has_consistency,
    invalid_soil_strength_combination,
    // New invalid combination errors
    invalid_consistency_soil_combination,
    invalid_density_soil_combination,
    invalid_plasticity_granular_soil,
    invalid_strength_material_combination,
    // Material type misclassification errors
    soil_material_classified_as_rock,

    pub fn toString(self: ValidationError) []const u8 {
        return switch (self) {
            .cohesive_soil_missing_consistency => "Cohesive soil (clay/silt) should have consistency descriptor (very soft, soft, firm, stiff, very stiff, hard)",
            .granular_soil_missing_density => "Granular soil (sand/gravel) should have density descriptor (very loose, loose, medium dense, dense, very dense)",
            .cohesive_soil_has_density => "Cohesive soil (clay/silt) should not have density descriptor - use consistency instead",
            .granular_soil_has_consistency => "Granular soil (sand/gravel) should not have consistency descriptor - use density instead",
            .invalid_soil_strength_combination => "Invalid combination of soil type and strength descriptor",
            .invalid_consistency_soil_combination => "Consistency descriptors (soft, firm, stiff) cannot be used with granular soils (sand/gravel)",
            .invalid_density_soil_combination => "Density descriptors (loose, dense) cannot be used with cohesive soils (clay/silt)",
            .invalid_plasticity_granular_soil => "Plasticity descriptors should only be used with cohesive soils (clay/silt)",
            .invalid_strength_material_combination => "Rock strength descriptors cannot be used with soil materials",
            .soil_material_classified_as_rock => "Material contains soil types (clay, silt, sand, gravel) but was classified as rock - check descriptors",
        };
    }

    pub fn isInvalidating(self: ValidationError) bool {
        return switch (self) {
            .invalid_consistency_soil_combination, .invalid_density_soil_combination, .invalid_plasticity_granular_soil, .invalid_strength_material_combination, .soil_material_classified_as_rock => true,
            else => false,
        };
    }
};

pub const ValidationWarning = struct {
    error_type: ValidationError,
    message: []const u8,
    severity: Severity,

    pub const Severity = enum {
        low,
        medium,
        high,

        pub fn toString(self: Severity) []const u8 {
            return switch (self) {
                .low => "low",
                .medium => "medium",
                .high => "high",
            };
        }
    };

    pub fn init(allocator: std.mem.Allocator, error_type: ValidationError, severity: Severity) !ValidationWarning {
        const message = try allocator.dupe(u8, error_type.toString());
        return ValidationWarning{
            .error_type = error_type,
            .message = message,
            .severity = severity,
        };
    }

    pub fn deinit(self: ValidationWarning, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
    }
};

pub const Validator = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Validator {
        return Validator{ .allocator = allocator };
    }

    pub fn validate(self: *Validator, description: *SoilDescription) !void {
        var warnings = std.ArrayList(ValidationWarning).init(self.allocator);
        defer {
            for (warnings.items) |warning| {
                warning.deinit(self.allocator);
            }
            warnings.deinit();
        }

        var has_invalidating_error = false;

        // Check for material type misclassification first
        const invalid_classification = try self.validateMaterialClassification(&warnings, description);
        if (invalid_classification) has_invalidating_error = true;

        if (description.material_type == .soil) {
            if (description.primary_soil_type) |soil_type| {
                const invalid_result = try self.validateSoilStrengthDescriptors(&warnings, soil_type, description.consistency, description.density);
                if (invalid_result) has_invalidating_error = true;

                const invalid_plasticity = try self.validatePlasticityDescriptors(&warnings, soil_type, description.plasticity_index);
                if (invalid_plasticity) has_invalidating_error = true;
            }

            const invalid_rock_props = try self.validateRockPropertiesOnSoil(&warnings, description);
            if (invalid_rock_props) has_invalidating_error = true;
        }

        // Mark as invalid if there are invalidating errors
        if (has_invalidating_error) {
            description.is_valid = false;
        }

        // Convert warnings to string array for SoilDescription
        if (warnings.items.len > 0) {
            var warning_strings = std.ArrayList([]const u8).init(self.allocator);
            defer warning_strings.deinit();

            for (warnings.items) |warning| {
                const warning_str = try std.fmt.allocPrint(self.allocator, "[{s}] {s}", .{ warning.severity.toString(), warning.message });
                try warning_strings.append(warning_str);
            }

            // Free existing warnings if any
            for (description.warnings) |warning| {
                self.allocator.free(warning);
            }
            self.allocator.free(description.warnings);

            description.warnings = try warning_strings.toOwnedSlice();

            // Reduce confidence based on validation issues
            const confidence_penalty = @as(f32, @floatFromInt(warnings.items.len)) * 0.15;
            description.confidence = @max(0.1, description.confidence - confidence_penalty);
        }
    }

    fn validateSoilStrengthDescriptors(
        self: *Validator,
        warnings: *std.ArrayList(ValidationWarning),
        soil_type: SoilType,
        consistency: ?Consistency,
        density: ?Density,
    ) !bool {
        var has_invalidating_error = false;

        if (soil_type.isCohesive()) {
            // Cohesive soils (clay/silt) should have consistency, not density
            if (consistency == null) {
                const warning = try ValidationWarning.init(
                    self.allocator,
                    .cohesive_soil_missing_consistency,
                    .high,
                );
                try warnings.append(warning);
            }

            if (density != null) {
                const warning = try ValidationWarning.init(
                    self.allocator,
                    .invalid_density_soil_combination,
                    .high,
                );
                try warnings.append(warning);
                has_invalidating_error = true;
            }
        } else if (soil_type.isGranular()) {
            // Granular soils (sand/gravel) should have density, not consistency
            if (density == null) {
                const warning = try ValidationWarning.init(
                    self.allocator,
                    .granular_soil_missing_density,
                    .high,
                );
                try warnings.append(warning);
            }

            if (consistency != null) {
                const warning = try ValidationWarning.init(
                    self.allocator,
                    .invalid_consistency_soil_combination,
                    .high,
                );
                try warnings.append(warning);
                has_invalidating_error = true;
            }
        }

        return has_invalidating_error;
    }

    fn validateMaterialClassification(
        self: *Validator,
        warnings: *std.ArrayList(ValidationWarning),
        description: *SoilDescription,
    ) !bool {
        // Check if a description contains obvious soil types but was classified as rock
        if (description.material_type == .rock) {
            // Check raw description for soil type keywords
            const raw_lower = std.ascii.allocLowerString(self.allocator, description.raw_description) catch return false;
            defer self.allocator.free(raw_lower);

            const soil_keywords = [_][]const u8{ "clay", "silt", "sand", "gravel", "peat", "organic" };
            for (soil_keywords) |keyword| {
                if (std.mem.indexOf(u8, raw_lower, keyword)) |_| {
                    const warning = try ValidationWarning.init(
                        self.allocator,
                        .soil_material_classified_as_rock,
                        .high,
                    );
                    try warnings.append(warning);
                    return true;
                }
            }
        }

        return false;
    }

    fn validatePlasticityDescriptors(
        self: *Validator,
        warnings: *std.ArrayList(ValidationWarning),
        soil_type: SoilType,
        plasticity: ?types.PlasticityIndex,
    ) !bool {
        if (plasticity == null) return false;

        // Plasticity descriptors should only be used with cohesive soils
        if (soil_type.isGranular()) {
            const warning = try ValidationWarning.init(
                self.allocator,
                .invalid_plasticity_granular_soil,
                .high,
            );
            try warnings.append(warning);
            return true;
        }

        return false;
    }

    fn validateRockPropertiesOnSoil(
        self: *Validator,
        warnings: *std.ArrayList(ValidationWarning),
        description: *SoilDescription,
    ) !bool {
        var has_invalidating_error = false;

        // Check if rock strength descriptors are used with soil
        if (description.rock_strength != null) {
            const warning = try ValidationWarning.init(
                self.allocator,
                .invalid_strength_material_combination,
                .high,
            );
            try warnings.append(warning);
            has_invalidating_error = true;
        }

        return has_invalidating_error;
    }

    pub fn isValidCohesiveSoilDescription(soil_type: SoilType, consistency: ?Consistency) bool {
        if (!soil_type.isCohesive()) return true;
        return consistency != null;
    }

    pub fn isValidGranularSoilDescription(soil_type: SoilType, density: ?Density) bool {
        if (!soil_type.isGranular()) return true;
        return density != null;
    }

    pub fn getSuggestedStrengthDescriptor(soil_type: SoilType) ?[]const u8 {
        if (soil_type.isCohesive()) {
            return "consistency descriptor (very soft, soft, firm, stiff, very stiff, hard)";
        } else if (soil_type.isGranular()) {
            return "density descriptor (very loose, loose, medium dense, dense, very dense)";
        }
        return null;
    }
};

// Tests
test "validate cohesive soil with consistency" {
    const allocator = std.testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "Firm CLAY"),
        .material_type = .soil,
        .primary_soil_type = .clay,
        .consistency = .firm,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    try std.testing.expect(description.warnings.len == 0);
    try std.testing.expect(description.confidence == 1.0);
}

test "validate cohesive soil missing consistency" {
    const allocator = std.testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "CLAY"),
        .material_type = .soil,
        .primary_soil_type = .clay,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    try std.testing.expect(description.warnings.len == 1);
    try std.testing.expect(description.confidence < 1.0);
    try std.testing.expect(std.mem.indexOf(u8, description.warnings[0], "consistency descriptor") != null);
}

test "validate cohesive soil with density" {
    const allocator = std.testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "Dense CLAY"),
        .material_type = .soil,
        .primary_soil_type = .clay,
        .density = .dense,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    try std.testing.expect(description.warnings.len == 2); // Missing consistency + has density
    try std.testing.expect(description.confidence < 1.0);
}

test "validate granular soil with density" {
    const allocator = std.testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "Dense SAND"),
        .material_type = .soil,
        .primary_soil_type = .sand,
        .density = .dense,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    try std.testing.expect(description.warnings.len == 0);
    try std.testing.expect(description.confidence == 1.0);
}

test "validate granular soil missing density" {
    const allocator = std.testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "SAND"),
        .material_type = .soil,
        .primary_soil_type = .sand,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    try std.testing.expect(description.warnings.len == 1);
    try std.testing.expect(description.confidence < 1.0);
    try std.testing.expect(std.mem.indexOf(u8, description.warnings[0], "density descriptor") != null);
}

test "validate granular soil with consistency" {
    const allocator = std.testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "Firm SAND"),
        .material_type = .soil,
        .primary_soil_type = .sand,
        .consistency = .firm,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    try std.testing.expect(description.warnings.len == 2); // Missing density + has consistency
    try std.testing.expect(description.confidence < 1.0);
}

test "validation helper functions" {
    try std.testing.expect(Validator.isValidCohesiveSoilDescription(.clay, .firm));
    try std.testing.expect(!Validator.isValidCohesiveSoilDescription(.clay, null));
    try std.testing.expect(Validator.isValidCohesiveSoilDescription(.sand, null)); // Not cohesive

    try std.testing.expect(Validator.isValidGranularSoilDescription(.sand, .dense));
    try std.testing.expect(!Validator.isValidGranularSoilDescription(.sand, null));
    try std.testing.expect(Validator.isValidGranularSoilDescription(.clay, null)); // Not granular

    const clay_suggestion = Validator.getSuggestedStrengthDescriptor(.clay);
    try std.testing.expect(clay_suggestion != null);
    try std.testing.expect(std.mem.indexOf(u8, clay_suggestion.?, "consistency") != null);

    const sand_suggestion = Validator.getSuggestedStrengthDescriptor(.sand);
    try std.testing.expect(sand_suggestion != null);
    try std.testing.expect(std.mem.indexOf(u8, sand_suggestion.?, "density") != null);
}
