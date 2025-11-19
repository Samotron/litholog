const std = @import("std");
const fuzzy = @import("fuzzy.zig");
const typos = @import("typos.zig");

pub const TokenType = enum {
    word,
    consistency_range, // "soft to firm", "firm to stiff", etc.
    consistency,
    density,
    proportion,
    soil_type,
    rock_type,
    rock_strength,
    weathering_grade,
    rock_structure,
    adjective, // sandy, clayey, etc.
    color,
    moisture_content,
    plasticity_index,
    particle_size,
    unknown,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
    start: usize,
    end: usize,
    corrected_from: ?[]const u8 = null, // Original typo if spelling was corrected
    similarity_score: ?f32 = null, // Fuzzy match score if corrected
};

// Classification result with potential correction
const ClassificationResult = struct {
    token_type: TokenType,
    corrected_value: ?[]const u8 = null,
    similarity_score: ?f32 = null,
};

pub const Lexer = struct {
    input: []const u8,
    tokens: std.ArrayList(Token),
    allocator: std.mem.Allocator,
    fuzzy_threshold: f32 = 0.80, // Threshold for fuzzy matching

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Lexer {
        return Lexer{
            .input = input,
            .tokens = std.ArrayList(Token).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }

    pub fn tokenize(self: *Lexer) ![]Token {
        var pos: usize = 0;

        while (pos < self.input.len) {
            // Skip whitespace
            while (pos < self.input.len and std.ascii.isWhitespace(self.input[pos])) {
                pos += 1;
            }

            if (pos >= self.input.len) break;

            // Try to match multi-word patterns first
            if (try self.matchConsistencyRange(&pos)) |token| {
                try self.tokens.append(token);
                continue;
            }

            if (try self.matchMultiWord(&pos)) |token| {
                try self.tokens.append(token);
                continue;
            }

            // Match single words
            const start = pos;
            while (pos < self.input.len and !std.ascii.isWhitespace(self.input[pos])) {
                pos += 1;
            }

            const word = self.input[start..pos];
            const classification = try self.classifyWord(word);

            try self.tokens.append(Token{
                .type = classification.token_type,
                .value = classification.corrected_value orelse word,
                .start = start,
                .end = pos,
                .corrected_from = if (classification.corrected_value != null) word else null,
                .similarity_score = classification.similarity_score,
            });
        }

        return self.tokens.toOwnedSlice();
    }

    fn matchConsistencyRange(self: *Lexer, pos: *usize) !?Token {
        const patterns = [_][]const u8{
            "soft to firm",
            "firm to stiff",
            "stiff to very stiff",
            "very soft to soft",
        };

        for (patterns) |pattern| {
            if (self.matchPattern(pattern, pos.*)) |end_pos| {
                const token = Token{
                    .type = .consistency_range,
                    .value = self.input[pos.*..end_pos],
                    .start = pos.*,
                    .end = end_pos,
                };
                pos.* = end_pos;
                return token;
            }
        }

        return null;
    }

    fn matchMultiWord(self: *Lexer, pos: *usize) !?Token {
        const patterns = [_]struct { pattern: []const u8, token_type: TokenType }{
            // Soil patterns
            .{ .pattern = "very soft", .token_type = .consistency },
            .{ .pattern = "very stiff", .token_type = .consistency },
            .{ .pattern = "very loose", .token_type = .density },
            .{ .pattern = "very dense", .token_type = .density },
            .{ .pattern = "medium dense", .token_type = .density },
            // Rock strength patterns
            .{ .pattern = "very weak", .token_type = .rock_strength },
            .{ .pattern = "moderately weak", .token_type = .rock_strength },
            .{ .pattern = "moderately strong", .token_type = .rock_strength },
            .{ .pattern = "very strong", .token_type = .rock_strength },
            .{ .pattern = "extremely strong", .token_type = .rock_strength },
            // Weathering grade patterns
            .{ .pattern = "slightly weathered", .token_type = .weathering_grade },
            .{ .pattern = "moderately weathered", .token_type = .weathering_grade },
            .{ .pattern = "highly weathered", .token_type = .weathering_grade },
            .{ .pattern = "completely weathered", .token_type = .weathering_grade },
            // Color patterns
            .{ .pattern = "dark gray", .token_type = .color },
            .{ .pattern = "dark grey", .token_type = .color },
            .{ .pattern = "light gray", .token_type = .color },
            .{ .pattern = "light grey", .token_type = .color },
            .{ .pattern = "dark brown", .token_type = .color },
            .{ .pattern = "light brown", .token_type = .color },
            .{ .pattern = "reddish brown", .token_type = .color },
            .{ .pattern = "yellowish brown", .token_type = .color },
            // Plasticity patterns
            .{ .pattern = "non plastic", .token_type = .plasticity_index },
            .{ .pattern = "non-plastic", .token_type = .plasticity_index },
            .{ .pattern = "low plasticity", .token_type = .plasticity_index },
            .{ .pattern = "intermediate plasticity", .token_type = .plasticity_index },
            .{ .pattern = "high plasticity", .token_type = .plasticity_index },
            .{ .pattern = "extremely high plasticity", .token_type = .plasticity_index },
            // Particle size patterns
            .{ .pattern = "fine to medium", .token_type = .particle_size },
            .{ .pattern = "medium to coarse", .token_type = .particle_size },
            .{ .pattern = "fine to coarse", .token_type = .particle_size },
        };

        // Try exact match first
        for (patterns) |pattern_info| {
            if (self.matchPattern(pattern_info.pattern, pos.*)) |end_pos| {
                const token = Token{
                    .type = pattern_info.token_type,
                    .value = self.input[pos.*..end_pos],
                    .start = pos.*,
                    .end = end_pos,
                };
                pos.* = end_pos;
                return token;
            }
        }

        // Try fuzzy matching on multi-word patterns (for minor typos)
        // Temporarily disabled for performance - only does exact matching now
        // TODO: Re-enable with better performance optimizations

        return null;
    }

    const FuzzyPatternMatch = struct {
        end_pos: usize,
        score: f32,
    };

    fn fuzzyMatchPattern(self: *Lexer, pattern: []const u8, start_pos: usize) !?FuzzyPatternMatch {
        // Only try fuzzy matching for patterns that are similar in length
        // Look ahead to get the next N characters where N is roughly the pattern length
        const search_length = @min(pattern.len + 5, self.input.len - start_pos);
        if (search_length < pattern.len - 3) return null; // Too short

        // Find the end of the potential multi-word match (up to next punctuation or significant whitespace)
        var end_pos = start_pos;
        var word_count: usize = 0;
        const target_words = std.mem.count(u8, pattern, " ") + 1;

        while (end_pos < self.input.len and word_count <= target_words + 1) {
            if (self.input[end_pos] == ',' or self.input[end_pos] == '.') break;

            // Count words
            if (end_pos > start_pos and std.ascii.isWhitespace(self.input[end_pos - 1]) and !std.ascii.isWhitespace(self.input[end_pos])) {
                word_count += 1;
            }

            end_pos += 1;

            // If we have enough words, check if this is a good match
            if (word_count >= target_words) {
                // Trim to word boundary
                while (end_pos < self.input.len and !std.ascii.isWhitespace(self.input[end_pos])) {
                    end_pos += 1;
                }

                const candidate = self.input[start_pos..end_pos];
                const score = try fuzzy.similarityRatio(candidate, pattern, self.allocator);

                // Use a higher threshold for multi-word patterns to avoid false positives
                if (score >= 0.85) {
                    return FuzzyPatternMatch{
                        .end_pos = end_pos,
                        .score = score,
                    };
                }

                break;
            }
        }

        return null;
    }

    fn matchPattern(self: *Lexer, pattern: []const u8, start_pos: usize) ?usize {
        if (start_pos + pattern.len > self.input.len) return null;

        const slice = self.input[start_pos .. start_pos + pattern.len];
        var lower_buf: [64]u8 = undefined;
        if (slice.len >= lower_buf.len) return null;

        const lower_slice = std.ascii.lowerString(lower_buf[0..slice.len], slice);
        var lower_pattern_buf: [64]u8 = undefined;
        if (pattern.len >= lower_pattern_buf.len) return null;

        const lower_pattern = std.ascii.lowerString(lower_pattern_buf[0..pattern.len], pattern);

        if (std.mem.eql(u8, lower_slice, lower_pattern)) {
            // Check word boundaries
            const end_pos = start_pos + pattern.len;
            if (end_pos < self.input.len and !std.ascii.isWhitespace(self.input[end_pos])) {
                return null; // Not a complete word
            }
            if (start_pos > 0 and !std.ascii.isWhitespace(self.input[start_pos - 1])) {
                return null; // Not at word boundary
            }
            return end_pos;
        }

        return null;
    }

    fn classifyWord(self: *Lexer, word: []const u8) !ClassificationResult {
        var lower_buf: [64]u8 = undefined;
        if (word.len >= lower_buf.len) return ClassificationResult{ .token_type = .unknown };

        const lower = std.ascii.lowerString(lower_buf[0..word.len], word);

        // Try exact matches first for performance
        const exact_result = self.tryExactMatch(lower);
        if (exact_result.token_type != .word) {
            return exact_result;
        }

        // Check common typo dictionary for fast correction
        if (typos.lookupTypo(lower)) |corrected| {
            // Found in typo dictionary, now classify the corrected word
            const corrected_result = self.tryExactMatch(corrected);
            if (corrected_result.token_type != .word) {
                // Allocate corrected value
                const corrected_owned = try self.allocator.dupe(u8, corrected);
                return ClassificationResult{
                    .token_type = corrected_result.token_type,
                    .corrected_value = corrected_owned,
                    .similarity_score = 0.95, // High score for known typos
                };
            }
        }

        // Only try fuzzy matching if the word looks like it might be a geological term
        // (within reasonable length range and starts with common geological term letters)
        if (self.mightBeGeologicalTerm(lower)) {
            return try self.tryFuzzyMatch(lower);
        }

        // Otherwise, just return as word
        return ClassificationResult{ .token_type = .word };
    }

    fn mightBeGeologicalTerm(self: *Lexer, word: []const u8) bool {
        _ = self;
        // Skip fuzzy matching for very short or very long words
        if (word.len < 3 or word.len > 15) return false;

        // Only consider words that start with common geological term letters
        // This quickly filters out most non-geological words
        const first_char = word[0];
        const geological_starts = "bcdfglmoprstwh"; // First letters of common terms

        for (geological_starts) |c| {
            if (first_char == c) return true;
        }

        return false;
    }

    fn tryExactMatch(self: *Lexer, lower: []const u8) ClassificationResult {
        _ = self;

        // Consistency
        const consistencies = [_][]const u8{ "soft", "firm", "stiff", "hard" };
        for (consistencies) |c| {
            if (std.mem.eql(u8, lower, c)) return .{ .token_type = .consistency };
        }

        // Density
        const densities = [_][]const u8{ "loose", "dense" };
        for (densities) |d| {
            if (std.mem.eql(u8, lower, d)) return .{ .token_type = .density };
        }

        // Rock strength
        const rock_strengths = [_][]const u8{ "weak", "strong" };
        for (rock_strengths) |rs| {
            if (std.mem.eql(u8, lower, rs)) return .{ .token_type = .rock_strength };
        }

        // Weathering grade
        const weathering_grades = [_][]const u8{ "fresh", "weathered" };
        for (weathering_grades) |wg| {
            if (std.mem.eql(u8, lower, wg)) return .{ .token_type = .weathering_grade };
        }

        // Rock structure
        const rock_structures = [_][]const u8{ "massive", "bedded", "jointed", "fractured", "foliated", "laminated" };
        for (rock_structures) |rs| {
            if (std.mem.eql(u8, lower, rs)) return .{ .token_type = .rock_structure };
        }

        // Proportions
        const proportions = [_][]const u8{ "slightly", "moderately", "very" };
        for (proportions) |p| {
            if (std.mem.eql(u8, lower, p)) return .{ .token_type = .proportion };
        }

        // Soil types
        const soil_types = [_][]const u8{ "clay", "silt", "sand", "gravel", "peat", "organic" };
        for (soil_types) |st| {
            if (std.mem.eql(u8, lower, st)) return .{ .token_type = .soil_type };
        }

        // Rock types
        const rock_types = [_][]const u8{ "limestone", "sandstone", "mudstone", "shale", "granite", "basalt", "chalk", "dolomite", "quartzite", "slate", "schist", "gneiss", "marble", "conglomerate", "breccia" };
        for (rock_types) |rt| {
            if (std.mem.eql(u8, lower, rt)) return .{ .token_type = .rock_type };
        }

        // Adjectives
        const adjectives = [_][]const u8{ "sandy", "silty", "clayey", "gravelly" };
        for (adjectives) |adj| {
            if (std.mem.eql(u8, lower, adj)) return .{ .token_type = .adjective };
        }

        // Colors
        const colors = [_][]const u8{ "gray", "grey", "brown", "red", "yellow", "orange", "black", "white", "green", "blue", "pink", "purple", "tan", "buff" };
        for (colors) |color| {
            if (std.mem.eql(u8, lower, color)) return .{ .token_type = .color };
        }

        // Moisture content
        const moisture_contents = [_][]const u8{ "dry", "moist", "wet", "saturated" };
        for (moisture_contents) |mc| {
            if (std.mem.eql(u8, lower, mc)) return .{ .token_type = .moisture_content };
        }

        // Particle size
        const particle_sizes = [_][]const u8{ "fine", "medium", "coarse" };
        for (particle_sizes) |ps| {
            if (std.mem.eql(u8, lower, ps)) return .{ .token_type = .particle_size };
        }

        return .{ .token_type = .word };
    }

    fn tryFuzzyMatch(self: *Lexer, lower: []const u8) !ClassificationResult {
        // Skip fuzzy matching for very short or very long words (likely not typos)
        if (lower.len < 3 or lower.len > 20) {
            return ClassificationResult{ .token_type = .word };
        }

        // Define all term categories with their types
        const categories = [_]struct {
            terms: []const []const u8,
            token_type: TokenType,
        }{
            .{ .terms = &[_][]const u8{ "soft", "firm", "stiff", "hard" }, .token_type = .consistency },
            .{ .terms = &[_][]const u8{ "loose", "dense" }, .token_type = .density },
            .{ .terms = &[_][]const u8{ "weak", "strong" }, .token_type = .rock_strength },
            .{ .terms = &[_][]const u8{ "fresh", "weathered" }, .token_type = .weathering_grade },
            .{ .terms = &[_][]const u8{ "massive", "bedded", "jointed", "fractured", "foliated", "laminated" }, .token_type = .rock_structure },
            .{ .terms = &[_][]const u8{ "slightly", "moderately", "very" }, .token_type = .proportion },
            .{ .terms = &[_][]const u8{ "clay", "silt", "sand", "gravel", "peat", "organic" }, .token_type = .soil_type },
            .{ .terms = &[_][]const u8{ "limestone", "sandstone", "mudstone", "shale", "granite", "basalt", "chalk", "dolomite", "quartzite", "slate", "schist", "gneiss", "marble", "conglomerate", "breccia" }, .token_type = .rock_type },
            .{ .terms = &[_][]const u8{ "sandy", "silty", "clayey", "gravelly" }, .token_type = .adjective },
            .{ .terms = &[_][]const u8{ "gray", "grey", "brown", "red", "yellow", "orange", "black", "white", "green", "blue", "pink", "purple", "tan", "buff" }, .token_type = .color },
            .{ .terms = &[_][]const u8{ "dry", "moist", "wet", "saturated" }, .token_type = .moisture_content },
            .{ .terms = &[_][]const u8{ "fine", "medium", "coarse" }, .token_type = .particle_size },
        };

        var best_match: ?struct {
            term: []const u8,
            token_type: TokenType,
            score: f32,
        } = null;

        // Search across all categories for best match
        // Only check terms with similar length (within 3 characters) for performance
        for (categories) |category| {
            for (category.terms) |term| {
                // Quick length check before expensive fuzzy matching
                const len_diff = if (lower.len > term.len) lower.len - term.len else term.len - lower.len;
                if (len_diff > 3) continue; // Too different in length

                // Quick first-letter check (most typos preserve first letter)
                if (lower[0] != term[0]) continue;

                const score = try fuzzy.similarityRatio(lower, term, self.allocator);
                if (score >= self.fuzzy_threshold) {
                    if (best_match == null or score > best_match.?.score) {
                        best_match = .{
                            .term = term,
                            .token_type = category.token_type,
                            .score = score,
                        };
                    }
                }
            }
        }

        if (best_match) |match| {
            // Allocate corrected value
            const corrected = try self.allocator.dupe(u8, match.term);
            return ClassificationResult{
                .token_type = match.token_type,
                .corrected_value = corrected,
                .similarity_score = match.score,
            };
        }

        return ClassificationResult{ .token_type = .word };
    }
};
