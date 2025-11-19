const std = @import("std");
const types = @import("types.zig");
const strength_db = @import("strength_db.zig");
const Random = std.Random;

const SoilDescription = types.SoilDescription;
const MaterialType = types.MaterialType;
const SoilType = types.SoilType;
const RockType = types.RockType;
const Consistency = types.Consistency;
const Density = types.Density;
const RockStrength = types.RockStrength;
const WeatheringGrade = types.WeatheringGrade;
const RockStructure = types.RockStructure;
const SecondaryConstituent = types.SecondaryConstituent;

/// Generate a human-readable geological description from a SoilDescription struct
pub fn generate(desc: SoilDescription, allocator: std.mem.Allocator) ![]u8 {
    var parts = std.ArrayList([]const u8).init(allocator);
    defer parts.deinit();

    switch (desc.material_type) {
        .soil => {
            // Add consistency or density
            if (desc.consistency) |consistency| {
                try parts.append(consistency.toString());
            } else if (desc.density) |density| {
                try parts.append(density.toString());
            }

            // Add secondary constituents
            for (desc.secondary_constituents) |sc| {
                try parts.append(sc.amount);
                try parts.append(sc.soil_type);
            }

            // Add particle size
            if (desc.particle_size) |ps| {
                try parts.append(ps.toString());
            }

            // Add primary soil type
            if (desc.primary_soil_type) |pst| {
                try parts.append(pst.toString());
            }
        },
        .rock => {
            // Add rock strength
            if (desc.rock_strength) |rs| {
                try parts.append(rs.toString());
            }

            // Add weathering
            if (desc.weathering_grade) |wg| {
                const weathering_str = try std.fmt.allocPrint(allocator, "{s} weathered", .{wg.toString()});
                try parts.append(weathering_str);
            }

            // Add structure
            if (desc.rock_structure) |rs| {
                try parts.append(rs.toString());
            }

            // Add primary rock type
            if (desc.primary_rock_type) |prt| {
                try parts.append(prt.toString());
            }
        },
    }

    // Join all parts with spaces
    return try std.mem.join(allocator, " ", parts.items);
}

/// Generate a concise description (minimal formatting)
pub fn generateConcise(desc: SoilDescription, allocator: std.mem.Allocator) ![]u8 {
    var parts = std.ArrayList([]const u8).init(allocator);
    defer parts.deinit();

    switch (desc.material_type) {
        .soil => {
            if (desc.consistency) |c| {
                try parts.append(c.toString());
            } else if (desc.density) |d| {
                try parts.append(d.toString());
            }

            if (desc.primary_soil_type) |pst| {
                try parts.append(pst.toString());
            }
        },
        .rock => {
            if (desc.rock_strength) |rs| {
                try parts.append(rs.toString());
            }

            if (desc.primary_rock_type) |prt| {
                try parts.append(prt.toString());
            }
        },
    }

    return try std.mem.join(allocator, " ", parts.items);
}

/// Generate a verbose description with all available information
pub fn generateVerbose(desc: SoilDescription, allocator: std.mem.Allocator) ![]u8 {
    var parts = std.ArrayList([]const u8).init(allocator);
    defer parts.deinit();

    // Add color if present
    if (desc.color) |color| {
        try parts.append(color.toString());
    }

    // Add moisture content
    if (desc.moisture_content) |moisture| {
        try parts.append(moisture.toString());
    }

    switch (desc.material_type) {
        .soil => {
            // Add consistency or density
            if (desc.consistency) |consistency| {
                try parts.append(consistency.toString());
            } else if (desc.density) |density| {
                try parts.append(density.toString());
            }

            // Add plasticity
            if (desc.plasticity_index) |plasticity| {
                const plasticity_str = try std.fmt.allocPrint(allocator, "{s}", .{plasticity.toString()});
                try parts.append(plasticity_str);
            }

            // Add secondary constituents
            for (desc.secondary_constituents) |sc| {
                try parts.append(sc.amount);
                try parts.append(sc.soil_type);
            }

            // Add particle size
            if (desc.particle_size) |ps| {
                try parts.append(ps.toString());
            }

            // Add primary soil type
            if (desc.primary_soil_type) |pst| {
                try parts.append(pst.toString());
            }
        },
        .rock => {
            // Add rock strength
            if (desc.rock_strength) |rs| {
                try parts.append(rs.toString());
            }

            // Add weathering
            if (desc.weathering_grade) |wg| {
                const weathering_str = try std.fmt.allocPrint(allocator, "{s} weathered", .{wg.toString()});
                try parts.append(weathering_str);
            }

            // Add structure
            if (desc.rock_structure) |rs| {
                try parts.append(rs.toString());
            }

            // Add primary rock type
            if (desc.primary_rock_type) |prt| {
                try parts.append(prt.toString());
            }
        },
    }

    return try std.mem.join(allocator, " ", parts.items);
}

/// Generate description with BS5930 standard formatting
pub fn generateBS5930(desc: SoilDescription, allocator: std.mem.Allocator) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    var writer = result.writer();

    // BS5930 format: [Consistency/Density] [Secondary constituents] PRIMARY TYPE

    switch (desc.material_type) {
        .soil => {
            // State and consistency/density
            if (desc.consistency) |c| {
                try writer.print("{s} ", .{c.toString()});
            } else if (desc.density) |d| {
                try writer.print("{s} ", .{d.toString()});
            }

            // Secondary constituents in order
            for (desc.secondary_constituents) |sc| {
                try writer.print("{s} {s} ", .{ sc.amount, sc.soil_type });
            }

            // Primary type (capitalized)
            if (desc.primary_soil_type) |pst| {
                try writer.print("{s}", .{pst.toString()});
            }
        },
        .rock => {
            // Strength
            if (desc.rock_strength) |rs| {
                try writer.print("{s} ", .{rs.toString()});
            }

            // Weathering state
            if (desc.weathering_grade) |wg| {
                try writer.print("{s} weathered ", .{wg.toString()});
            }

            // Structure
            if (desc.rock_structure) |rs| {
                try writer.print("{s} ", .{rs.toString()});
            }

            // Primary rock type (capitalized)
            if (desc.primary_rock_type) |prt| {
                try writer.print("{s}", .{prt.toString()});
            }
        },
    }

    return result.toOwnedSlice();
}

test "generate simple soil description" {
    const allocator = std.testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .soil,
        .consistency = .firm,
        .primary_soil_type = .clay,
    };

    const generated = try generate(desc, allocator);
    defer allocator.free(generated);

    try std.testing.expect(std.mem.indexOf(u8, generated, "firm") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "CLAY") != null);
}

test "generate rock description" {
    const allocator = std.testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .rock,
        .rock_strength = .strong,
        .primary_rock_type = .limestone,
    };

    const generated = try generate(desc, allocator);
    defer allocator.free(generated);

    try std.testing.expect(std.mem.indexOf(u8, generated, "strong") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "LIMESTONE") != null);
}

test "generate concise description" {
    const allocator = std.testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .soil,
        .consistency = .stiff,
        .primary_soil_type = .clay,
    };

    const generated = try generateConcise(desc, allocator);
    defer allocator.free(generated);

    // Concise should be shorter
    try std.testing.expect(generated.len < 30);
}

// ============================================================================
// Advanced Generation Functions
// ============================================================================

/// Generate description from explicit properties
pub fn generateFromProperties(
    allocator: std.mem.Allocator,
    material_type: MaterialType,
    primary_type: union(enum) { soil: SoilType, rock: RockType },
    strength: ?union(enum) { consistency: Consistency, density: Density, rock_strength: RockStrength },
    constituents: ?[]const SecondaryConstituent,
) ![]u8 {
    const raw_desc = "generated";

    var desc = SoilDescription{
        .raw_description = raw_desc,
        .material_type = material_type,
    };

    // Allocate constituents if provided
    if (constituents) |c| {
        desc.secondary_constituents = try allocator.dupe(SecondaryConstituent, c);
    }
    defer if (constituents != null) allocator.free(desc.secondary_constituents);

    switch (material_type) {
        .soil => {
            desc.primary_soil_type = primary_type.soil;
            if (strength) |s| {
                switch (s) {
                    .consistency => |c| desc.consistency = c,
                    .density => |d| desc.density = d,
                    else => {},
                }
            }
        },
        .rock => {
            desc.primary_rock_type = primary_type.rock;
            if (strength) |s| {
                switch (s) {
                    .rock_strength => |rs| desc.rock_strength = rs,
                    else => {},
                }
            }
        },
    }

    return try generate(desc, allocator);
}

/// Generate random valid soil description
pub fn generateRandom(allocator: std.mem.Allocator, seed: u64) ![]u8 {
    var prng = Random.DefaultPrng.init(seed);
    const random = prng.random();

    const material_type = if (random.boolean()) MaterialType.soil else MaterialType.rock;

    const raw_desc = "random";
    var desc = SoilDescription{
        .raw_description = raw_desc,
        .material_type = material_type,
    };

    switch (material_type) {
        .soil => {
            // Random soil type
            const soil_types = [_]SoilType{ .clay, .silt, .sand, .gravel };
            desc.primary_soil_type = soil_types[random.intRangeAtMost(usize, 0, soil_types.len - 1)];

            // Random strength descriptor based on soil type
            if (desc.primary_soil_type.?.isCohesive()) {
                const consistencies = [_]Consistency{ .soft, .firm, .stiff, .very_stiff };
                desc.consistency = consistencies[random.intRangeAtMost(usize, 0, consistencies.len - 1)];
            } else {
                const densities = [_]Density{ .loose, .medium_dense, .dense };
                desc.density = densities[random.intRangeAtMost(usize, 0, densities.len - 1)];
            }

            // Maybe add a secondary constituent
            if (random.boolean()) {
                const constituents = try allocator.alloc(SecondaryConstituent, 1);
                const amounts = [_][]const u8{ "slightly", "moderately", "very" };
                const types_str = [_][]const u8{ "sandy", "silty", "clayey", "gravelly" };
                constituents[0] = SecondaryConstituent{
                    .amount = amounts[random.intRangeAtMost(usize, 0, amounts.len - 1)],
                    .soil_type = types_str[random.intRangeAtMost(usize, 0, types_str.len - 1)],
                };
                desc.secondary_constituents = constituents;
            }
        },
        .rock => {
            // Random rock type
            const rock_types = [_]RockType{ .limestone, .sandstone, .mudstone, .granite };
            desc.primary_rock_type = rock_types[random.intRangeAtMost(usize, 0, rock_types.len - 1)];

            // Random rock strength
            const strengths = [_]RockStrength{ .weak, .moderately_weak, .moderately_strong, .strong };
            desc.rock_strength = strengths[random.intRangeAtMost(usize, 0, strengths.len - 1)];
        },
    }

    const result = try generate(desc, allocator);

    // Clean up allocated constituents
    if (desc.secondary_constituents.len > 0) {
        allocator.free(desc.secondary_constituents);
    }

    return result;
}

/// Generate variations of a description with different strength descriptors
pub fn generateVariations(desc: SoilDescription, allocator: std.mem.Allocator) ![][]u8 {
    var variations = std.ArrayList([]u8).init(allocator);
    errdefer {
        for (variations.items) |v| allocator.free(v);
        variations.deinit();
    }

    switch (desc.material_type) {
        .soil => {
            if (desc.primary_soil_type) |soil_type| {
                if (soil_type.isCohesive()) {
                    // Generate variations with different consistencies
                    const consistencies = [_]Consistency{ .soft, .firm, .stiff, .very_stiff };
                    for (consistencies) |consistency| {
                        var variant = desc;
                        variant.consistency = consistency;
                        const generated = try generate(variant, allocator);
                        try variations.append(generated);
                    }
                } else if (soil_type.isGranular()) {
                    // Generate variations with different densities
                    const densities = [_]Density{ .loose, .medium_dense, .dense, .very_dense };
                    for (densities) |density| {
                        var variant = desc;
                        variant.density = density;
                        const generated = try generate(variant, allocator);
                        try variations.append(generated);
                    }
                }
            }
        },
        .rock => {
            // Generate variations with different rock strengths
            const strengths = [_]RockStrength{ .weak, .moderately_weak, .moderately_strong, .strong, .very_strong };
            for (strengths) |strength| {
                var variant = desc;
                variant.rock_strength = strength;
                const generated = try generate(variant, allocator);
                try variations.append(generated);
            }
        },
    }

    return variations.toOwnedSlice();
}

/// Generate description with strength parameters included
pub fn generateWithStrength(desc: SoilDescription, allocator: std.mem.Allocator) ![]u8 {
    const base = try generate(desc, allocator);
    defer allocator.free(base);

    if (desc.strength_parameters) |params| {
        const with_strength = try std.fmt.allocPrint(
            allocator,
            "{s} ({s}: {d:.1}-{d:.1} {s})",
            .{
                base,
                params.parameter_type.toString(),
                params.range.lower_bound,
                params.range.upper_bound,
                params.parameter_type.getUnits(),
            },
        );
        return with_strength;
    }

    // If no strength parameters, just return base
    return try allocator.dupe(u8, base);
}

/// Generate simplified description suitable for labels or summaries
pub fn generateLabel(desc: SoilDescription, allocator: std.mem.Allocator) ![]u8 {
    switch (desc.material_type) {
        .soil => {
            if (desc.primary_soil_type) |pst| {
                return try allocator.dupe(u8, pst.toString());
            }
        },
        .rock => {
            if (desc.primary_rock_type) |prt| {
                return try allocator.dupe(u8, prt.toString());
            }
        },
    }

    return try allocator.dupe(u8, "Unknown");
}
