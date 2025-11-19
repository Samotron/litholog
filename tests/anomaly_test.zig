const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

const SoilDescription = parser.SoilDescription;
const MaterialType = parser.MaterialType;
const SoilType = parser.SoilType;
const Consistency = parser.Consistency;
const Density = parser.Density;
const SecondaryConstituent = parser.SecondaryConstituent;

// We'll need to add anomaly exports to bs5930.zig first
const AnomalyDetector = parser.AnomalyDetector;
const AnomalyType = parser.AnomalyType;
const Severity = parser.Severity;

test "anomaly: cohesive soil with density descriptor" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const desc = SoilDescription{
        .raw_description = "Dense CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        .density = .dense, // Wrong - should use consistency
    };

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);
    try testing.expect(result.anomalies.len >= 1);

    // Find the mismatched descriptor anomaly
    var found_mismatch = false;
    for (result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .mismatched_strength_descriptor) {
            found_mismatch = true;
            try testing.expectEqual(Severity.high, anomaly.severity);
            try testing.expect(anomaly.suggestion != null);
        }
    }
    try testing.expect(found_mismatch);
}

test "anomaly: granular soil with consistency descriptor" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const desc = SoilDescription{
        .raw_description = "Firm SAND",
        .material_type = .soil,
        .primary_soil_type = .sand,
        .consistency = .firm, // Wrong - should use density
    };

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);
    try testing.expect(result.anomalies.len >= 1);

    var found_mismatch = false;
    for (result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .mismatched_strength_descriptor) {
            found_mismatch = true;
            try testing.expectEqual(Severity.high, anomaly.severity);
        }
    }
    try testing.expect(found_mismatch);
}

test "anomaly: cohesive soil missing consistency" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const desc = SoilDescription{
        .raw_description = "CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        // Missing consistency
    };

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);
    try testing.expect(result.anomalies.len >= 1);

    var found_missing = false;
    for (result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .missing_strength_descriptor) {
            found_missing = true;
            try testing.expectEqual(Severity.medium, anomaly.severity);
            try testing.expect(anomaly.suggestion != null);
        }
    }
    try testing.expect(found_missing);
}

test "anomaly: granular soil missing density" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const desc = SoilDescription{
        .raw_description = "SAND",
        .material_type = .soil,
        .primary_soil_type = .sand,
        // Missing density
    };

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);
    try testing.expect(result.anomalies.len >= 1);

    var found_missing = false;
    for (result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .missing_strength_descriptor) {
            found_missing = true;
            try testing.expectEqual(Severity.medium, anomaly.severity);
        }
    }
    try testing.expect(found_missing);
}

test "anomaly: very clayey sand should be sandy clay" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const constituents = try allocator.alloc(SecondaryConstituent, 1);
    constituents[0] = SecondaryConstituent{
        .amount = "very",
        .soil_type = "clayey",
    };

    const desc = SoilDescription{
        .raw_description = "Very clayey SAND",
        .material_type = .soil,
        .primary_soil_type = .sand,
        .density = .dense,
        .secondary_constituents = constituents,
    };
    defer allocator.free(constituents);

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);

    var found_unusual = false;
    for (result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .unusual_constituent_combination) {
            found_unusual = true;
            try testing.expectEqual(Severity.medium, anomaly.severity);
            try testing.expect(std.mem.indexOf(u8, anomaly.description, "sandy CLAY") != null);
        }
    }
    try testing.expect(found_unusual);
}

test "anomaly: very sandy clay should be clayey sand" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const constituents = try allocator.alloc(SecondaryConstituent, 1);
    constituents[0] = SecondaryConstituent{
        .amount = "very",
        .soil_type = "sandy",
    };

    const desc = SoilDescription{
        .raw_description = "Very sandy CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        .consistency = .firm,
        .secondary_constituents = constituents,
    };
    defer allocator.free(constituents);

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);

    var found_unusual = false;
    for (result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .unusual_constituent_combination) {
            found_unusual = true;
            try testing.expect(std.mem.indexOf(u8, anomaly.description, "clayey SAND") != null);
        }
    }
    try testing.expect(found_unusual);
}

test "anomaly: both consistency and density present" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const desc = SoilDescription{
        .raw_description = "Firm dense CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        .consistency = .firm,
        .density = .dense, // Should not have both
    };

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);

    var found_conflict = false;
    for (result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .conflicting_properties) {
            found_conflict = true;
            try testing.expectEqual(Severity.high, anomaly.severity);
        }
    }
    try testing.expect(found_conflict);
}

test "anomaly: excessive constituents" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const constituents = try allocator.alloc(SecondaryConstituent, 4);
    constituents[0] = SecondaryConstituent{ .amount = "slightly", .soil_type = "sandy" };
    constituents[1] = SecondaryConstituent{ .amount = "slightly", .soil_type = "silty" };
    constituents[2] = SecondaryConstituent{ .amount = "slightly", .soil_type = "gravelly" };
    constituents[3] = SecondaryConstituent{ .amount = "slightly", .soil_type = "organic" };

    const desc = SoilDescription{
        .raw_description = "Complex soil",
        .material_type = .soil,
        .primary_soil_type = .clay,
        .consistency = .firm,
        .secondary_constituents = constituents,
    };
    defer allocator.free(constituents);

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);

    var found_excessive = false;
    for (result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .excessive_constituents) {
            found_excessive = true;
            try testing.expectEqual(Severity.low, anomaly.severity);
        }
    }
    try testing.expect(found_excessive);
}

test "anomaly: duplicate constituents" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const constituents = try allocator.alloc(SecondaryConstituent, 2);
    constituents[0] = SecondaryConstituent{ .amount = "slightly", .soil_type = "sandy" };
    constituents[1] = SecondaryConstituent{ .amount = "very", .soil_type = "sandy" }; // Duplicate

    const desc = SoilDescription{
        .raw_description = "Slightly very sandy CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        .consistency = .firm,
        .secondary_constituents = constituents,
    };
    defer allocator.free(constituents);

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);

    var found_duplicate = false;
    for (result.anomalies) |anomaly| {
        if (anomaly.anomaly_type == .duplicate_constituents) {
            found_duplicate = true;
            try testing.expectEqual(Severity.low, anomaly.severity);
            try testing.expect(std.mem.indexOf(u8, anomaly.description, "sandy") != null);
        }
    }
    try testing.expect(found_duplicate);
}

test "anomaly: well-formed description has no anomalies" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const constituents = try allocator.alloc(SecondaryConstituent, 1);
    constituents[0] = SecondaryConstituent{ .amount = "slightly", .soil_type = "sandy" };

    const desc = SoilDescription{
        .raw_description = "Firm slightly sandy CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        .consistency = .firm,
        .secondary_constituents = constituents,
    };
    defer allocator.free(constituents);

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(!result.has_anomalies);
    try testing.expectEqual(@as(usize, 0), result.anomalies.len);
}

test "anomaly: overall severity calculation - high" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const desc = SoilDescription{
        .raw_description = "Dense CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        .density = .dense, // High severity: mismatched descriptor
    };

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);
    try testing.expectEqual(Severity.high, result.overall_severity);
}

test "anomaly: overall severity calculation - medium" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const desc = SoilDescription{
        .raw_description = "CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        // Missing consistency - medium severity
    };

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);
    try testing.expectEqual(Severity.medium, result.overall_severity);
}

test "anomaly: overall severity calculation - low" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const constituents = try allocator.alloc(SecondaryConstituent, 2);
    constituents[0] = SecondaryConstituent{ .amount = "slightly", .soil_type = "sandy" };
    constituents[1] = SecondaryConstituent{ .amount = "slightly", .soil_type = "sandy" }; // Low severity: duplicate

    const desc = SoilDescription{
        .raw_description = "Firm slightly sandy slightly sandy CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        .consistency = .firm,
        .secondary_constituents = constituents,
    };
    defer allocator.free(constituents);

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);
    try testing.expectEqual(Severity.low, result.overall_severity);
}

test "anomaly: AnomalyType toString" {
    try testing.expectEqualStrings("Mismatched strength descriptor", AnomalyType.mismatched_strength_descriptor.toString());
    try testing.expectEqualStrings("Missing strength descriptor", AnomalyType.missing_strength_descriptor.toString());
    try testing.expectEqualStrings("Unusual constituent combination", AnomalyType.unusual_constituent_combination.toString());
    try testing.expectEqualStrings("Conflicting properties", AnomalyType.conflicting_properties.toString());
}

test "anomaly: Severity toString" {
    try testing.expectEqualStrings("low", Severity.low.toString());
    try testing.expectEqualStrings("medium", Severity.medium.toString());
    try testing.expectEqualStrings("high", Severity.high.toString());
}

test "anomaly: AnomalyType getSeverity" {
    try testing.expectEqual(Severity.high, AnomalyType.mismatched_strength_descriptor.getSeverity());
    try testing.expectEqual(Severity.medium, AnomalyType.missing_strength_descriptor.getSeverity());
    try testing.expectEqual(Severity.low, AnomalyType.excessive_constituents.getSeverity());
}

test "anomaly: multiple anomalies in single description" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const constituents = try allocator.alloc(SecondaryConstituent, 2);
    constituents[0] = SecondaryConstituent{ .amount = "slightly", .soil_type = "sandy" };
    constituents[1] = SecondaryConstituent{ .amount = "very", .soil_type = "sandy" };

    const desc = SoilDescription{
        .raw_description = "Dense slightly very sandy CLAY",
        .material_type = .soil,
        .primary_soil_type = .clay,
        .density = .dense, // Wrong descriptor (high severity)
        .secondary_constituents = constituents, // Duplicates (low severity)
    };
    defer allocator.free(constituents);

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    try testing.expect(result.has_anomalies);
    try testing.expect(result.anomalies.len >= 2);

    // Should have high overall severity due to mismatched descriptor
    try testing.expectEqual(Severity.high, result.overall_severity);
}

test "anomaly: rock description has no soil anomalies" {
    const allocator = testing.allocator;
    var detector = AnomalyDetector.init(allocator);

    const desc = SoilDescription{
        .raw_description = "Strong LIMESTONE",
        .material_type = .rock,
        .primary_rock_type = parser.RockType.limestone,
        .rock_strength = parser.RockStrength.strong,
    };

    var result = try detector.detect(&desc);
    defer result.deinit(allocator);

    // Rock descriptions shouldn't trigger soil-specific anomalies
    try testing.expect(!result.has_anomalies);
}
