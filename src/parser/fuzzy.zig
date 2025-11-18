const std = @import("std");

/// Levenshtein distance algorithm for fuzzy string matching
pub fn levenshteinDistance(s1: []const u8, s2: []const u8, allocator: std.mem.Allocator) !usize {
    const len1 = s1.len;
    const len2 = s2.len;

    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    // Create matrix (len1+1) x (len2+1)
    const rows = len1 + 1;
    const cols = len2 + 1;

    var matrix = try allocator.alloc([]usize, rows);
    defer {
        for (matrix) |row| {
            allocator.free(row);
        }
        allocator.free(matrix);
    }

    for (matrix) |*row| {
        row.* = try allocator.alloc(usize, cols);
    }

    // Initialize first row and column
    for (0..rows) |i| {
        matrix[i][0] = i;
    }
    for (0..cols) |j| {
        matrix[0][j] = j;
    }

    // Fill matrix
    for (1..rows) |i| {
        for (1..cols) |j| {
            const cost: usize = if (s1[i - 1] == s2[j - 1]) 0 else 1;

            const deletion = matrix[i - 1][j] + 1;
            const insertion = matrix[i][j - 1] + 1;
            const substitution = matrix[i - 1][j - 1] + cost;

            matrix[i][j] = @min(@min(deletion, insertion), substitution);
        }
    }

    return matrix[len1][len2];
}

/// Calculate similarity ratio between two strings (0.0 to 1.0)
pub fn similarityRatio(s1: []const u8, s2: []const u8, allocator: std.mem.Allocator) !f32 {
    if (s1.len == 0 and s2.len == 0) return 1.0;

    const distance = try levenshteinDistance(s1, s2, allocator);
    const max_len = @max(s1.len, s2.len);

    const ratio = 1.0 - (@as(f32, @floatFromInt(distance)) / @as(f32, @floatFromInt(max_len)));
    return ratio;
}

/// Find the closest match from a list of options
pub fn findClosestMatch(target: []const u8, options: []const []const u8, allocator: std.mem.Allocator) !?struct { match: []const u8, score: f32 } {
    if (options.len == 0) return null;

    var best_match: []const u8 = options[0];
    var best_score: f32 = try similarityRatio(target, options[0], allocator);

    for (options[1..]) |option| {
        const score = try similarityRatio(target, option, allocator);
        if (score > best_score) {
            best_score = score;
            best_match = option;
        }
    }

    return .{
        .match = best_match,
        .score = best_score,
    };
}

/// Check if a string fuzzy matches any option with a minimum threshold
pub fn fuzzyMatch(target: []const u8, options: []const []const u8, threshold: f32, allocator: std.mem.Allocator) !?[]const u8 {
    const result = try findClosestMatch(target, options, allocator) orelse return null;

    if (result.score >= threshold) {
        return result.match;
    }

    return null;
}

/// Fuzzy match for case-insensitive comparison
pub fn fuzzyMatchCaseInsensitive(target: []const u8, options: []const []const u8, threshold: f32, allocator: std.mem.Allocator) !?[]const u8 {
    const target_lower = try std.ascii.allocLowerString(allocator, target);
    defer allocator.free(target_lower);

    var options_lower = try allocator.alloc([]u8, options.len);
    defer {
        for (options_lower) |opt| {
            allocator.free(opt);
        }
        allocator.free(options_lower);
    }

    for (options, 0..) |opt, i| {
        options_lower[i] = try std.ascii.allocLowerString(allocator, opt);
    }

    // Find best match with lowercase strings
    var best_match_idx: ?usize = null;
    var best_score: f32 = 0.0;

    for (options_lower, 0..) |opt_lower, i| {
        const score = try similarityRatio(target_lower, opt_lower, allocator);
        if (score > best_score) {
            best_score = score;
            best_match_idx = i;
        }
    }

    if (best_match_idx) |idx| {
        if (best_score >= threshold) {
            return options[idx];
        }
    }

    return null;
}

test "levenshtein distance" {
    const allocator = std.testing.allocator;

    const dist1 = try levenshteinDistance("kitten", "sitting", allocator);
    try std.testing.expectEqual(@as(usize, 3), dist1);

    const dist2 = try levenshteinDistance("flaw", "lawn", allocator);
    try std.testing.expectEqual(@as(usize, 2), dist2);

    const dist3 = try levenshteinDistance("", "abc", allocator);
    try std.testing.expectEqual(@as(usize, 3), dist3);
}

test "similarity ratio" {
    const allocator = std.testing.allocator;

    const ratio1 = try similarityRatio("hello", "hello", allocator);
    try std.testing.expectApproxEqRel(@as(f32, 1.0), ratio1, 0.001);

    const ratio2 = try similarityRatio("hello", "hallo", allocator);
    try std.testing.expect(ratio2 > 0.7);
    try std.testing.expect(ratio2 < 1.0);
}

test "find closest match" {
    const allocator = std.testing.allocator;

    const options = [_][]const u8{ "clay", "sand", "gravel", "silt" };
    const result = try findClosestMatch("clai", &options, allocator);

    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("clay", result.?.match);
    try std.testing.expect(result.?.score > 0.7);
}

test "fuzzy match with threshold" {
    const allocator = std.testing.allocator;

    const options = [_][]const u8{ "clay", "sand", "gravel", "silt" };

    // Should match
    const match1 = try fuzzyMatch("clai", &options, 0.7, allocator);
    try std.testing.expect(match1 != null);
    try std.testing.expectEqualStrings("clay", match1.?);

    // Should not match with high threshold
    const match2 = try fuzzyMatch("xyz", &options, 0.9, allocator);
    try std.testing.expect(match2 == null);
}

test "case insensitive fuzzy match" {
    const allocator = std.testing.allocator;

    const options = [_][]const u8{ "CLAY", "SAND", "GRAVEL", "SILT" };

    const match = try fuzzyMatchCaseInsensitive("clai", &options, 0.7, allocator);
    try std.testing.expect(match != null);
    try std.testing.expectEqualStrings("CLAY", match.?);
}
