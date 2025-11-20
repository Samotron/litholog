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

test "fromJson: simple soil description" {
    const allocator = testing.allocator;

    const json =
        \\{"material_type":"soil","consistency":"firm","primary_soil_type":"clay"}
    ;

    const desc = try SoilDescription.fromJson(json, allocator);
    defer desc.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, desc.material_type);
    try testing.expectEqual(Consistency.firm, desc.consistency.?);
    try testing.expectEqual(SoilType.clay, desc.primary_soil_type.?);
}

test "fromJson: simple rock description" {
    const allocator = testing.allocator;

    const json =
        \\{"material_type":"rock","rock_strength":"strong","primary_rock_type":"limestone"}
    ;

    const desc = try SoilDescription.fromJson(json, allocator);
    defer desc.deinit(allocator);

    try testing.expectEqual(MaterialType.rock, desc.material_type);
    try testing.expectEqual(RockStrength.strong, desc.rock_strength.?);
    try testing.expectEqual(RockType.limestone, desc.primary_rock_type.?);
}

test "fromJson: with secondary constituents" {
    const allocator = testing.allocator;

    const json =
        \\{"material_type":"soil","consistency":"firm","primary_soil_type":"clay","secondary_constituents":[{"amount":"slightly","soil_type":"sandy"}]}
    ;

    const desc = try SoilDescription.fromJson(json, allocator);
    defer desc.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, desc.material_type);
    try testing.expectEqual(@as(usize, 1), desc.secondary_constituents.len);
    try testing.expectEqualStrings("slightly", desc.secondary_constituents[0].amount);
    try testing.expectEqualStrings("sandy", desc.secondary_constituents[0].soil_type);
}

test "roundtrip: parse -> toJson -> fromJson -> generate" {
    const allocator = testing.allocator;

    const original = "Firm slightly sandy CLAY";

    // Parse original
    var p = parser.Parser.init(allocator);
    const parsed = try p.parse(original);
    defer parsed.deinit(allocator);

    // Convert to JSON
    const json = try parsed.toJson(allocator);
    defer allocator.free(json);

    // Parse JSON back
    const from_json = try SoilDescription.fromJson(json, allocator);
    defer from_json.deinit(allocator);

    // Generate description
    const generated = try parser.generate(from_json, allocator);
    defer allocator.free(generated);

    // Check key properties match
    try testing.expectEqual(parsed.material_type, from_json.material_type);
    try testing.expectEqual(parsed.consistency, from_json.consistency);
    try testing.expectEqual(parsed.primary_soil_type, from_json.primary_soil_type);

    // Generated should contain key terms
    try testing.expect(std.mem.indexOf(u8, generated, "firm") != null);
    try testing.expect(std.mem.indexOf(u8, generated, "CLAY") != null);
}

test "roundtrip: multiple formats" {
    const allocator = testing.allocator;

    const original = "Dense SAND";

    var p = parser.Parser.init(allocator);
    const parsed = try p.parse(original);
    defer parsed.deinit(allocator);

    const json = try parsed.toJson(allocator);
    defer allocator.free(json);

    const from_json = try SoilDescription.fromJson(json, allocator);
    defer from_json.deinit(allocator);

    // Test all formats
    const standard = try parser.generate(from_json, allocator);
    defer allocator.free(standard);

    const concise = try parser.generateConcise(from_json, allocator);
    defer allocator.free(concise);

    const verbose = try parser.generateVerbose(from_json, allocator);
    defer allocator.free(verbose);

    const bs5930 = try parser.generateBS5930(from_json, allocator);
    defer allocator.free(bs5930);

    // All should contain SAND
    try testing.expect(std.mem.indexOf(u8, standard, "SAND") != null);
    try testing.expect(std.mem.indexOf(u8, concise, "SAND") != null);
    try testing.expect(std.mem.indexOf(u8, verbose, "SAND") != null);
    try testing.expect(std.mem.indexOf(u8, bs5930, "SAND") != null);
}

test "fromJson: handles missing optional fields" {
    const allocator = testing.allocator;

    const json =
        \\{"material_type":"soil","primary_soil_type":"clay"}
    ;

    const desc = try SoilDescription.fromJson(json, allocator);
    defer desc.deinit(allocator);

    try testing.expectEqual(MaterialType.soil, desc.material_type);
    try testing.expectEqual(SoilType.clay, desc.primary_soil_type.?);
    try testing.expect(desc.consistency == null);
    try testing.expect(desc.density == null);
}

test "fromJson: confidence and validity" {
    const allocator = testing.allocator;

    const json =
        \\{"material_type":"soil","primary_soil_type":"clay","confidence":0.95,"is_valid":true}
    ;

    const desc = try SoilDescription.fromJson(json, allocator);
    defer desc.deinit(allocator);

    try testing.expectEqual(@as(f32, 0.95), desc.confidence);
    try testing.expect(desc.is_valid);
}
