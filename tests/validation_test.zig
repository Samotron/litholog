const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

const Validator = parser.Validator;
const SoilDescription = parser.SoilDescription;
const MaterialType = parser.MaterialType;
const Consistency = parser.Consistency;
const Density = parser.Density;
const SoilType = parser.SoilType;

test "validation: cohesive soil with consistency is valid" {
    const allocator = testing.allocator;
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
    try testing.expect(description.is_valid);
    try testing.expectEqual(@as(usize, 0), description.warnings.len);
}

test "validation: cohesive soil missing consistency" {
    const allocator = testing.allocator;
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
    try testing.expect(description.warnings.len > 0);
    try testing.expect(description.confidence < 1.0);
}

test "validation: cohesive soil with density is invalid" {
    const allocator = testing.allocator;
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
    try testing.expect(!description.is_valid);
    try testing.expect(description.warnings.len >= 1);
}

test "validation: granular soil with density is valid" {
    const allocator = testing.allocator;
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
    try testing.expect(description.is_valid);
    try testing.expectEqual(@as(usize, 0), description.warnings.len);
}

test "validation: granular soil missing density" {
    const allocator = testing.allocator;
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
    try testing.expect(description.warnings.len > 0);
    try testing.expect(description.confidence < 1.0);
}

test "validation: granular soil with consistency is invalid" {
    const allocator = testing.allocator;
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
    try testing.expect(!description.is_valid);
    try testing.expect(description.warnings.len >= 1);
}

test "validation: plasticity on granular soil is invalid" {
    const allocator = testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "Dense high plasticity SAND"),
        .material_type = .soil,
        .primary_soil_type = .sand,
        .density = .dense,
        .plasticity_index = .high_plasticity,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    try testing.expect(!description.is_valid);
    try testing.expect(description.warnings.len >= 1);
}

test "validation: rock strength on soil is invalid" {
    const allocator = testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "Strong CLAY"),
        .material_type = .soil,
        .primary_soil_type = .clay,
        .rock_strength = .strong,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    try testing.expect(!description.is_valid);
    try testing.expect(description.warnings.len >= 1);
}

test "validation: confidence penalty for warnings" {
    const allocator = testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "CLAY"),
        .material_type = .soil,
        .primary_soil_type = .clay,
        .confidence = 1.0,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    // Should have reduced confidence due to missing consistency
    try testing.expect(description.confidence < 1.0);
}

test "validation: multiple warnings compound" {
    const allocator = testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "Dense CLAY"),
        .material_type = .soil,
        .primary_soil_type = .clay,
        .density = .dense,
        .confidence = 1.0,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    // Should have multiple warnings (missing consistency + has density)
    try testing.expect(description.warnings.len >= 2);
    try testing.expect(!description.is_valid);
}

test "validation: helper - isValidCohesiveSoilDescription" {
    try testing.expect(Validator.isValidCohesiveSoilDescription(.clay, .firm));
    try testing.expect(Validator.isValidCohesiveSoilDescription(.silt, .stiff));
    try testing.expect(!Validator.isValidCohesiveSoilDescription(.clay, null));
    try testing.expect(!Validator.isValidCohesiveSoilDescription(.silt, null));
    // Non-cohesive soils should return true (not applicable)
    try testing.expect(Validator.isValidCohesiveSoilDescription(.sand, null));
    try testing.expect(Validator.isValidCohesiveSoilDescription(.gravel, null));
}

test "validation: helper - isValidGranularSoilDescription" {
    try testing.expect(Validator.isValidGranularSoilDescription(.sand, .dense));
    try testing.expect(Validator.isValidGranularSoilDescription(.gravel, .loose));
    try testing.expect(!Validator.isValidGranularSoilDescription(.sand, null));
    try testing.expect(!Validator.isValidGranularSoilDescription(.gravel, null));
    // Non-granular soils should return true (not applicable)
    try testing.expect(Validator.isValidGranularSoilDescription(.clay, null));
    try testing.expect(Validator.isValidGranularSoilDescription(.silt, null));
}

test "validation: helper - getSuggestedStrengthDescriptor" {
    const clay_suggestion = Validator.getSuggestedStrengthDescriptor(.clay);
    try testing.expect(clay_suggestion != null);
    try testing.expect(std.mem.indexOf(u8, clay_suggestion.?, "consistency") != null);

    const silt_suggestion = Validator.getSuggestedStrengthDescriptor(.silt);
    try testing.expect(silt_suggestion != null);
    try testing.expect(std.mem.indexOf(u8, silt_suggestion.?, "consistency") != null);

    const sand_suggestion = Validator.getSuggestedStrengthDescriptor(.sand);
    try testing.expect(sand_suggestion != null);
    try testing.expect(std.mem.indexOf(u8, sand_suggestion.?, "density") != null);

    const gravel_suggestion = Validator.getSuggestedStrengthDescriptor(.gravel);
    try testing.expect(gravel_suggestion != null);
    try testing.expect(std.mem.indexOf(u8, gravel_suggestion.?, "density") != null);
}

test "validation: rock description is valid" {
    const allocator = testing.allocator;
    var validator = Validator.init(allocator);

    var description = SoilDescription{
        .raw_description = try allocator.dupe(u8, "Strong LIMESTONE"),
        .material_type = .rock,
        .primary_rock_type = .limestone,
        .rock_strength = .strong,
    };
    defer {
        allocator.free(description.raw_description);
        for (description.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(description.warnings);
    }

    try validator.validate(&description);
    try testing.expect(description.is_valid);
    try testing.expectEqual(@as(usize, 0), description.warnings.len);
}

test "validation: all consistency levels validate correctly" {
    const allocator = testing.allocator;
    var validator = Validator.init(allocator);

    const consistencies = [_]Consistency{
        .very_soft,
        .soft,
        .firm,
        .stiff,
        .very_stiff,
        .hard,
        .soft_to_firm,
        .firm_to_stiff,
        .stiff_to_very_stiff,
    };

    for (consistencies) |consistency| {
        var description = SoilDescription{
            .raw_description = try allocator.dupe(u8, "Test CLAY"),
            .material_type = .soil,
            .primary_soil_type = .clay,
            .consistency = consistency,
        };
        defer {
            allocator.free(description.raw_description);
            for (description.warnings) |warning| {
                allocator.free(warning);
            }
            allocator.free(description.warnings);
        }

        try validator.validate(&description);
        try testing.expect(description.is_valid);
    }
}

test "validation: all density levels validate correctly" {
    const allocator = testing.allocator;
    var validator = Validator.init(allocator);

    const densities = [_]Density{
        .very_loose,
        .loose,
        .medium_dense,
        .dense,
        .very_dense,
    };

    for (densities) |density| {
        var description = SoilDescription{
            .raw_description = try allocator.dupe(u8, "Test SAND"),
            .material_type = .soil,
            .primary_soil_type = .sand,
            .density = density,
        };
        defer {
            allocator.free(description.raw_description);
            for (description.warnings) |warning| {
                allocator.free(warning);
            }
            allocator.free(description.warnings);
        }

        try validator.validate(&description);
        try testing.expect(description.is_valid);
    }
}
