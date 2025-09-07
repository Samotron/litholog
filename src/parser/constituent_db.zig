const std = @import("std");
const types = @import("types.zig");

const SoilType = types.SoilType;

pub const ProportionRange = struct {
    lower_bound: f32,
    upper_bound: f32,
    typical_value: ?f32 = null,

    pub fn contains(self: ProportionRange, value: f32) bool {
        return value >= self.lower_bound and value <= self.upper_bound;
    }

    pub fn getMidpoint(self: ProportionRange) f32 {
        return (self.lower_bound + self.upper_bound) / 2.0;
    }
};

pub const ConstituentProportion = struct {
    soil_type: []const u8,
    range: ProportionRange,

    pub fn toString(self: ConstituentProportion, allocator: std.mem.Allocator) ![]u8 {
        const typical = if (self.range.typical_value) |tv| tv else self.range.getMidpoint();
        return std.fmt.allocPrint(allocator, "{s}: {d:.0}-{d:.0}% (typical: {d:.0}%)", .{
            self.soil_type,
            self.range.lower_bound,
            self.range.upper_bound,
            typical,
        });
    }
};

pub const ConstituentGuidance = struct {
    constituents: []ConstituentProportion,
    confidence: f32 = 0.8,

    pub fn deinit(self: ConstituentGuidance, allocator: std.mem.Allocator) void {
        allocator.free(self.constituents);
    }
};

// BS5930 proportion ranges based on descriptive terms
const PROPORTION_RANGES = std.StringHashMap(ProportionRange).init(std.heap.page_allocator);

fn initProportionRanges() std.StringHashMap(ProportionRange) {
    var ranges = std.StringHashMap(ProportionRange).init(std.heap.page_allocator);

    // BS5930 standard proportion ranges
    ranges.put("slightly", ProportionRange{ .lower_bound = 5, .upper_bound = 12, .typical_value = 8 }) catch unreachable;
    ranges.put("moderately", ProportionRange{ .lower_bound = 12, .upper_bound = 35, .typical_value = 20 }) catch unreachable;
    ranges.put("very", ProportionRange{ .lower_bound = 35, .upper_bound = 65, .typical_value = 50 }) catch unreachable;

    return ranges;
}

// Lazy initialization of proportion ranges
var proportion_ranges_init = false;
var proportion_ranges: std.StringHashMap(ProportionRange) = undefined;

fn getProportionRanges() *std.StringHashMap(ProportionRange) {
    if (!proportion_ranges_init) {
        proportion_ranges = initProportionRanges();
        proportion_ranges_init = true;
    }
    return &proportion_ranges;
}

pub const ConstituentDatabase = struct {
    pub fn getConstituentGuidance(
        allocator: std.mem.Allocator,
        primary_soil_type: ?SoilType,
        secondary_constituents: []types.SecondaryConstituent,
    ) !?ConstituentGuidance {
        if (primary_soil_type == null and secondary_constituents.len == 0) {
            return null;
        }

        var constituents = std.ArrayList(ConstituentProportion).init(allocator);
        defer constituents.deinit();

        var total_secondary_percentage: f32 = 0;

        // Process secondary constituents
        for (secondary_constituents) |sc| {
            if (getProportionRange(sc.amount)) |range| {
                const typical = if (range.typical_value) |tv| tv else range.getMidpoint();
                total_secondary_percentage += typical;

                try constituents.append(ConstituentProportion{
                    .soil_type = sc.soil_type,
                    .range = range,
                });
            }
        }

        // Calculate primary constituent percentage
        if (primary_soil_type) |pst| {
            const primary_percentage = 100.0 - total_secondary_percentage;
            const primary_range = ProportionRange{
                .lower_bound = @max(35.0, primary_percentage - 15.0), // Minimum 35% for primary
                .upper_bound = @min(95.0, primary_percentage + 15.0), // Maximum 95% for primary
                .typical_value = @max(35.0, primary_percentage),
            };

            // Convert soil type to lowercase for consistency
            const primary_name = switch (pst) {
                .clay => "clay",
                .silt => "silt",
                .sand => "sand",
                .gravel => "gravel",
                .peat => "peat",
                .organic => "organic",
            };

            try constituents.insert(0, ConstituentProportion{
                .soil_type = primary_name,
                .range = primary_range,
            });
        }

        if (constituents.items.len == 0) {
            return null;
        }

        return ConstituentGuidance{
            .constituents = try constituents.toOwnedSlice(),
            .confidence = calculateConfidence(secondary_constituents.len),
        };
    }

    fn getProportionRange(amount_str: []const u8) ?ProportionRange {
        const ranges = getProportionRanges();
        return ranges.get(amount_str);
    }

    fn calculateConfidence(num_constituents: usize) f32 {
        // Confidence decreases with more constituents due to cumulative uncertainty
        return switch (num_constituents) {
            0 => 0.9, // High confidence for pure material
            1 => 0.8, // Good confidence for binary mixture
            2 => 0.7, // Moderate confidence for ternary mixture
            else => 0.6, // Lower confidence for complex mixtures
        };
    }

    pub fn estimateProportionFromPercentage(percentage: f32) ?[]const u8 {
        if (percentage < 5) return null; // Below detection threshold
        if (percentage < 12) return "slightly";
        if (percentage < 35) return "moderately";
        if (percentage < 65) return "very";
        return "predominantly"; // Above 65%
    }
};

// Tests
test "proportion range lookup" {
    const range = ConstituentDatabase.getProportionRange("slightly");
    try std.testing.expect(range != null);
    try std.testing.expect(range.?.lower_bound == 5);
    try std.testing.expect(range.?.upper_bound == 12);
    try std.testing.expect(range.?.typical_value.? == 8);
}

test "constituent guidance for binary mixture" {
    const allocator = std.testing.allocator;

    var secondary_constituents = [_]types.SecondaryConstituent{
        types.SecondaryConstituent{
            .amount = "slightly",
            .soil_type = "sandy",
        },
    };

    const guidance = try ConstituentDatabase.getConstituentGuidance(
        allocator,
        .clay,
        secondary_constituents[0..],
    );

    try std.testing.expect(guidance != null);
    defer guidance.?.deinit(allocator);

    try std.testing.expect(guidance.?.constituents.len == 2);
    // First should be primary (clay)
    try std.testing.expect(std.mem.eql(u8, guidance.?.constituents[0].soil_type, "clay"));
    // Second should be secondary (sandy)
    try std.testing.expect(std.mem.eql(u8, guidance.?.constituents[1].soil_type, "sandy"));
}

test "constituent guidance for complex mixture" {
    const allocator = std.testing.allocator;

    var secondary_constituents = [_]types.SecondaryConstituent{
        types.SecondaryConstituent{
            .amount = "slightly",
            .soil_type = "sandy",
        },
        types.SecondaryConstituent{
            .amount = "moderately",
            .soil_type = "gravelly",
        },
    };

    const guidance = try ConstituentDatabase.getConstituentGuidance(
        allocator,
        .clay,
        secondary_constituents[0..],
    );

    try std.testing.expect(guidance != null);
    defer guidance.?.deinit(allocator);

    try std.testing.expect(guidance.?.constituents.len == 3);
    try std.testing.expect(guidance.?.confidence < 0.8); // Lower confidence for complex mixture
}

test "percentage estimation" {
    const desc = ConstituentDatabase.estimateProportionFromPercentage(8);
    try std.testing.expect(std.mem.eql(u8, desc.?, "slightly"));

    const desc2 = ConstituentDatabase.estimateProportionFromPercentage(25);
    try std.testing.expect(std.mem.eql(u8, desc2.?, "moderately"));

    const desc3 = ConstituentDatabase.estimateProportionFromPercentage(50);
    try std.testing.expect(std.mem.eql(u8, desc3.?, "very"));
}
