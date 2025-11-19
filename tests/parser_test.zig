const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

const Parser = parser.Parser;
const SoilDescription = parser.SoilDescription;
const MaterialType = parser.MaterialType;
const Consistency = parser.Consistency;
const Density = parser.Density;
const SoilType = parser.SoilType;
const RockType = parser.RockType;
const RockStrength = parser.RockStrength;
const WeatheringGrade = parser.WeatheringGrade;
const RockStructure = parser.RockStructure;

test "parser: parse simple cohesive soil" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm CLAY");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
    try testing.expect(result.consistency != null);
    try testing.expectEqual(Consistency.firm, result.consistency.?);
    try testing.expect(result.primary_soil_type != null);
    try testing.expectEqual(SoilType.clay, result.primary_soil_type.?);
}

test "parser: parse simple granular soil" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Dense SAND");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
    try testing.expect(result.density != null);
    try testing.expectEqual(Density.dense, result.density.?);
    try testing.expect(result.primary_soil_type != null);
    try testing.expectEqual(SoilType.sand, result.primary_soil_type.?);
}

test "parser: parse consistency range" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm to stiff CLAY");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
    try testing.expect(result.consistency != null);
    try testing.expectEqual(Consistency.firm_to_stiff, result.consistency.?);
    try testing.expectEqual(SoilType.clay, result.primary_soil_type.?);
}

test "parser: parse soil with secondary constituents" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm slightly sandy CLAY");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
    try testing.expectEqual(Consistency.firm, result.consistency.?);
    try testing.expectEqual(SoilType.clay, result.primary_soil_type.?);
    try testing.expect(result.secondary_constituents.len > 0);
    try testing.expectEqualStrings("slightly", result.secondary_constituents[0].amount);
    try testing.expectEqualStrings("sandy", result.secondary_constituents[0].soil_type);
}

test "parser: parse soil with multiple secondary constituents" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm slightly sandy slightly gravelly CLAY");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
    try testing.expectEqual(@as(usize, 2), result.secondary_constituents.len);
}

test "parser: parse simple rock" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Strong LIMESTONE");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.rock, result.material_type);
    try testing.expect(result.rock_strength != null);
    try testing.expectEqual(RockStrength.strong, result.rock_strength.?);
    try testing.expect(result.primary_rock_type != null);
    try testing.expectEqual(RockType.limestone, result.primary_rock_type.?);
}

test "parser: parse rock with weathering" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Strong slightly weathered LIMESTONE");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.rock, result.material_type);
    try testing.expectEqual(RockStrength.strong, result.rock_strength.?);
    try testing.expect(result.weathering_grade != null);
    try testing.expectEqual(WeatheringGrade.slightly_weathered, result.weathering_grade.?);
    try testing.expectEqual(RockType.limestone, result.primary_rock_type.?);
}

test "parser: parse rock with structure" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Strong jointed LIMESTONE");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.rock, result.material_type);
    try testing.expectEqual(RockStrength.strong, result.rock_strength.?);
    try testing.expect(result.rock_structure != null);
    try testing.expectEqual(RockStructure.jointed, result.rock_structure.?);
    try testing.expectEqual(RockType.limestone, result.primary_rock_type.?);
}

test "parser: parse complex rock description" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Strong slightly weathered jointed LIMESTONE");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.rock, result.material_type);
    try testing.expectEqual(RockStrength.strong, result.rock_strength.?);
    try testing.expectEqual(WeatheringGrade.slightly_weathered, result.weathering_grade.?);
    try testing.expectEqual(RockStructure.jointed, result.rock_structure.?);
    try testing.expectEqual(RockType.limestone, result.primary_rock_type.?);
}

test "parser: parse all soil types" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const soil_types = [_]struct { desc: []const u8, expected: SoilType }{
        .{ .desc = "Firm CLAY", .expected = .clay },
        .{ .desc = "Firm SILT", .expected = .silt },
        .{ .desc = "Dense SAND", .expected = .sand },
        .{ .desc = "Dense GRAVEL", .expected = .gravel },
        .{ .desc = "Soft PEAT", .expected = .peat },
        .{ .desc = "Firm ORGANIC", .expected = .organic },
    };

    for (soil_types) |test_case| {
        const result = try p.parse(test_case.desc);
        defer result.deinit(allocator);

        try testing.expectEqual(MaterialType.soil, result.material_type);
        try testing.expectEqual(test_case.expected, result.primary_soil_type.?);
    }
}

test "parser: parse all consistency levels" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const consistencies = [_]struct { desc: []const u8, expected: Consistency }{
        .{ .desc = "Very soft CLAY", .expected = .very_soft },
        .{ .desc = "Soft CLAY", .expected = .soft },
        .{ .desc = "Firm CLAY", .expected = .firm },
        .{ .desc = "Stiff CLAY", .expected = .stiff },
        .{ .desc = "Very stiff CLAY", .expected = .very_stiff },
        .{ .desc = "Hard CLAY", .expected = .hard },
    };

    for (consistencies) |test_case| {
        const result = try p.parse(test_case.desc);
        defer result.deinit(allocator);

        try testing.expectEqual(test_case.expected, result.consistency.?);
    }
}

test "parser: parse all density levels" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const densities = [_]struct { desc: []const u8, expected: Density }{
        .{ .desc = "Very loose SAND", .expected = .very_loose },
        .{ .desc = "Loose SAND", .expected = .loose },
        .{ .desc = "Medium dense SAND", .expected = .medium_dense },
        .{ .desc = "Dense SAND", .expected = .dense },
        .{ .desc = "Very dense SAND", .expected = .very_dense },
    };

    for (densities) |test_case| {
        const result = try p.parse(test_case.desc);
        defer result.deinit(allocator);

        try testing.expectEqual(test_case.expected, result.density.?);
    }
}

test "parser: parse all rock types" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const rock_types = [_]struct { desc: []const u8, expected: RockType }{
        .{ .desc = "Strong LIMESTONE", .expected = .limestone },
        .{ .desc = "Strong SANDSTONE", .expected = .sandstone },
        .{ .desc = "Strong MUDSTONE", .expected = .mudstone },
        .{ .desc = "Strong SHALE", .expected = .shale },
        .{ .desc = "Strong GRANITE", .expected = .granite },
        .{ .desc = "Strong BASALT", .expected = .basalt },
    };

    for (rock_types) |test_case| {
        const result = try p.parse(test_case.desc);
        defer result.deinit(allocator);

        try testing.expectEqual(MaterialType.rock, result.material_type);
        try testing.expectEqual(test_case.expected, result.primary_rock_type.?);
    }
}

test "parser: material type detection for soil" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm CLAY");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
}

test "parser: material type detection for rock" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Strong LIMESTONE");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.rock, result.material_type);
}

test "parser: parse with color descriptor" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Brown firm CLAY");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
    try testing.expect(result.color != null);
}

test "parser: parse with moisture content" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Moist firm CLAY");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
    try testing.expect(result.moisture_content != null);
}

test "parser: parse with plasticity index" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm high plasticity CLAY");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
    try testing.expect(result.plasticity_index != null);
}

test "parser: parse with particle size" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Dense fine SAND");
    defer result.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, result.material_type);
    try testing.expect(result.particle_size != null);
}

test "parser: confidence score is set" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm CLAY");
    defer result.deinit(allocator);

    try testing.expect(result.confidence > 0.0);
    try testing.expect(result.confidence <= 1.0);
}

test "parser: raw description is preserved" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const input = "Firm CLAY";
    const result = try p.parse(input);
    defer result.deinit(allocator);

    try testing.expectEqualStrings(input, result.raw_description);
}

test "parser: strength parameters for cohesive soil" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm CLAY");
    defer result.deinit(allocator);

    try testing.expect(result.strength_parameters != null);
    // Firm clay should have cu around 25-50 kPa
    const sp = result.strength_parameters.?;
    try testing.expect(sp.range.lower_bound >= 20);
    try testing.expect(sp.range.upper_bound <= 60);
}

test "parser: strength parameters for granular soil" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Dense SAND");
    defer result.deinit(allocator);

    try testing.expect(result.strength_parameters != null);
    // Dense sand should have SPT-N around 30-50
    const sp = result.strength_parameters.?;
    try testing.expect(sp.range.lower_bound >= 25);
    try testing.expect(sp.range.upper_bound <= 55);
}

test "parser: strength parameters for rock" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Strong LIMESTONE");
    defer result.deinit(allocator);

    try testing.expect(result.strength_parameters != null);
    // Strong rock should have UCS around 50-100 MPa
    const sp = result.strength_parameters.?;
    try testing.expect(sp.range.lower_bound >= 40);
    try testing.expect(sp.range.upper_bound <= 110);
}

test "parser: constituent guidance for secondary constituents" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm slightly sandy CLAY");
    defer result.deinit(allocator);

    try testing.expect(result.constituent_guidance != null);
    const cg = result.constituent_guidance.?;
    try testing.expect(cg.constituents.len > 0);
}

test "parser: validation runs automatically" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("CLAY"); // Missing consistency
    defer result.deinit(allocator);

    // Should have warnings due to missing consistency
    try testing.expect(result.warnings.len > 0);
}

test "parser: case insensitivity" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result1 = try p.parse("Firm CLAY");
    defer result1.deinit(allocator);

    const result2 = try p.parse("firm clay");
    defer result2.deinit(allocator);

    const result3 = try p.parse("FIRM CLAY");
    defer result3.deinit(allocator);

    // All should parse to the same type
    try testing.expectEqual(result1.consistency, result2.consistency);
    try testing.expectEqual(result1.primary_soil_type, result2.primary_soil_type);
    try testing.expectEqual(result1.consistency, result3.consistency);
}

test "parser: whitespace handling" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result1 = try p.parse("Firm CLAY");
    defer result1.deinit(allocator);

    const result2 = try p.parse("  Firm   CLAY  ");
    defer result2.deinit(allocator);

    try testing.expectEqual(result1.consistency, result2.consistency);
    try testing.expectEqual(result1.primary_soil_type, result2.primary_soil_type);
}
