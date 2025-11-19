const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

const ConstituentDatabase = parser.ConstituentDatabase;
const SoilType = parser.SoilType;
const SecondaryConstituent = parser.SecondaryConstituent;

test "constituent_db: guidance for single secondary constituent" {
    const allocator = testing.allocator;

    var secondary = [_]SecondaryConstituent{
        .{ .amount = "slightly", .soil_type = "sandy" },
    };

    const guidance = try ConstituentDatabase.getConstituentGuidance(allocator, .clay, &secondary);
    try testing.expect(guidance != null);
    defer if (guidance) |g| g.deinit(allocator);

    const g = guidance.?;
    try testing.expect(g.constituents.len > 0);
    try testing.expect(g.confidence > 0.0);
}

test "constituent_db: guidance for multiple secondary constituents" {
    const allocator = testing.allocator;

    var secondary = [_]SecondaryConstituent{
        .{ .amount = "slightly", .soil_type = "sandy" },
        .{ .amount = "slightly", .soil_type = "gravelly" },
    };

    const guidance = try ConstituentDatabase.getConstituentGuidance(allocator, .clay, &secondary);
    try testing.expect(guidance != null);
    defer if (guidance) |g| g.deinit(allocator);

    const g = guidance.?;
    try testing.expect(g.constituents.len >= 2);
}

test "constituent_db: no guidance for no constituents" {
    const allocator = testing.allocator;

    var secondary = [_]SecondaryConstituent{};

    const guidance = try ConstituentDatabase.getConstituentGuidance(allocator, null, &secondary);
    try testing.expect(guidance == null);
}

test "constituent_db: proportion ranges are correct" {
    const allocator = testing.allocator;

    var secondary_slightly = [_]SecondaryConstituent{
        .{ .amount = "slightly", .soil_type = "sandy" },
    };

    const guidance = try ConstituentDatabase.getConstituentGuidance(allocator, .clay, &secondary_slightly);
    try testing.expect(guidance != null);
    defer if (guidance) |g| g.deinit(allocator);

    // "slightly" should be around 5-12%
    const g = guidance.?;
    for (g.constituents) |constituent| {
        if (std.mem.eql(u8, constituent.soil_type, "sandy")) {
            try testing.expect(constituent.range.lower_bound >= 4);
            try testing.expect(constituent.range.upper_bound <= 13);
        }
    }
}

test "constituent_db: confidence is set" {
    const allocator = testing.allocator;

    var secondary = [_]SecondaryConstituent{
        .{ .amount = "slightly", .soil_type = "sandy" },
    };

    const guidance = try ConstituentDatabase.getConstituentGuidance(allocator, .clay, &secondary);
    try testing.expect(guidance != null);
    defer if (guidance) |g| g.deinit(allocator);

    try testing.expect(guidance.?.confidence > 0.0);
    try testing.expect(guidance.?.confidence <= 1.0);
}
