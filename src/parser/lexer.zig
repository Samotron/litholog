const std = @import("std");

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
};

pub const Lexer = struct {
    input: []const u8,
    tokens: std.ArrayList(Token),
    allocator: std.mem.Allocator,

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
            const token_type = self.classifyWord(word);

            try self.tokens.append(Token{
                .type = token_type,
                .value = word,
                .start = start,
                .end = pos,
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

    fn classifyWord(self: *Lexer, word: []const u8) TokenType {
        _ = self;
        var lower_buf: [64]u8 = undefined;
        if (word.len >= lower_buf.len) return .unknown;

        const lower = std.ascii.lowerString(lower_buf[0..word.len], word);

        // Consistency
        const consistencies = [_][]const u8{ "soft", "firm", "stiff", "hard" };
        for (consistencies) |c| {
            if (std.mem.eql(u8, lower, c)) return .consistency;
        }

        // Density
        const densities = [_][]const u8{ "loose", "dense" };
        for (densities) |d| {
            if (std.mem.eql(u8, lower, d)) return .density;
        }

        // Rock strength
        const rock_strengths = [_][]const u8{ "weak", "strong" };
        for (rock_strengths) |rs| {
            if (std.mem.eql(u8, lower, rs)) return .rock_strength;
        }

        // Weathering grade
        const weathering_grades = [_][]const u8{ "fresh", "weathered" };
        for (weathering_grades) |wg| {
            if (std.mem.eql(u8, lower, wg)) return .weathering_grade;
        }

        // Rock structure
        const rock_structures = [_][]const u8{ "massive", "bedded", "jointed", "fractured", "foliated", "laminated" };
        for (rock_structures) |rs| {
            if (std.mem.eql(u8, lower, rs)) return .rock_structure;
        }

        // Proportions
        const proportions = [_][]const u8{ "slightly", "moderately", "very" };
        for (proportions) |p| {
            if (std.mem.eql(u8, lower, p)) return .proportion;
        }

        // Soil types
        const soil_types = [_][]const u8{ "clay", "silt", "sand", "gravel", "peat", "organic" };
        for (soil_types) |st| {
            if (std.mem.eql(u8, lower, st)) return .soil_type;
        }

        // Rock types
        const rock_types = [_][]const u8{ "limestone", "sandstone", "mudstone", "shale", "granite", "basalt", "chalk", "dolomite", "quartzite", "slate", "schist", "gneiss", "marble", "conglomerate", "breccia" };
        for (rock_types) |rt| {
            if (std.mem.eql(u8, lower, rt)) return .rock_type;
        }

        // Adjectives
        const adjectives = [_][]const u8{ "sandy", "silty", "clayey", "gravelly" };
        for (adjectives) |adj| {
            if (std.mem.eql(u8, lower, adj)) return .adjective;
        }

        // Colors
        const colors = [_][]const u8{ "gray", "grey", "brown", "red", "yellow", "orange", "black", "white", "green", "blue", "pink", "purple", "tan", "buff" };
        for (colors) |color| {
            if (std.mem.eql(u8, lower, color)) return .color;
        }

        // Moisture content
        const moisture_contents = [_][]const u8{ "dry", "moist", "wet", "saturated" };
        for (moisture_contents) |mc| {
            if (std.mem.eql(u8, lower, mc)) return .moisture_content;
        }

        // Particle size
        const particle_sizes = [_][]const u8{ "fine", "medium", "coarse" };
        for (particle_sizes) |ps| {
            if (std.mem.eql(u8, lower, ps)) return .particle_size;
        }

        return .word;
    }
};
