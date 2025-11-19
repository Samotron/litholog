const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

const SoilDescription = parser.SoilDescription;
const MaterialType = parser.MaterialType;
const Consistency = parser.Consistency;
const Density = parser.Density;
const SoilType = parser.SoilType;
const RockType = parser.RockType;
const RockStrength = parser.RockStrength;
const SecondaryConstituent = parser.SecondaryConstituent;

test "generator: generate simple cohesive soil" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .soil,
        .consistency = .firm,
        .primary_soil_type = .clay,
    };

    const generated = try parser.generate(desc, allocator);
    defer allocator.free(generated);

    try testing.expect(std.mem.indexOf(u8, generated, "firm") != null);
    try testing.expect(std.mem.indexOf(u8, generated, "CLAY") != null);
}

test "generator: generate simple granular soil" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .soil,
        .density = .dense,
        .primary_soil_type = .sand,
    };

    const generated = try parser.generate(desc, allocator);
    defer allocator.free(generated);

    try testing.expect(std.mem.indexOf(u8, generated, "dense") != null);
    try testing.expect(std.mem.indexOf(u8, generated, "SAND") != null);
}

test "generator: generate simple rock" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .rock,
        .rock_strength = .strong,
        .primary_rock_type = .limestone,
    };

    const generated = try parser.generate(desc, allocator);
    defer allocator.free(generated);

    try testing.expect(std.mem.indexOf(u8, generated, "strong") != null);
    try testing.expect(std.mem.indexOf(u8, generated, "LIMESTONE") != null);
}

test "generator: generateConcise is shorter" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .soil,
        .consistency = .firm,
        .primary_soil_type = .clay,
    };

    const generated = try parser.generate(desc, allocator);
    defer allocator.free(generated);

    const concise = try parser.generateConcise(desc, allocator);
    defer allocator.free(concise);

    try testing.expect(concise.len <= generated.len);
}

test "generator: generateBS5930 format" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .soil,
        .consistency = .firm,
        .primary_soil_type = .clay,
    };

    const generated = try parser.generateBS5930(desc, allocator);
    defer allocator.free(generated);

    try testing.expect(generated.len > 0);
    try testing.expect(std.mem.indexOf(u8, generated, "firm") != null);
}

test "generator: generateFromProperties - cohesive soil" {
    const allocator = testing.allocator;

    const generated = try parser.generateFromProperties(
        allocator,
        .soil,
        .{ .soil = .clay },
        .{ .consistency = .firm },
        null,
    );
    defer allocator.free(generated);

    try testing.expect(std.mem.indexOf(u8, generated, "firm") != null);
    try testing.expect(std.mem.indexOf(u8, generated, "CLAY") != null);
}

test "generator: generateFromProperties - granular soil" {
    const allocator = testing.allocator;

    const generated = try parser.generateFromProperties(
        allocator,
        .soil,
        .{ .soil = .sand },
        .{ .density = .dense },
        null,
    );
    defer allocator.free(generated);

    try testing.expect(std.mem.indexOf(u8, generated, "dense") != null);
    try testing.expect(std.mem.indexOf(u8, generated, "SAND") != null);
}

test "generator: generateFromProperties - with constituents" {
    const allocator = testing.allocator;

    const constituents = [_]SecondaryConstituent{
        .{ .amount = "slightly", .soil_type = "sandy" },
    };

    const generated = try parser.generateFromProperties(
        allocator,
        .soil,
        .{ .soil = .clay },
        .{ .consistency = .firm },
        &constituents,
    );
    defer allocator.free(generated);

    try testing.expect(std.mem.indexOf(u8, generated, "firm") != null);
    try testing.expect(std.mem.indexOf(u8, generated, "sandy") != null);
    try testing.expect(std.mem.indexOf(u8, generated, "CLAY") != null);
}

test "generator: generateFromProperties - rock" {
    const allocator = testing.allocator;

    const generated = try parser.generateFromProperties(
        allocator,
        .rock,
        .{ .rock = .limestone },
        .{ .rock_strength = .strong },
        null,
    );
    defer allocator.free(generated);

    try testing.expect(std.mem.indexOf(u8, generated, "strong") != null);
    try testing.expect(std.mem.indexOf(u8, generated, "LIMESTONE") != null);
}

test "generator: generateRandom produces valid description" {
    const allocator = testing.allocator;

    const generated = try parser.generateRandom(allocator, 12345);
    defer allocator.free(generated);

    try testing.expect(generated.len > 0);
    // Should contain some recognizable terms
    const has_valid_content =
        std.mem.indexOf(u8, generated, "CLAY") != null or
        std.mem.indexOf(u8, generated, "SAND") != null or
        std.mem.indexOf(u8, generated, "SILT") != null or
        std.mem.indexOf(u8, generated, "GRAVEL") != null or
        std.mem.indexOf(u8, generated, "LIMESTONE") != null or
        std.mem.indexOf(u8, generated, "SANDSTONE") != null;
    try testing.expect(has_valid_content);
}

test "generator: generateRandom with different seeds produces different results" {
    const allocator = testing.allocator;

    const gen1 = try parser.generateRandom(allocator, 12345);
    defer allocator.free(gen1);

    const gen2 = try parser.generateRandom(allocator, 67890);
    defer allocator.free(gen2);

    // Different seeds should produce different results (statistically likely)
    try testing.expect(!std.mem.eql(u8, gen1, gen2));
}

test "generator: generateVariations for cohesive soil" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .soil,
        .consistency = .firm,
        .primary_soil_type = .clay,
    };

    const variations = try parser.generateVariations(desc, allocator);
    defer {
        for (variations) |v| allocator.free(v);
        allocator.free(variations);
    }

    // Should have multiple variations (one for each consistency level)
    try testing.expect(variations.len >= 4);

    // Each should contain CLAY
    for (variations) |v| {
        try testing.expect(std.mem.indexOf(u8, v, "CLAY") != null);
    }
}

test "generator: generateVariations for granular soil" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .soil,
        .density = .dense,
        .primary_soil_type = .sand,
    };

    const variations = try parser.generateVariations(desc, allocator);
    defer {
        for (variations) |v| allocator.free(v);
        allocator.free(variations);
    }

    // Should have multiple variations (one for each density level)
    try testing.expect(variations.len >= 4);

    // Each should contain SAND
    for (variations) |v| {
        try testing.expect(std.mem.indexOf(u8, v, "SAND") != null);
    }
}

test "generator: generateVariations for rock" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .rock,
        .rock_strength = .strong,
        .primary_rock_type = .limestone,
    };

    const variations = try parser.generateVariations(desc, allocator);
    defer {
        for (variations) |v| allocator.free(v);
        allocator.free(variations);
    }

    // Should have multiple variations (one for each strength level)
    try testing.expect(variations.len >= 5);

    // Each should contain LIMESTONE
    for (variations) |v| {
        try testing.expect(std.mem.indexOf(u8, v, "LIMESTONE") != null);
    }
}

test "generator: generateLabel for soil" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .soil,
        .consistency = .firm,
        .primary_soil_type = .clay,
    };

    const label = try parser.generateLabel(desc, allocator);
    defer allocator.free(label);

    try testing.expectEqualStrings("CLAY", label);
}

test "generator: generateLabel for rock" {
    const allocator = testing.allocator;

    const desc = SoilDescription{
        .raw_description = "test",
        .material_type = .rock,
        .rock_strength = .strong,
        .primary_rock_type = .limestone,
    };

    const label = try parser.generateLabel(desc, allocator);
    defer allocator.free(label);

    try testing.expectEqualStrings("LIMESTONE", label);
}
