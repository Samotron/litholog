const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

const Lexer = parser.Lexer;
const TokenType = parser.TokenType;

test "lexer: tokenize simple consistency descriptor" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "firm");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.consistency, tokens[0].type);
    try testing.expectEqualStrings("firm", tokens[0].value);
}

test "lexer: tokenize simple density descriptor" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "dense");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.density, tokens[0].type);
    try testing.expectEqualStrings("dense", tokens[0].value);
}

test "lexer: tokenize soil type" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "CLAY");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.soil_type, tokens[0].type);
    try testing.expectEqualStrings("CLAY", tokens[0].value);
}

test "lexer: tokenize rock type" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "LIMESTONE");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.rock_type, tokens[0].type);
    try testing.expectEqualStrings("LIMESTONE", tokens[0].value);
}

test "lexer: tokenize simple soil description" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "Firm CLAY");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 2), tokens.len);
    try testing.expectEqual(TokenType.consistency, tokens[0].type);
    try testing.expectEqualStrings("Firm", tokens[0].value);
    try testing.expectEqual(TokenType.soil_type, tokens[1].type);
    try testing.expectEqualStrings("CLAY", tokens[1].value);
}

test "lexer: tokenize consistency range" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "soft to firm");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.consistency_range, tokens[0].type);
    try testing.expectEqualStrings("soft to firm", tokens[0].value);
}

test "lexer: tokenize consistency range with CLAY" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "firm to stiff CLAY");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 2), tokens.len);
    try testing.expectEqual(TokenType.consistency_range, tokens[0].type);
    try testing.expectEqualStrings("firm to stiff", tokens[0].value);
    try testing.expectEqual(TokenType.soil_type, tokens[1].type);
}

test "lexer: tokenize multi-word patterns" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "very soft");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.consistency, tokens[0].type);
    try testing.expectEqualStrings("very soft", tokens[0].value);
}

test "lexer: tokenize proportion descriptor" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "slightly");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.proportion, tokens[0].type);
    try testing.expectEqualStrings("slightly", tokens[0].value);
}

test "lexer: tokenize adjective" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "sandy");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.adjective, tokens[0].type);
    try testing.expectEqualStrings("sandy", tokens[0].value);
}

test "lexer: tokenize complex soil description" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "Firm slightly sandy CLAY");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 4), tokens.len);
    try testing.expectEqual(TokenType.consistency, tokens[0].type);
    try testing.expectEqual(TokenType.proportion, tokens[1].type);
    try testing.expectEqual(TokenType.adjective, tokens[2].type);
    try testing.expectEqual(TokenType.soil_type, tokens[3].type);
}

test "lexer: tokenize rock strength" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "strong");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.rock_strength, tokens[0].type);
    try testing.expectEqualStrings("strong", tokens[0].value);
}

test "lexer: tokenize weathering grade" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "slightly weathered");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.weathering_grade, tokens[0].type);
    try testing.expectEqualStrings("slightly weathered", tokens[0].value);
}

test "lexer: tokenize rock structure" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "jointed");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.rock_structure, tokens[0].type);
    try testing.expectEqualStrings("jointed", tokens[0].value);
}

test "lexer: tokenize complex rock description" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "Strong slightly weathered jointed LIMESTONE");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 4), tokens.len);
    try testing.expectEqual(TokenType.rock_strength, tokens[0].type);
    try testing.expectEqual(TokenType.weathering_grade, tokens[1].type);
    try testing.expectEqual(TokenType.rock_structure, tokens[2].type);
    try testing.expectEqual(TokenType.rock_type, tokens[3].type);
}

test "lexer: tokenize color descriptor" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "brown");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.color, tokens[0].type);
    try testing.expectEqualStrings("brown", tokens[0].value);
}

test "lexer: tokenize moisture content" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "moist");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.moisture_content, tokens[0].type);
    try testing.expectEqualStrings("moist", tokens[0].value);
}

test "lexer: tokenize plasticity index" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "high plasticity");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.plasticity_index, tokens[0].type);
    try testing.expectEqualStrings("high plasticity", tokens[0].value);
}

test "lexer: tokenize particle size" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "fine");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.particle_size, tokens[0].type);
    try testing.expectEqualStrings("fine", tokens[0].value);
}

test "lexer: tokenize empty string" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 0), tokens.len);
}

test "lexer: tokenize whitespace only" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "   \t\n  ");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 0), tokens.len);
}

test "lexer: tokenize with extra whitespace" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "  Firm   CLAY  ");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 2), tokens.len);
    try testing.expectEqualStrings("Firm", tokens[0].value);
    try testing.expectEqualStrings("CLAY", tokens[1].value);
}

test "lexer: tokenize mixed case" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "FiRm ClAy");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 2), tokens.len);
    // Lexer preserves original case
    try testing.expectEqualStrings("FiRm", tokens[0].value);
    try testing.expectEqualStrings("ClAy", tokens[1].value);
}

test "lexer: tokenize position tracking" {
    const allocator = testing.allocator;
    var lex = Lexer.init(allocator, "Firm CLAY");
    defer lex.deinit();

    const tokens = try lex.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 0), tokens[0].start);
    try testing.expectEqual(@as(usize, 4), tokens[0].end);
    try testing.expectEqual(@as(usize, 5), tokens[1].start);
    try testing.expectEqual(@as(usize, 9), tokens[1].end);
}

test "lexer: tokenize all consistency values" {
    const allocator = testing.allocator;
    const consistencies = [_][]const u8{
        "very soft",
        "soft",
        "firm",
        "stiff",
        "very stiff",
        "hard",
    };

    for (consistencies) |consistency| {
        var lex = Lexer.init(allocator, consistency);
        defer lex.deinit();

        const tokens = try lex.tokenize();
        defer allocator.free(tokens);

        try testing.expectEqual(@as(usize, 1), tokens.len);
        try testing.expectEqual(TokenType.consistency, tokens[0].type);
    }
}

test "lexer: tokenize all density values" {
    const allocator = testing.allocator;
    const densities = [_][]const u8{
        "very loose",
        "loose",
        "medium dense",
        "dense",
        "very dense",
    };

    for (densities) |density| {
        var lex = Lexer.init(allocator, density);
        defer lex.deinit();

        const tokens = try lex.tokenize();
        defer allocator.free(tokens);

        try testing.expectEqual(@as(usize, 1), tokens.len);
        try testing.expectEqual(TokenType.density, tokens[0].type);
    }
}

test "lexer: tokenize all rock strength values" {
    const allocator = testing.allocator;
    const strengths = [_][]const u8{
        "very weak",
        "weak",
        "moderately weak",
        "moderately strong",
        "strong",
        "very strong",
        "extremely strong",
    };

    for (strengths) |strength| {
        var lex = Lexer.init(allocator, strength);
        defer lex.deinit();

        const tokens = try lex.tokenize();
        defer allocator.free(tokens);

        try testing.expectEqual(@as(usize, 1), tokens.len);
        try testing.expectEqual(TokenType.rock_strength, tokens[0].type);
    }
}
