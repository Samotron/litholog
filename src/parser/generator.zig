const std = @import("std");
const types = @import("types.zig");

const SoilDescription = types.SoilDescription;
const MaterialType = types.MaterialType;
const Consistency = types.Consistency;
const Density = types.Density;
const RockStrength = types.RockStrength;
const WeatheringGrade = types.WeatheringGrade;
const RockStructure = types.RockStructure;

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
