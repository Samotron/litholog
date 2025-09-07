const std = @import("std");

pub const TerminologyVariations = struct {
    consistency_variations: std.StringHashMap([]const []const u8),
    density_variations: std.StringHashMap([]const []const u8),
    soil_type_variations: std.StringHashMap([]const []const u8),

    pub fn init(allocator: std.mem.Allocator) TerminologyVariations {
        const consistency_vars = std.StringHashMap([]const []const u8).init(allocator);
        const density_vars = std.StringHashMap([]const []const u8).init(allocator);
        const soil_type_vars = std.StringHashMap([]const []const u8).init(allocator);

        return TerminologyVariations{
            .consistency_variations = consistency_vars,
            .density_variations = density_vars,
            .soil_type_variations = soil_type_vars,
        };
    }

    pub fn deinit(self: *TerminologyVariations) void {
        self.consistency_variations.deinit();
        self.density_variations.deinit();
        self.soil_type_variations.deinit();
    }
};

pub const consistency_abbreviations = [_]struct { abbrev: []const u8, full: []const u8 }{
    .{ .abbrev = "v.soft", .full = "very soft" },
    .{ .abbrev = "v. soft", .full = "very soft" },
    .{ .abbrev = "vs", .full = "very soft" },
    .{ .abbrev = "v.stiff", .full = "very stiff" },
    .{ .abbrev = "v. stiff", .full = "very stiff" },
    .{ .abbrev = "v.s.", .full = "very stiff" },
};

pub const density_abbreviations = [_]struct { abbrev: []const u8, full: []const u8 }{
    .{ .abbrev = "v.loose", .full = "very loose" },
    .{ .abbrev = "v. loose", .full = "very loose" },
    .{ .abbrev = "vl", .full = "very loose" },
    .{ .abbrev = "med. dense", .full = "medium dense" },
    .{ .abbrev = "med dense", .full = "medium dense" },
    .{ .abbrev = "md", .full = "medium dense" },
    .{ .abbrev = "v.dense", .full = "very dense" },
    .{ .abbrev = "v. dense", .full = "very dense" },
    .{ .abbrev = "vd", .full = "very dense" },
};

pub const proportion_abbreviations = [_]struct { abbrev: []const u8, full: []const u8 }{
    .{ .abbrev = "sl.", .full = "slightly" },
    .{ .abbrev = "sl", .full = "slightly" },
    .{ .abbrev = "mod.", .full = "moderately" },
    .{ .abbrev = "mod", .full = "moderately" },
    .{ .abbrev = "v.", .full = "very" },
    .{ .abbrev = "v", .full = "very" },
};

pub const soil_type_abbreviations = [_]struct { abbrev: []const u8, full: []const u8 }{
    .{ .abbrev = "cl", .full = "clay" },
    .{ .abbrev = "si", .full = "silt" },
    .{ .abbrev = "sa", .full = "sand" },
    .{ .abbrev = "gr", .full = "gravel" },
};

pub fn expandAbbreviations(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = try allocator.dupe(u8, input);

    // Replace consistency abbreviations
    for (consistency_abbreviations) |abbrev_pair| {
        if (std.mem.indexOf(u8, result, abbrev_pair.abbrev)) |_| {
            const new_result = try std.mem.replaceOwned(u8, allocator, result, abbrev_pair.abbrev, abbrev_pair.full);
            allocator.free(result);
            result = new_result;
        }
    }

    // Replace density abbreviations
    for (density_abbreviations) |abbrev_pair| {
        if (std.mem.indexOf(u8, result, abbrev_pair.abbrev)) |_| {
            const new_result = try std.mem.replaceOwned(u8, allocator, result, abbrev_pair.abbrev, abbrev_pair.full);
            allocator.free(result);
            result = new_result;
        }
    }

    // Replace proportion abbreviations
    for (proportion_abbreviations) |abbrev_pair| {
        if (std.mem.indexOf(u8, result, abbrev_pair.abbrev)) |_| {
            const new_result = try std.mem.replaceOwned(u8, allocator, result, abbrev_pair.abbrev, abbrev_pair.full);
            allocator.free(result);
            result = new_result;
        }
    }

    return result;
}

pub fn normalizeSpelling(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = try allocator.dupe(u8, input);

    // Handle common UK/US spelling variations
    const variations = [_]struct { from: []const u8, to: []const u8 }{
        .{ .from = "grey", .to = "gray" },
        .{ .from = "colour", .to = "color" },
    };

    for (variations) |variation| {
        if (std.mem.indexOf(u8, result, variation.from)) |_| {
            const new_result = try std.mem.replaceOwned(u8, allocator, result, variation.from, variation.to);
            allocator.free(result);
            result = new_result;
        }
    }

    return result;
}
