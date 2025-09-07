const std = @import("std");
const types = @import("types.zig");
const terminology = @import("terminology.zig");
const lexer = @import("lexer.zig");
const strength_db = @import("strength_db.zig");
const constituent_db = @import("constituent_db.zig");
const validation = @import("validation.zig");

pub const SoilDescription = types.SoilDescription;
const MaterialType = types.MaterialType;
const SoilType = types.SoilType;
const RockType = types.RockType;
const Consistency = types.Consistency;
const Density = types.Density;
const RockStrength = types.RockStrength;
const WeatheringGrade = types.WeatheringGrade;
const RockStructure = types.RockStructure;
const SecondaryConstituent = types.SecondaryConstituent;
const Token = lexer.Token;
const TokenType = lexer.TokenType;
const Lexer = lexer.Lexer;
const StrengthDatabase = strength_db.StrengthDatabase;
const ConstituentDatabase = constituent_db.ConstituentDatabase;
const Validator = validation.Validator;

pub const Parser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Parser {
        return Parser{ .allocator = allocator };
    }

    pub fn parse(self: *Parser, description: []const u8) !SoilDescription {
        // Clone the description to avoid memory issues
        const owned_description = try self.allocator.dupe(u8, description);

        var lex = Lexer.init(self.allocator, description);
        defer lex.deinit();

        const tokens = try lex.tokenize();
        defer self.allocator.free(tokens);

        // Determine material type by checking for rock or soil indicators
        const material_type = self.determineMaterialType(tokens);

        var result = SoilDescription{
            .raw_description = owned_description,
            .material_type = material_type,
        };

        result = try self.parseTokens(tokens, result);

        // Validate the parsed description
        var validator = Validator.init(self.allocator);
        try validator.validate(&result);

        return result;
    }

    fn determineMaterialType(self: *Parser, tokens: []Token) MaterialType {
        _ = self;

        // Check for rock-specific tokens
        for (tokens) |token| {
            switch (token.type) {
                .rock_type, .rock_strength, .weathering_grade, .rock_structure => {
                    return .rock;
                },
                else => {},
            }
        }

        // Check for rock type names in word tokens
        for (tokens) |token| {
            if (token.type == .word) {
                if (RockType.fromString(token.value) != null) {
                    return .rock;
                }
            }
        }

        // Default to soil if no rock indicators found
        return .soil;
    }

    fn parseTokens(self: *Parser, tokens: []Token, result: SoilDescription) !SoilDescription {
        var parsed = result;
        var i: usize = 0;
        var secondary_constituents = std.ArrayList(SecondaryConstituent).init(self.allocator);
        defer secondary_constituents.deinit();

        while (i < tokens.len) {
            const token = tokens[i];

            switch (token.type) {
                .consistency_range, .consistency => {
                    if (parsed.material_type == .soil and parsed.consistency == null) {
                        if (Consistency.fromString(token.value)) |consistency| {
                            parsed.consistency = consistency;
                        }
                    }
                    i += 1;
                },
                .density => {
                    if (parsed.material_type == .soil and parsed.density == null) {
                        if (Density.fromString(token.value)) |density| {
                            parsed.density = density;
                        }
                    }
                    i += 1;
                },
                .rock_strength => {
                    if (parsed.material_type == .rock and parsed.rock_strength == null) {
                        if (RockStrength.fromString(token.value)) |strength| {
                            parsed.rock_strength = strength;
                        }
                    }
                    i += 1;
                },
                .weathering_grade => {
                    if (parsed.material_type == .rock and parsed.weathering_grade == null) {
                        if (WeatheringGrade.fromString(token.value)) |weathering| {
                            parsed.weathering_grade = weathering;
                        }
                    }
                    i += 1;
                },
                .rock_structure => {
                    if (parsed.material_type == .rock and parsed.rock_structure == null) {
                        if (RockStructure.fromString(token.value)) |structure| {
                            parsed.rock_structure = structure;
                        }
                    }
                    i += 1;
                },
                .rock_type => {
                    if (parsed.material_type == .rock and parsed.primary_rock_type == null) {
                        if (RockType.fromString(token.value)) |rock_type| {
                            parsed.primary_rock_type = rock_type;
                        }
                    }
                    i += 1;
                },
                .proportion => {
                    // Look ahead for adjective or soil type
                    if (i + 1 < tokens.len) {
                        const next_token = tokens[i + 1];
                        if (next_token.type == .adjective or next_token.type == .soil_type) {
                            if (self.parseSecondaryConstituent(tokens, i)) |sc_result| {
                                try secondary_constituents.append(sc_result.constituent);
                                i += sc_result.tokens_consumed;
                                continue;
                            }
                        }
                    }
                    i += 1;
                },
                .adjective => {
                    if (self.parseStandaloneSecondaryConstituent(token.value)) |constituent| {
                        try secondary_constituents.append(constituent);
                    }
                    i += 1;
                },
                .soil_type => {
                    if (parsed.material_type == .soil and parsed.primary_soil_type == null) {
                        if (SoilType.fromString(token.value)) |soil_type| {
                            parsed.primary_soil_type = soil_type;
                        }
                    }
                    i += 1;
                },
                .color => {
                    if (parsed.color == null) {
                        if (types.Color.fromString(token.value)) |color| {
                            parsed.color = color;
                        }
                    }
                    i += 1;
                },
                .moisture_content => {
                    if (parsed.moisture_content == null) {
                        if (types.MoistureContent.fromString(token.value)) |moisture| {
                            parsed.moisture_content = moisture;
                        }
                    }
                    i += 1;
                },
                .plasticity_index => {
                    if (parsed.plasticity_index == null) {
                        if (types.PlasticityIndex.fromString(token.value)) |plasticity| {
                            parsed.plasticity_index = plasticity;
                        }
                    }
                    i += 1;
                },
                .particle_size => {
                    if (parsed.particle_size == null) {
                        if (types.ParticleSize.fromString(token.value)) |particle_size| {
                            parsed.particle_size = particle_size;
                        }
                    }
                    i += 1;
                },
                .word => {
                    // Check if it's an uppercase soil or rock type we missed
                    if (parsed.material_type == .soil and parsed.primary_soil_type == null) {
                        if (SoilType.fromString(token.value)) |soil_type| {
                            parsed.primary_soil_type = soil_type;
                        }
                    } else if (parsed.material_type == .rock and parsed.primary_rock_type == null) {
                        if (RockType.fromString(token.value)) |rock_type| {
                            parsed.primary_rock_type = rock_type;
                        }
                    }
                    i += 1;
                },
                .unknown => {
                    i += 1;
                },
            }
        }

        parsed.secondary_constituents = try secondary_constituents.toOwnedSlice();

        // Lookup strength parameters based on parsed properties
        parsed.strength_parameters = StrengthDatabase.getStrengthParameters(
            parsed.material_type,
            parsed.consistency,
            parsed.density,
            parsed.rock_strength,
            parsed.primary_soil_type,
        );

        // Lookup constituent guidance for soil materials
        if (parsed.material_type == .soil) {
            parsed.constituent_guidance = ConstituentDatabase.getConstituentGuidance(
                self.allocator,
                parsed.primary_soil_type,
                parsed.secondary_constituents,
            ) catch null;
        }

        return parsed;
    }

    const SecondaryConstituentResult = struct {
        constituent: SecondaryConstituent,
        tokens_consumed: usize,
    };

    fn parseSecondaryConstituent(_: *Parser, tokens: []Token, start_idx: usize) ?SecondaryConstituentResult {
        if (start_idx + 1 >= tokens.len) return null;

        const proportion_token = tokens[start_idx];
        const soil_type_token = tokens[start_idx + 1];

        if (proportion_token.type != .proportion) return null;

        // Convert soil type to adjective form
        const soil_type_adj = blk: {
            var lower_buf: [32]u8 = undefined;
            if (soil_type_token.value.len >= lower_buf.len) break :blk soil_type_token.value;
            const lower = std.ascii.lowerString(lower_buf[0..soil_type_token.value.len], soil_type_token.value);

            if (std.mem.eql(u8, lower, "sand")) break :blk "sandy";
            if (std.mem.eql(u8, lower, "silt")) break :blk "silty";
            if (std.mem.eql(u8, lower, "clay")) break :blk "clayey";
            if (std.mem.eql(u8, lower, "gravel")) break :blk "gravelly";
            break :blk soil_type_token.value; // Use as-is if already adjective form
        };

        return SecondaryConstituentResult{
            .constituent = SecondaryConstituent{
                .amount = proportion_token.value,
                .soil_type = soil_type_adj,
            },
            .tokens_consumed = 2,
        };
    }

    fn parseStandaloneSecondaryConstituent(_: *Parser, token_value: []const u8) ?SecondaryConstituent {
        var lower_buf: [32]u8 = undefined;
        if (token_value.len >= lower_buf.len) return null;
        const lower = std.ascii.lowerString(lower_buf[0..token_value.len], token_value);

        // Default to "moderately" for standalone adjectives
        const amount = "moderately";

        if (std.mem.eql(u8, lower, "sandy")) {
            return SecondaryConstituent{
                .amount = amount,
                .soil_type = "sandy",
            };
        }
        if (std.mem.eql(u8, lower, "silty")) {
            return SecondaryConstituent{
                .amount = amount,
                .soil_type = "silty",
            };
        }
        if (std.mem.eql(u8, lower, "clayey")) {
            return SecondaryConstituent{
                .amount = amount,
                .soil_type = "clayey",
            };
        }
        if (std.mem.eql(u8, lower, "gravelly")) {
            return SecondaryConstituent{
                .amount = amount,
                .soil_type = "gravelly",
            };
        }

        return null;
    }
};

test "parse simple clay description" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Firm CLAY");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.consistency.? == .firm);
    try std.testing.expect(result.primary_soil_type.? == .clay);
}

test "parse simple rock description" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Strong LIMESTONE");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .rock);
    try std.testing.expect(result.rock_strength.? == .strong);
    try std.testing.expect(result.primary_rock_type.? == .limestone);
}

test "parse rock with weathering" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Moderately strong slightly weathered SANDSTONE");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .rock);
    try std.testing.expect(result.rock_strength.? == .moderately_strong);
    try std.testing.expect(result.weathering_grade.? == .slightly_weathered);
    try std.testing.expect(result.primary_rock_type.? == .sandstone);
}

test "parse jointed rock" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Weak highly weathered jointed MUDSTONE");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .rock);
    try std.testing.expect(result.rock_strength.? == .weak);
    try std.testing.expect(result.weathering_grade.? == .highly_weathered);
    try std.testing.expect(result.rock_structure.? == .jointed);
    try std.testing.expect(result.primary_rock_type.? == .mudstone);
}

test "parse consistency range" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("soft to firm very sandy clay");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.consistency.? == .soft_to_firm);
    try std.testing.expect(result.primary_soil_type.? == .clay);
    try std.testing.expect(result.secondary_constituents.len == 1);
}

test "parse complex soil description" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Firm to stiff slightly sandy gravelly CLAY");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.consistency.? == .firm_to_stiff);
    try std.testing.expect(result.primary_soil_type.? == .clay);
    try std.testing.expect(result.secondary_constituents.len == 2);

    // Check strength parameters
    try std.testing.expect(result.strength_parameters != null);
    try std.testing.expect(result.strength_parameters.?.parameter_type == .undrained_shear_strength);
    try std.testing.expect(result.strength_parameters.?.range.lower_bound == 25);
    try std.testing.expect(result.strength_parameters.?.range.upper_bound == 100);
}

test "parse soil with strength parameters - cohesive" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Firm CLAY");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.strength_parameters != null);
    try std.testing.expect(result.strength_parameters.?.parameter_type == .undrained_shear_strength);
    try std.testing.expect(result.strength_parameters.?.range.lower_bound == 25);
    try std.testing.expect(result.strength_parameters.?.range.upper_bound == 50);
    try std.testing.expect(result.strength_parameters.?.range.typical_value.? == 37);
}

test "parse soil with strength parameters - granular" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Dense SAND");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.strength_parameters != null);
    try std.testing.expect(result.strength_parameters.?.parameter_type == .spt_n_value);
    try std.testing.expect(result.strength_parameters.?.range.lower_bound == 30);
    try std.testing.expect(result.strength_parameters.?.range.upper_bound == 50);
}

test "parse rock with strength parameters" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Strong LIMESTONE");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .rock);
    try std.testing.expect(result.strength_parameters != null);
    try std.testing.expect(result.strength_parameters.?.parameter_type == .ucs);
    try std.testing.expect(result.strength_parameters.?.range.lower_bound == 50.0);
    try std.testing.expect(result.strength_parameters.?.range.upper_bound == 100.0);
}

test "validation - cohesive soil with consistency passes" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Firm CLAY");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.primary_soil_type.? == .clay);
    try std.testing.expect(result.consistency.? == .firm);
    try std.testing.expect(result.warnings.len == 0);
    try std.testing.expect(result.confidence == 1.0);
}

test "validation - cohesive soil missing consistency generates warning" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("CLAY");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.primary_soil_type.? == .clay);
    try std.testing.expect(result.consistency == null);
    try std.testing.expect(result.warnings.len == 1);
    try std.testing.expect(result.confidence < 1.0);
    try std.testing.expect(std.mem.indexOf(u8, result.warnings[0], "consistency descriptor") != null);
}

test "validation - granular soil with density passes" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Dense SAND");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.primary_soil_type.? == .sand);
    try std.testing.expect(result.density.? == .dense);
    try std.testing.expect(result.warnings.len == 0);
    try std.testing.expect(result.confidence == 1.0);
}

test "validation - granular soil missing density generates warning" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("SAND");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.primary_soil_type.? == .sand);
    try std.testing.expect(result.density == null);
    try std.testing.expect(result.warnings.len == 1);
    try std.testing.expect(result.confidence < 1.0);
    try std.testing.expect(std.mem.indexOf(u8, result.warnings[0], "density descriptor") != null);
}

test "validation - cohesive soil with wrong strength descriptor" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Dense CLAY");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.primary_soil_type.? == .clay);
    try std.testing.expect(result.density.? == .dense);
    try std.testing.expect(result.consistency == null);
    try std.testing.expect(result.warnings.len == 2); // Missing consistency + has density
    try std.testing.expect(result.confidence < 1.0);
}

test "parse soil with constituent guidance" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Firm slightly sandy CLAY");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.consistency.? == .firm);
    try std.testing.expect(result.primary_soil_type.? == .clay);
    try std.testing.expect(result.secondary_constituents.len == 1);

    // Check constituent guidance
    try std.testing.expect(result.constituent_guidance != null);
    try std.testing.expect(result.constituent_guidance.?.constituents.len == 2);

    // Primary constituent should be clay
    try std.testing.expect(std.mem.eql(u8, result.constituent_guidance.?.constituents[0].soil_type, "clay"));
    // Secondary constituent should be sandy
    try std.testing.expect(std.mem.eql(u8, result.constituent_guidance.?.constituents[1].soil_type, "sandy"));
}

test "parse complex soil with constituent guidance" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator);

    const result = try parser.parse("Firm to stiff slightly sandy very gravelly CLAY");
    defer result.deinit(allocator);

    try std.testing.expect(result.material_type == .soil);
    try std.testing.expect(result.consistency.? == .firm_to_stiff);
    try std.testing.expect(result.primary_soil_type.? == .clay);
    try std.testing.expect(result.secondary_constituents.len == 2);

    // Check constituent guidance
    try std.testing.expect(result.constituent_guidance != null);
    try std.testing.expect(result.constituent_guidance.?.constituents.len == 3);

    // Should have clay as primary, sandy and gravelly as secondary
    var found_clay = false;
    var found_sandy = false;
    var found_gravelly = false;

    for (result.constituent_guidance.?.constituents) |constituent| {
        if (std.mem.eql(u8, constituent.soil_type, "clay")) found_clay = true;
        if (std.mem.eql(u8, constituent.soil_type, "sandy")) found_sandy = true;
        if (std.mem.eql(u8, constituent.soil_type, "gravelly")) found_gravelly = true;
    }

    try std.testing.expect(found_clay);
    try std.testing.expect(found_sandy);
    try std.testing.expect(found_gravelly);
}
