const std = @import("std");

/// Common typo corrections for fast-path lookup before fuzzy matching
/// These are common transpositions, missing letters, and fat-finger errors
pub const common_typos = [_]struct { typo: []const u8, correct: []const u8 }{
    // Consistency terms
    .{ .typo = "firn", .correct = "firm" }, // transposition
    .{ .typo = "frim", .correct = "firm" }, // transposition
    .{ .typo = "stif", .correct = "stiff" }, // missing letter
    .{ .typo = "stff", .correct = "stiff" }, // missing letter
    .{ .typo = "sitff", .correct = "stiff" }, // typo
    .{ .typo = "soff", .correct = "soft" }, // typo
    .{ .typo = "sfot", .correct = "soft" }, // transposition

    // Soil types
    .{ .typo = "clai", .correct = "clay" }, // transposition
    .{ .typo = "caly", .correct = "clay" }, // transposition
    .{ .typo = "caly", .correct = "clay" }, // transposition
    .{ .typo = "snad", .correct = "sand" }, // transposition
    .{ .typo = "snad", .correct = "sand" }, // transposition
    .{ .typo = "sant", .correct = "sand" }, // typo
    .{ .typo = "silt", .correct = "silt" }, // common misspelling
    .{ .typo = "siltt", .correct = "silt" }, // double letter
    .{ .typo = "garvel", .correct = "gravel" }, // typo
    .{ .typo = "grabel", .correct = "gravel" }, // typo
    .{ .typo = "gravelv", .correct = "gravel" }, // extra letter

    // Rock types
    .{ .typo = "limstone", .correct = "limestone" }, // missing letter
    .{ .typo = "limetone", .correct = "limestone" }, // missing letter
    .{ .typo = "limesone", .correct = "limestone" }, // missing letter
    .{ .typo = "sandston", .correct = "sandstone" }, // missing letter
    .{ .typo = "sandstoen", .correct = "sandstone" }, // transposition
    .{ .typo = "mudston", .correct = "mudstone" }, // missing letter
    .{ .typo = "mudstoen", .correct = "mudstone" }, // transposition
    .{ .typo = "granit", .correct = "granite" }, // missing letter
    .{ .typo = "graniet", .correct = "granite" }, // typo
    .{ .typo = "baslt", .correct = "basalt" }, // missing letter

    // Density terms
    .{ .typo = "loos", .correct = "loose" }, // missing letter
    .{ .typo = "losoe", .correct = "loose" }, // transposition
    .{ .typo = "dens", .correct = "dense" }, // missing letter
    .{ .typo = "dence", .correct = "dense" }, // typo
    .{ .typo = "dnese", .correct = "dense" }, // transposition

    // Rock strength
    .{ .typo = "waek", .correct = "weak" }, // transposition
    .{ .typo = "weka", .correct = "weak" }, // transposition
    .{ .typo = "storng", .correct = "strong" }, // transposition
    .{ .typo = "strogn", .correct = "strong" }, // transposition
    .{ .typo = "stong", .correct = "strong" }, // missing letter

    // Proportions
    .{ .typo = "slighty", .correct = "slightly" }, // typo
    .{ .typo = "slighly", .correct = "slightly" }, // missing letter
    .{ .typo = "slighlty", .correct = "slightly" }, // typo
    .{ .typo = "moderatly", .correct = "moderately" }, // missing letter
    .{ .typo = "moderatley", .correct = "moderately" }, // transposition
    .{ .typo = "modertely", .correct = "moderately" }, // typo

    // Adjectives
    .{ .typo = "snady", .correct = "sandy" }, // transposition
    .{ .typo = "sadny", .correct = "sandy" }, // transposition
    .{ .typo = "silty", .correct = "silty" }, // common misspelling (already correct)
    .{ .typo = "claey", .correct = "clayey" }, // typo
    .{ .typo = "clayy", .correct = "clayey" }, // typo
    .{ .typo = "gravelley", .correct = "gravelly" }, // extra letter
    .{ .typo = "gravely", .correct = "gravelly" }, // missing letter

    // Colors
    .{ .typo = "borwn", .correct = "brown" }, // transposition
    .{ .typo = "browm", .correct = "brown" }, // typo
    .{ .typo = "graY", .correct = "gray" }, // case
    .{ .typo = "gery", .correct = "gray" }, // transposition

    // Weathering
    .{ .typo = "weatherd", .correct = "weathered" }, // missing letter
    .{ .typo = "waethered", .correct = "weathered" }, // transposition
    .{ .typo = "wethered", .correct = "weathered" }, // missing letter

    // Rock structure
    .{ .typo = "massiv", .correct = "massive" }, // missing letter
    .{ .typo = "masive", .correct = "massive" }, // missing letter
    .{ .typo = "bedde", .correct = "bedded" }, // missing letter
    .{ .typo = "jointe", .correct = "jointed" }, // missing letter
    .{ .typo = "fractued", .correct = "fractured" }, // transposition
    .{ .typo = "fracured", .correct = "fractured" }, // missing letter
    .{ .typo = "foliatd", .correct = "foliated" }, // missing letter
    .{ .typo = "laminatd", .correct = "laminated" }, // missing letter
};

/// Look up a word in the common typos dictionary
/// Returns the corrected word if found, null otherwise
pub fn lookupTypo(word: []const u8) ?[]const u8 {
    var lower_buf: [64]u8 = undefined;
    if (word.len >= lower_buf.len) return null;

    const lower = std.ascii.lowerString(lower_buf[0..word.len], word);

    for (common_typos) |entry| {
        if (std.mem.eql(u8, lower, entry.typo)) {
            return entry.correct;
        }
    }

    return null;
}

test "typo lookup - exact match" {
    const testing = std.testing;

    const result1 = lookupTypo("firn");
    try testing.expect(result1 != null);
    try testing.expectEqualStrings("firm", result1.?);

    const result2 = lookupTypo("clai");
    try testing.expect(result2 != null);
    try testing.expectEqualStrings("clay", result2.?);

    const result3 = lookupTypo("stif");
    try testing.expect(result3 != null);
    try testing.expectEqualStrings("stiff", result3.?);
}

test "typo lookup - no match" {
    const testing = std.testing;

    const result = lookupTypo("correctword");
    try testing.expect(result == null);
}

test "typo lookup - case insensitive" {
    const testing = std.testing;

    const result1 = lookupTypo("FIRN");
    try testing.expect(result1 != null);
    try testing.expectEqualStrings("firm", result1.?);

    const result2 = lookupTypo("Clai");
    try testing.expect(result2 != null);
    try testing.expectEqualStrings("clay", result2.?);
}
