const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

test "fuzzy: levenshtein distance - identical strings" {
    const allocator = testing.allocator;

    const distance = try parser.levenshteinDistance("test", "test", allocator);
    try testing.expectEqual(@as(usize, 0), distance);
}

test "fuzzy: levenshtein distance - one character difference" {
    const allocator = testing.allocator;

    const distance = try parser.levenshteinDistance("test", "text", allocator);
    try testing.expectEqual(@as(usize, 1), distance);
}

test "fuzzy: levenshtein distance - insertion" {
    const allocator = testing.allocator;

    const distance = try parser.levenshteinDistance("test", "tests", allocator);
    try testing.expectEqual(@as(usize, 1), distance);
}

test "fuzzy: levenshtein distance - deletion" {
    const allocator = testing.allocator;

    const distance = try parser.levenshteinDistance("tests", "test", allocator);
    try testing.expectEqual(@as(usize, 1), distance);
}

test "fuzzy: levenshtein distance - empty strings" {
    const allocator = testing.allocator;

    const distance1 = try parser.levenshteinDistance("", "", allocator);
    try testing.expectEqual(@as(usize, 0), distance1);

    const distance2 = try parser.levenshteinDistance("test", "", allocator);
    try testing.expectEqual(@as(usize, 4), distance2);

    const distance3 = try parser.levenshteinDistance("", "test", allocator);
    try testing.expectEqual(@as(usize, 4), distance3);
}

test "fuzzy: levenshtein distance - common typos" {
    const allocator = testing.allocator;

    const distance1 = try parser.levenshteinDistance("firm", "frim", allocator);
    try testing.expectEqual(@as(usize, 2), distance1); // transposition

    const distance2 = try parser.levenshteinDistance("clay", "caly", allocator);
    try testing.expectEqual(@as(usize, 2), distance2); // transposition
}

test "fuzzy: similarity metric exists" {
    const allocator = testing.allocator;

    const similarity = try parser.similarityRatio("test", "text", allocator);
    try testing.expect(similarity >= 0.0);
    try testing.expect(similarity <= 1.0);
}

test "fuzzy: identical strings have high similarity" {
    const allocator = testing.allocator;

    const similarity = try parser.similarityRatio("test", "test", allocator);
    try testing.expect(similarity > 0.99);
}

test "fuzzy: very different strings have low similarity" {
    const allocator = testing.allocator;

    const similarity = try parser.similarityRatio("abc", "xyz", allocator);
    try testing.expect(similarity < 0.5);
}
