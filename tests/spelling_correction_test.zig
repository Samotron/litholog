const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

test "spelling correction: simple typo in soil type" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Firm CLAI");
    defer result.deinit(allocator);

    // Should correct CLAI to CLAY
    try testing.expect(result.primary_soil_type != null);
    try testing.expectEqual(parser.SoilType.clay, result.primary_soil_type.?);

    // Should have a spelling correction recorded
    try testing.expect(result.spelling_corrections.len > 0);
    try testing.expectEqualStrings("clai", result.spelling_corrections[0].original);
    try testing.expectEqualStrings("clay", result.spelling_corrections[0].corrected);
}

test "spelling correction: typo in consistency" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Stif CLAY");
    defer result.deinit(allocator);

    // Should correct Stif to stiff
    try testing.expect(result.consistency != null);
    try testing.expectEqual(parser.Consistency.stiff, result.consistency.?);

    // Should have a spelling correction recorded
    try testing.expect(result.spelling_corrections.len > 0);
    try testing.expectEqualStrings("stif", result.spelling_corrections[0].original);
    try testing.expectEqualStrings("stiff", result.spelling_corrections[0].corrected);
}

test "spelling correction: transposition error" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Firn brown CLAY");
    defer result.deinit(allocator);

    // Should correct Firn to firm
    try testing.expect(result.consistency != null);
    try testing.expectEqual(parser.Consistency.firm, result.consistency.?);

    // Should have a spelling correction recorded
    try testing.expect(result.spelling_corrections.len > 0);
    try testing.expectEqualStrings("firn", result.spelling_corrections[0].original);
    try testing.expectEqualStrings("firm", result.spelling_corrections[0].corrected);
}

test "spelling correction: multiple typos in one description" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Stif borwn CLAI");
    defer result.deinit(allocator);

    // Should correct all typos
    try testing.expectEqual(parser.Consistency.stiff, result.consistency.?);
    try testing.expectEqual(parser.SoilType.clay, result.primary_soil_type.?);

    // Should have multiple spelling corrections recorded
    try testing.expect(result.spelling_corrections.len >= 2);
}

test "spelling correction: density typo" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Dens SAND");
    defer result.deinit(allocator);

    // Should correct Dens to dense
    try testing.expect(result.density != null);
    try testing.expectEqual(parser.Density.dense, result.density.?);

    // Should have a spelling correction recorded
    try testing.expect(result.spelling_corrections.len > 0);
}

test "spelling correction: rock type typo" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Strong LIMSTONE");
    defer result.deinit(allocator);

    // Should correct LIMSTONE to limestone
    try testing.expect(result.primary_rock_type != null);
    try testing.expectEqual(parser.RockType.limestone, result.primary_rock_type.?);

    // Should have a spelling correction recorded
    try testing.expect(result.spelling_corrections.len > 0);
    try testing.expectEqualStrings("limstone", result.spelling_corrections[0].original);
    try testing.expectEqualStrings("limestone", result.spelling_corrections[0].corrected);
}

test "spelling correction: adjective typo" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Firm slightly snady CLAY");
    defer result.deinit(allocator);

    // Should correct snady to sandy
    try testing.expect(result.secondary_constituents.len > 0);

    // Should have a spelling correction recorded
    try testing.expect(result.spelling_corrections.len > 0);
}

test "spelling correction: proportion typo" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Firm slighty sandy CLAY");
    defer result.deinit(allocator);

    // Should correct slighty to slightly
    try testing.expect(result.secondary_constituents.len > 0);

    // Should have a spelling correction recorded
    try testing.expect(result.spelling_corrections.len > 0);
}

test "spelling correction: no correction needed for correct spelling" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Firm brown CLAY");
    defer result.deinit(allocator);

    // Should parse correctly
    try testing.expectEqual(parser.Consistency.firm, result.consistency.?);
    try testing.expectEqual(parser.SoilType.clay, result.primary_soil_type.?);

    // Should have NO spelling corrections
    try testing.expectEqual(@as(usize, 0), result.spelling_corrections.len);
}

test "spelling correction: anomaly detection integration" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Firn CLAI");
    defer result.deinit(allocator);

    // Should have spelling corrections
    try testing.expect(result.spelling_corrections.len > 0);

    // Run anomaly detection
    var detector = parser.AnomalyDetector.init(allocator);
    var anomaly_result = try detector.detect(&result);
    defer anomaly_result.deinit(allocator);

    // Should have spelling correction anomalies
    var found_spelling_anomaly = false;
    for (anomaly_result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .spelling_correction) {
            found_spelling_anomaly = true;
            try testing.expectEqual(parser.Severity.low, anomaly.severity);
        }
    }
    try testing.expect(found_spelling_anomaly);
}

test "spelling correction: high similarity threshold" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);

    // "xyz" is too different from "clay" - should not be corrected
    const result = try p.parse("Firm XYZ");
    defer result.deinit(allocator);

    // Should not find a match or should classify as unknown
    // The word "xyz" is too dissimilar to any valid term
    try testing.expect(result.spelling_corrections.len == 0);
}

test "spelling correction: case insensitive" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("FIRN CLAI");
    defer result.deinit(allocator);

    // Should correct regardless of case
    try testing.expect(result.consistency != null);
    try testing.expect(result.primary_soil_type != null);
    try testing.expect(result.spelling_corrections.len >= 2);
}

test "spelling correction: rock strength typo" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Waek LIMESTONE");
    defer result.deinit(allocator);

    // Should correct Waek to weak
    try testing.expect(result.rock_strength != null);
    try testing.expectEqual(parser.RockStrength.weak, result.rock_strength.?);

    // Should have a spelling correction recorded
    try testing.expect(result.spelling_corrections.len > 0);
    try testing.expectEqualStrings("waek", result.spelling_corrections[0].original);
    try testing.expectEqualStrings("weak", result.spelling_corrections[0].corrected);
}

test "spelling correction: weathering grade typo" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Strong slightly weatherd LIMESTONE");
    defer result.deinit(allocator);

    // Should correct weatherd to weathered
    try testing.expect(result.weathering_grade != null);

    // Should have a spelling correction recorded
    try testing.expect(result.spelling_corrections.len > 0);
}

test "spelling correction: common typo dictionary fast path" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);

    // These are all in the common typo dictionary
    const test_cases = [_]struct { input: []const u8, expected_soil: ?parser.SoilType, expected_consistency: ?parser.Consistency }{
        .{ .input = "Firn CLAY", .expected_soil = parser.SoilType.clay, .expected_consistency = parser.Consistency.firm },
        .{ .input = "Stif CLAY", .expected_soil = parser.SoilType.clay, .expected_consistency = parser.Consistency.stiff },
        .{ .input = "Firm CLAI", .expected_soil = parser.SoilType.clay, .expected_consistency = parser.Consistency.firm },
    };

    for (test_cases) |case| {
        const result = try p.parse(case.input);
        defer result.deinit(allocator);

        if (case.expected_soil) |expected| {
            try testing.expectEqual(expected, result.primary_soil_type.?);
        }

        if (case.expected_consistency) |expected| {
            try testing.expectEqual(expected, result.consistency.?);
        }

        // Should have corrections
        try testing.expect(result.spelling_corrections.len > 0);
    }
}

test "spelling correction: similarity scores recorded" {
    const allocator = testing.allocator;

    var p = parser.Parser.init(allocator);
    const result = try p.parse("Firm CLAI");
    defer result.deinit(allocator);

    // Should have spelling corrections with similarity scores
    try testing.expect(result.spelling_corrections.len > 0);
    try testing.expect(result.spelling_corrections[0].similarity_score > 0.7);
    try testing.expect(result.spelling_corrections[0].similarity_score <= 1.0);
}
