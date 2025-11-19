const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

const Parser = parser.Parser;

test "integration: parse all valid descriptions from test file" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const file = try std.fs.cwd().openFile("test_data/valid_descriptions.txt", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var valid_count: usize = 0;
    var total_count: usize = 0;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        total_count += 1;
        const result = p.parse(trimmed) catch continue;
        defer result.deinit(allocator);

        if (result.is_valid) {
            valid_count += 1;
        }
    }

    // At least 80% of valid descriptions should parse as valid
    const success_rate = @as(f32, @floatFromInt(valid_count)) / @as(f32, @floatFromInt(total_count));
    try testing.expect(success_rate >= 0.8);
}

test "integration: parse descriptions from test_descriptions.txt" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const file = try std.fs.cwd().openFile("test_descriptions.txt", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var parse_count: usize = 0;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        const result = p.parse(trimmed) catch continue;
        defer result.deinit(allocator);
        parse_count += 1;
    }

    // Should successfully parse most descriptions
    try testing.expect(parse_count > 0);
}

test "integration: JSON output is valid" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const result = try p.parse("Firm CLAY");
    defer result.deinit(allocator);

    const json = try result.toJson(allocator);
    defer allocator.free(json);

    // Basic JSON validation
    try testing.expect(json.len > 0);
    try testing.expect(json[0] == '{');
    try testing.expect(json[json.len - 1] == '}');
    try testing.expect(std.mem.indexOf(u8, json, "raw_description") != null);
    try testing.expect(std.mem.indexOf(u8, json, "material_type") != null);
}

test "integration: round-trip parse and generate" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const original = "Firm CLAY";
    const result1 = try p.parse(original);
    defer result1.deinit(allocator);

    const generated = try parser.generate(result1, allocator);
    defer allocator.free(generated);

    const result2 = try p.parse(generated);
    defer result2.deinit(allocator);

    // After round-trip, key properties should match
    try testing.expectEqual(result1.material_type, result2.material_type);
    try testing.expectEqual(result1.consistency, result2.consistency);
    try testing.expectEqual(result1.primary_soil_type, result2.primary_soil_type);
}

test "integration: batch processing multiple descriptions" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const descriptions = [_][]const u8{
        "Firm CLAY",
        "Dense SAND",
        "Strong LIMESTONE",
        "Stiff slightly sandy CLAY",
        "Very dense GRAVEL",
    };

    for (descriptions) |desc| {
        const result = try p.parse(desc);
        defer result.deinit(allocator);

        try testing.expect(result.confidence > 0.0);
    }
}

test "integration: complex descriptions parse correctly" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const complex_descriptions = [_][]const u8{
        "Firm to stiff brown moist slightly sandy slightly gravelly CLAY",
        "Very dense gray slightly silty fine to coarse SAND",
        "Strong slightly weathered jointed LIMESTONE",
        "Moderately strong moderately weathered bedded SANDSTONE",
    };

    for (complex_descriptions) |desc| {
        const result = try p.parse(desc);
        defer result.deinit(allocator);

        try testing.expect(result.confidence > 0.5);
        try testing.expect(result.raw_description.len > 0);
    }
}

test "integration: performance - parse 100 descriptions" {
    const allocator = testing.allocator;
    var p = Parser.init(allocator);

    const description = "Firm slightly sandy CLAY";
    var i: usize = 0;

    const start = std.time.milliTimestamp();
    while (i < 100) : (i += 1) {
        const result = try p.parse(description);
        defer result.deinit(allocator);
    }
    const end = std.time.milliTimestamp();

    const elapsed = end - start;
    // Should complete in reasonable time (less than 1 second)
    try testing.expect(elapsed < 1000);
}
