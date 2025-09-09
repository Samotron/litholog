const std = @import("std");
const builtin = @import("builtin");

pub const MaterialType = enum {
    soil,
    rock,

    pub fn toString(self: MaterialType) []const u8 {
        return switch (self) {
            .soil => "soil",
            .rock => "rock",
        };
    }
};

// Forward declarations for database modules
pub const StrengthParameters = @import("strength_db.zig").StrengthParameters;
pub const ConstituentGuidance = @import("constituent_db.zig").ConstituentGuidance;

pub const Consistency = enum {
    very_soft,
    soft,
    firm,
    stiff,
    very_stiff,
    hard,
    // Range types
    soft_to_firm,
    firm_to_stiff,
    stiff_to_very_stiff,

    pub fn fromString(str: []const u8) ?Consistency {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "very soft")) return .very_soft;
        if (std.mem.eql(u8, lower, "soft")) return .soft;
        if (std.mem.eql(u8, lower, "firm")) return .firm;
        if (std.mem.eql(u8, lower, "stiff")) return .stiff;
        if (std.mem.eql(u8, lower, "very stiff")) return .very_stiff;
        if (std.mem.eql(u8, lower, "hard")) return .hard;

        // Handle ranges as separate values
        if (std.mem.eql(u8, lower, "soft to firm")) return .soft_to_firm;
        if (std.mem.eql(u8, lower, "firm to stiff")) return .firm_to_stiff;
        if (std.mem.eql(u8, lower, "stiff to very stiff")) return .stiff_to_very_stiff;

        return null;
    }

    pub fn toString(self: Consistency) []const u8 {
        return switch (self) {
            .very_soft => "very soft",
            .soft => "soft",
            .firm => "firm",
            .stiff => "stiff",
            .very_stiff => "very stiff",
            .hard => "hard",
            .soft_to_firm => "soft to firm",
            .firm_to_stiff => "firm to stiff",
            .stiff_to_very_stiff => "stiff to very stiff",
        };
    }
};

pub const Density = enum {
    very_loose,
    loose,
    medium_dense,
    dense,
    very_dense,

    pub fn fromString(str: []const u8) ?Density {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "very loose")) return .very_loose;
        if (std.mem.eql(u8, lower, "loose")) return .loose;
        if (std.mem.eql(u8, lower, "medium dense")) return .medium_dense;
        if (std.mem.eql(u8, lower, "dense")) return .dense;
        if (std.mem.eql(u8, lower, "very dense")) return .very_dense;

        return null;
    }

    pub fn toString(self: Density) []const u8 {
        return switch (self) {
            .very_loose => "very loose",
            .loose => "loose",
            .medium_dense => "medium dense",
            .dense => "dense",
            .very_dense => "very dense",
        };
    }
};

pub const RockType = enum {
    limestone,
    sandstone,
    mudstone,
    shale,
    granite,
    basalt,
    chalk,
    dolomite,
    quartzite,
    slate,
    schist,
    gneiss,
    marble,
    conglomerate,
    breccia,

    pub fn fromString(str: []const u8) ?RockType {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "limestone")) return .limestone;
        if (std.mem.eql(u8, lower, "sandstone")) return .sandstone;
        if (std.mem.eql(u8, lower, "mudstone")) return .mudstone;
        if (std.mem.eql(u8, lower, "shale")) return .shale;
        if (std.mem.eql(u8, lower, "granite")) return .granite;
        if (std.mem.eql(u8, lower, "basalt")) return .basalt;
        if (std.mem.eql(u8, lower, "chalk")) return .chalk;
        if (std.mem.eql(u8, lower, "dolomite")) return .dolomite;
        if (std.mem.eql(u8, lower, "quartzite")) return .quartzite;
        if (std.mem.eql(u8, lower, "slate")) return .slate;
        if (std.mem.eql(u8, lower, "schist")) return .schist;
        if (std.mem.eql(u8, lower, "gneiss")) return .gneiss;
        if (std.mem.eql(u8, lower, "marble")) return .marble;
        if (std.mem.eql(u8, lower, "conglomerate")) return .conglomerate;
        if (std.mem.eql(u8, lower, "breccia")) return .breccia;

        return null;
    }

    pub fn toString(self: RockType) []const u8 {
        return switch (self) {
            .limestone => "LIMESTONE",
            .sandstone => "SANDSTONE",
            .mudstone => "MUDSTONE",
            .shale => "SHALE",
            .granite => "GRANITE",
            .basalt => "BASALT",
            .chalk => "CHALK",
            .dolomite => "DOLOMITE",
            .quartzite => "QUARTZITE",
            .slate => "SLATE",
            .schist => "SCHIST",
            .gneiss => "GNEISS",
            .marble => "MARBLE",
            .conglomerate => "CONGLOMERATE",
            .breccia => "BRECCIA",
        };
    }
};

pub const RockStrength = enum {
    very_weak,
    weak,
    moderately_weak,
    moderately_strong,
    strong,
    very_strong,
    extremely_strong,

    pub fn fromString(str: []const u8) ?RockStrength {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "very weak")) return .very_weak;
        if (std.mem.eql(u8, lower, "weak")) return .weak;
        if (std.mem.eql(u8, lower, "moderately weak")) return .moderately_weak;
        if (std.mem.eql(u8, lower, "moderately strong")) return .moderately_strong;
        if (std.mem.eql(u8, lower, "strong")) return .strong;
        if (std.mem.eql(u8, lower, "very strong")) return .very_strong;
        if (std.mem.eql(u8, lower, "extremely strong")) return .extremely_strong;

        return null;
    }

    pub fn toString(self: RockStrength) []const u8 {
        return switch (self) {
            .very_weak => "very weak",
            .weak => "weak",
            .moderately_weak => "moderately weak",
            .moderately_strong => "moderately strong",
            .strong => "strong",
            .very_strong => "very strong",
            .extremely_strong => "extremely strong",
        };
    }
};

pub const WeatheringGrade = enum {
    fresh,
    slightly_weathered,
    moderately_weathered,
    highly_weathered,
    completely_weathered,

    pub fn fromString(str: []const u8) ?WeatheringGrade {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "fresh")) return .fresh;
        if (std.mem.eql(u8, lower, "slightly weathered")) return .slightly_weathered;
        if (std.mem.eql(u8, lower, "moderately weathered")) return .moderately_weathered;
        if (std.mem.eql(u8, lower, "highly weathered")) return .highly_weathered;
        if (std.mem.eql(u8, lower, "completely weathered")) return .completely_weathered;

        return null;
    }

    pub fn toString(self: WeatheringGrade) []const u8 {
        return switch (self) {
            .fresh => "fresh",
            .slightly_weathered => "slightly weathered",
            .moderately_weathered => "moderately weathered",
            .highly_weathered => "highly weathered",
            .completely_weathered => "completely weathered",
        };
    }
};

pub const RockStructure = enum {
    massive,
    bedded,
    jointed,
    fractured,
    foliated,
    laminated,

    pub fn fromString(str: []const u8) ?RockStructure {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "massive")) return .massive;
        if (std.mem.eql(u8, lower, "bedded")) return .bedded;
        if (std.mem.eql(u8, lower, "jointed")) return .jointed;
        if (std.mem.eql(u8, lower, "fractured")) return .fractured;
        if (std.mem.eql(u8, lower, "foliated")) return .foliated;
        if (std.mem.eql(u8, lower, "laminated")) return .laminated;

        return null;
    }

    pub fn toString(self: RockStructure) []const u8 {
        return switch (self) {
            .massive => "massive",
            .bedded => "bedded",
            .jointed => "jointed",
            .fractured => "fractured",
            .foliated => "foliated",
            .laminated => "laminated",
        };
    }
};

pub const Color = enum {
    gray,
    grey,
    brown,
    red,
    yellow,
    orange,
    black,
    white,
    green,
    blue,
    pink,
    purple,
    tan,
    buff,
    dark_gray,
    light_gray,
    dark_brown,
    light_brown,
    reddish_brown,
    yellowish_brown,

    pub fn fromString(str: []const u8) ?Color {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "gray")) return .gray;
        if (std.mem.eql(u8, lower, "grey")) return .grey;
        if (std.mem.eql(u8, lower, "brown")) return .brown;
        if (std.mem.eql(u8, lower, "red")) return .red;
        if (std.mem.eql(u8, lower, "yellow")) return .yellow;
        if (std.mem.eql(u8, lower, "orange")) return .orange;
        if (std.mem.eql(u8, lower, "black")) return .black;
        if (std.mem.eql(u8, lower, "white")) return .white;
        if (std.mem.eql(u8, lower, "green")) return .green;
        if (std.mem.eql(u8, lower, "blue")) return .blue;
        if (std.mem.eql(u8, lower, "pink")) return .pink;
        if (std.mem.eql(u8, lower, "purple")) return .purple;
        if (std.mem.eql(u8, lower, "tan")) return .tan;
        if (std.mem.eql(u8, lower, "buff")) return .buff;
        if (std.mem.eql(u8, lower, "dark gray")) return .dark_gray;
        if (std.mem.eql(u8, lower, "dark grey")) return .dark_gray;
        if (std.mem.eql(u8, lower, "light gray")) return .light_gray;
        if (std.mem.eql(u8, lower, "light grey")) return .light_gray;
        if (std.mem.eql(u8, lower, "dark brown")) return .dark_brown;
        if (std.mem.eql(u8, lower, "light brown")) return .light_brown;
        if (std.mem.eql(u8, lower, "reddish brown")) return .reddish_brown;
        if (std.mem.eql(u8, lower, "yellowish brown")) return .yellowish_brown;

        return null;
    }

    pub fn toString(self: Color) []const u8 {
        return switch (self) {
            .gray => "gray",
            .grey => "grey",
            .brown => "brown",
            .red => "red",
            .yellow => "yellow",
            .orange => "orange",
            .black => "black",
            .white => "white",
            .green => "green",
            .blue => "blue",
            .pink => "pink",
            .purple => "purple",
            .tan => "tan",
            .buff => "buff",
            .dark_gray => "dark gray",
            .light_gray => "light gray",
            .dark_brown => "dark brown",
            .light_brown => "light brown",
            .reddish_brown => "reddish brown",
            .yellowish_brown => "yellowish brown",
        };
    }
};

pub const MoistureContent = enum {
    dry,
    moist,
    wet,
    saturated,

    pub fn fromString(str: []const u8) ?MoistureContent {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "dry")) return .dry;
        if (std.mem.eql(u8, lower, "moist")) return .moist;
        if (std.mem.eql(u8, lower, "wet")) return .wet;
        if (std.mem.eql(u8, lower, "saturated")) return .saturated;

        return null;
    }

    pub fn toString(self: MoistureContent) []const u8 {
        return switch (self) {
            .dry => "dry",
            .moist => "moist",
            .wet => "wet",
            .saturated => "saturated",
        };
    }
};

pub const PlasticityIndex = enum {
    non_plastic,
    low_plasticity,
    intermediate_plasticity,
    high_plasticity,
    extremely_high_plasticity,

    pub fn fromString(str: []const u8) ?PlasticityIndex {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "non plastic")) return .non_plastic;
        if (std.mem.eql(u8, lower, "non-plastic")) return .non_plastic;
        if (std.mem.eql(u8, lower, "low plasticity")) return .low_plasticity;
        if (std.mem.eql(u8, lower, "intermediate plasticity")) return .intermediate_plasticity;
        if (std.mem.eql(u8, lower, "high plasticity")) return .high_plasticity;
        if (std.mem.eql(u8, lower, "extremely high plasticity")) return .extremely_high_plasticity;

        return null;
    }

    pub fn toString(self: PlasticityIndex) []const u8 {
        return switch (self) {
            .non_plastic => "non plastic",
            .low_plasticity => "low plasticity",
            .intermediate_plasticity => "intermediate plasticity",
            .high_plasticity => "high plasticity",
            .extremely_high_plasticity => "extremely high plasticity",
        };
    }
};

pub const ParticleSize = enum {
    fine,
    medium,
    coarse,
    fine_to_medium,
    medium_to_coarse,
    fine_to_coarse,

    pub fn fromString(str: []const u8) ?ParticleSize {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "fine")) return .fine;
        if (std.mem.eql(u8, lower, "medium")) return .medium;
        if (std.mem.eql(u8, lower, "coarse")) return .coarse;
        if (std.mem.eql(u8, lower, "fine to medium")) return .fine_to_medium;
        if (std.mem.eql(u8, lower, "medium to coarse")) return .medium_to_coarse;
        if (std.mem.eql(u8, lower, "fine to coarse")) return .fine_to_coarse;

        return null;
    }

    pub fn toString(self: ParticleSize) []const u8 {
        return switch (self) {
            .fine => "fine",
            .medium => "medium",
            .coarse => "coarse",
            .fine_to_medium => "fine to medium",
            .medium_to_coarse => "medium to coarse",
            .fine_to_coarse => "fine to coarse",
        };
    }
};

pub const SoilType = enum {
    clay,
    silt,
    sand,
    gravel,
    peat,
    organic,

    pub fn fromString(str: []const u8) ?SoilType {
        var lower_buf: [64]u8 = undefined;
        if (str.len >= lower_buf.len) return null;

        const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

        if (std.mem.eql(u8, lower, "clay")) return .clay;
        if (std.mem.eql(u8, lower, "silt")) return .silt;
        if (std.mem.eql(u8, lower, "sand")) return .sand;
        if (std.mem.eql(u8, lower, "gravel")) return .gravel;
        if (std.mem.eql(u8, lower, "peat")) return .peat;
        if (std.mem.eql(u8, lower, "organic")) return .organic;

        return null;
    }

    pub fn toString(self: SoilType) []const u8 {
        return switch (self) {
            .clay => "CLAY",
            .silt => "SILT",
            .sand => "SAND",
            .gravel => "GRAVEL",
            .peat => "PEAT",
            .organic => "ORGANIC",
        };
    }

    pub fn isCohesive(self: SoilType) bool {
        return self == .clay or self == .silt;
    }

    pub fn isGranular(self: SoilType) bool {
        return self == .sand or self == .gravel;
    }
};

pub const SecondaryConstituent = struct {
    amount: []const u8,
    soil_type: []const u8,

    // Keep the old Proportion enum for backward compatibility in parsing
    pub const Proportion = enum {
        slightly,
        moderately,
        very,

        pub fn fromString(str: []const u8) ?Proportion {
            var lower_buf: [64]u8 = undefined;
            if (str.len >= lower_buf.len) return null;

            const lower = std.ascii.lowerString(lower_buf[0..str.len], str);

            if (std.mem.eql(u8, lower, "slightly")) return .slightly;
            if (std.mem.eql(u8, lower, "moderately")) return .moderately;
            if (std.mem.eql(u8, lower, "very")) return .very;

            return null;
        }

        pub fn toString(self: Proportion) []const u8 {
            return switch (self) {
                .slightly => "slightly",
                .moderately => "moderately",
                .very => "very",
            };
        }
    };

    pub fn toString(self: SecondaryConstituent, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s} {s}", .{ self.amount, self.soil_type });
    }
};

pub const SoilDescription = struct {
    raw_description: []const u8,
    material_type: MaterialType,
    // Soil properties
    consistency: ?Consistency = null,
    density: ?Density = null,
    secondary_constituents: []SecondaryConstituent = &[_]SecondaryConstituent{},
    primary_soil_type: ?SoilType = null,
    // Rock properties
    rock_strength: ?RockStrength = null,
    weathering_grade: ?WeatheringGrade = null,
    rock_structure: ?RockStructure = null,
    primary_rock_type: ?RockType = null,
    // Enhanced geological features
    color: ?Color = null,
    moisture_content: ?MoistureContent = null,
    plasticity_index: ?PlasticityIndex = null,
    particle_size: ?ParticleSize = null,
    // Strength parameters
    strength_parameters: ?StrengthParameters = null,
    // Constituent guidance
    constituent_guidance: ?ConstituentGuidance = null,
    // Common properties
    structure: ?[]const u8 = null,
    confidence: f32 = 1.0,
    warnings: [][]const u8 = &[_][]const u8{},
    is_valid: bool = true,

    pub fn deinit(self: SoilDescription, allocator: std.mem.Allocator) void {
        allocator.free(self.raw_description);
        allocator.free(self.secondary_constituents);

        // Free warning strings
        for (self.warnings) |warning| {
            allocator.free(warning);
        }
        allocator.free(self.warnings);

        // Free constituent guidance if present
        if (self.constituent_guidance) |guidance| {
            guidance.deinit(allocator);
        }
    }

    pub fn toJson(self: SoilDescription, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        var writer = result.writer();

        try writer.writeAll("{");

        try writer.print("\"raw_description\":\"{s}\"", .{self.raw_description});
        try writer.print(",\"material_type\":\"{s}\"", .{self.material_type.toString()});

        if (self.consistency) |c| {
            try writer.print(",\"consistency\":\"{s}\"", .{c.toString()});
        }

        if (self.density) |d| {
            try writer.print(",\"density\":\"{s}\"", .{d.toString()});
        }

        if (self.primary_soil_type) |pst| {
            try writer.print(",\"primary_soil_type\":\"{s}\"", .{pst.toString()});
        }

        if (self.rock_strength) |rs| {
            try writer.print(",\"rock_strength\":\"{s}\"", .{rs.toString()});
        }

        if (self.weathering_grade) |wg| {
            try writer.print(",\"weathering_grade\":\"{s}\"", .{wg.toString()});
        }

        if (self.rock_structure) |rs| {
            try writer.print(",\"rock_structure\":\"{s}\"", .{rs.toString()});
        }

        if (self.primary_rock_type) |prt| {
            try writer.print(",\"primary_rock_type\":\"{s}\"", .{prt.toString()});
        }

        // Add enhanced geological features to JSON
        if (self.color) |color| {
            try writer.print(",\"color\":\"{s}\"", .{color.toString()});
        }

        if (self.moisture_content) |moisture| {
            try writer.print(",\"moisture_content\":\"{s}\"", .{moisture.toString()});
        }

        if (self.plasticity_index) |plasticity| {
            try writer.print(",\"plasticity_index\":\"{s}\"", .{plasticity.toString()});
        }

        if (self.particle_size) |particle_size| {
            try writer.print(",\"particle_size\":\"{s}\"", .{particle_size.toString()});
        }

        // Add strength parameters to JSON
        if (self.strength_parameters) |sp| {
            try writer.print(",\"strength_parameter_type\":\"{s}\"", .{sp.parameter_type.toString()});
            try writer.print(",\"strength_parameter_units\":\"{s}\"", .{sp.parameter_type.getUnits()});
            try writer.print(",\"strength_lower_bound\":{d:.2}", .{sp.range.lower_bound});
            try writer.print(",\"strength_upper_bound\":{d:.2}", .{sp.range.upper_bound});
            if (sp.range.typical_value) |tv| {
                try writer.print(",\"strength_typical_value\":{d:.2}", .{tv});
            } else {
                try writer.print(",\"strength_typical_value\":{d:.2}", .{sp.range.getMidpoint()});
            }
            try writer.print(",\"strength_confidence\":{d:.2}", .{sp.confidence});
        }

        // Add constituent guidance to JSON
        if (self.constituent_guidance) |cg| {
            try writer.writeAll(",\"constituent_proportions\":[");
            for (cg.constituents, 0..) |constituent, i| {
                if (i > 0) try writer.writeAll(",");
                const typical = if (constituent.range.typical_value) |tv| tv else constituent.range.getMidpoint();
                try writer.print("{{\"soil_type\":\"{s}\",\"percentage_range\":\"{d:.0}-{d:.0}\",\"typical_percentage\":{d:.0}}}", .{
                    constituent.soil_type,
                    constituent.range.lower_bound,
                    constituent.range.upper_bound,
                    typical,
                });
            }
            try writer.writeAll("]");
            try writer.print(",\"constituent_confidence\":{d:.2}", .{cg.confidence});
        }

        try writer.writeAll(",\"secondary_constituents\":[");
        for (self.secondary_constituents, 0..) |sc, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{{\"amount\":\"{s}\",\"soil_type\":\"{s}\"}}", .{ sc.amount, sc.soil_type });
        }
        try writer.writeAll("]");

        try writer.writeAll(",\"warnings\":[");
        for (self.warnings, 0..) |warning, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("\"{s}\"", .{warning});
        }
        try writer.writeAll("]");

        try writer.print(",\"confidence\":{d:.2}", .{self.confidence});

        try writer.print(",\"is_valid\":{s}", .{if (self.is_valid) "true" else "false"});

        try writer.writeAll("}");

        return result.toOwnedSlice();
    }

    pub fn toPrettyJson(self: SoilDescription, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        var writer = result.writer();

        try writer.writeAll("{\n");

        try writer.print("  \"raw_description\": \"{s}\",\n", .{self.raw_description});
        try writer.print("  \"material_type\": \"{s}\"", .{self.material_type.toString()});

        if (self.consistency) |c| {
            try writer.print(",\n  \"consistency\": \"{s}\"", .{c.toString()});
        }

        if (self.density) |d| {
            try writer.print(",\n  \"density\": \"{s}\"", .{d.toString()});
        }

        if (self.primary_soil_type) |pst| {
            try writer.print(",\n  \"primary_soil_type\": \"{s}\"", .{pst.toString()});
        }

        if (self.rock_strength) |rs| {
            try writer.print(",\n  \"rock_strength\": \"{s}\"", .{rs.toString()});
        }

        if (self.weathering_grade) |wg| {
            try writer.print(",\n  \"weathering_grade\": \"{s}\"", .{wg.toString()});
        }

        if (self.rock_structure) |rs| {
            try writer.print(",\n  \"rock_structure\": \"{s}\"", .{rs.toString()});
        }

        if (self.primary_rock_type) |prt| {
            try writer.print(",\n  \"primary_rock_type\": \"{s}\"", .{prt.toString()});
        }

        // Add enhanced geological features to JSON
        if (self.color) |color| {
            try writer.print(",\n  \"color\": \"{s}\"", .{color.toString()});
        }

        if (self.moisture_content) |moisture| {
            try writer.print(",\n  \"moisture_content\": \"{s}\"", .{moisture.toString()});
        }

        if (self.plasticity_index) |plasticity| {
            try writer.print(",\n  \"plasticity_index\": \"{s}\"", .{plasticity.toString()});
        }

        if (self.particle_size) |particle_size| {
            try writer.print(",\n  \"particle_size\": \"{s}\"", .{particle_size.toString()});
        }

        // Add strength parameters to JSON
        if (self.strength_parameters) |sp| {
            try writer.print(",\n  \"strength_parameter_type\": \"{s}\"", .{sp.parameter_type.toString()});
            try writer.print(",\n  \"strength_parameter_units\": \"{s}\"", .{sp.parameter_type.getUnits()});
            try writer.print(",\n  \"strength_lower_bound\": {d:.2}", .{sp.range.lower_bound});
            try writer.print(",\n  \"strength_upper_bound\": {d:.2}", .{sp.range.upper_bound});
            if (sp.range.typical_value) |tv| {
                try writer.print(",\n  \"strength_typical_value\": {d:.2}", .{tv});
            } else {
                try writer.print(",\n  \"strength_typical_value\": {d:.2}", .{sp.range.getMidpoint()});
            }
            try writer.print(",\n  \"strength_confidence\": {d:.2}", .{sp.confidence});
        }

        // Add constituent guidance to JSON
        if (self.constituent_guidance) |cg| {
            try writer.writeAll(",\n  \"constituent_proportions\": [\n");
            for (cg.constituents, 0..) |constituent, i| {
                if (i > 0) try writer.writeAll(",\n");
                const typical = if (constituent.range.typical_value) |tv| tv else constituent.range.getMidpoint();
                try writer.print("    {{\n      \"soil_type\": \"{s}\",\n      \"percentage_range\": \"{d:.0}-{d:.0}\",\n      \"typical_percentage\": {d:.0}\n    }}", .{
                    constituent.soil_type,
                    constituent.range.lower_bound,
                    constituent.range.upper_bound,
                    typical,
                });
            }
            try writer.writeAll("\n  ]");
            try writer.print(",\n  \"constituent_confidence\": {d:.2}", .{cg.confidence});
        }

        try writer.writeAll(",\n  \"secondary_constituents\": [\n");
        for (self.secondary_constituents, 0..) |sc, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.print("    {{\n      \"amount\": \"{s}\",\n      \"soil_type\": \"{s}\"\n    }}", .{ sc.amount, sc.soil_type });
        }
        try writer.writeAll("\n  ]");

        try writer.writeAll(",\n  \"warnings\": [\n");
        for (self.warnings, 0..) |warning, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.print("    \"{s}\"", .{warning});
        }
        try writer.writeAll("\n  ]");

        try writer.print(",\n  \"confidence\": {d:.2}", .{self.confidence});

        try writer.print(",\n  \"is_valid\": {s}", .{if (self.is_valid) "true" else "false"});

        try writer.writeAll("\n}");

        return result.toOwnedSlice();
    }

    pub fn toColorizedJson(self: SoilDescription, allocator: std.mem.Allocator, use_colors: bool) ![]u8 {
        if (!use_colors) {
            return self.toPrettyJson(allocator);
        }

        var result = std.ArrayList(u8).init(allocator);
        var writer = result.writer();

        // ANSI color codes (jq-style)
        const bracket_color = "\x1b[90m"; // dim white for brackets
        const key_color = "\x1b[34m"; // blue for keys
        const string_color = "\x1b[32m"; // green for strings
        const number_color = "\x1b[33m"; // yellow for numbers
        const bool_color = "\x1b[35m"; // magenta for booleans
        const reset_color = "\x1b[0m"; // reset

        try writer.print("{s}{{{s}\n", .{ bracket_color, reset_color });

        try writer.print("  {s}\"{s}raw_description{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, self.raw_description, string_color, reset_color });
        try writer.print(",\n  {s}\"{s}material_type{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, self.material_type.toString(), string_color, reset_color });

        if (self.consistency) |c| {
            try writer.print(",\n  {s}\"{s}consistency{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, c.toString(), string_color, reset_color });
        }

        if (self.density) |d| {
            try writer.print(",\n  {s}\"{s}density{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, d.toString(), string_color, reset_color });
        }

        if (self.primary_soil_type) |pst| {
            try writer.print(",\n  {s}\"{s}primary_soil_type{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, pst.toString(), string_color, reset_color });
        }

        if (self.rock_strength) |rs| {
            try writer.print(",\n  {s}\"{s}rock_strength{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, rs.toString(), string_color, reset_color });
        }

        if (self.weathering_grade) |wg| {
            try writer.print(",\n  {s}\"{s}weathering_grade{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, wg.toString(), string_color, reset_color });
        }

        if (self.rock_structure) |rs| {
            try writer.print(",\n  {s}\"{s}rock_structure{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, rs.toString(), string_color, reset_color });
        }

        if (self.primary_rock_type) |prt| {
            try writer.print(",\n  {s}\"{s}primary_rock_type{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, prt.toString(), string_color, reset_color });
        }

        // Add enhanced geological features to JSON
        if (self.color) |color| {
            try writer.print(",\n  {s}\"{s}color{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, color.toString(), string_color, reset_color });
        }

        if (self.moisture_content) |moisture| {
            try writer.print(",\n  {s}\"{s}moisture_content{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, moisture.toString(), string_color, reset_color });
        }

        if (self.plasticity_index) |plasticity| {
            try writer.print(",\n  {s}\"{s}plasticity_index{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, plasticity.toString(), string_color, reset_color });
        }

        if (self.particle_size) |particle_size| {
            try writer.print(",\n  {s}\"{s}particle_size{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, particle_size.toString(), string_color, reset_color });
        }

        // Add strength parameters to JSON
        if (self.strength_parameters) |sp| {
            try writer.print(",\n  {s}\"{s}strength_parameter_type{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, sp.parameter_type.toString(), string_color, reset_color });
            try writer.print(",\n  {s}\"{s}strength_parameter_units{s}\"{s}: {s}\"{s}{s}{s}\"{s}", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, sp.parameter_type.getUnits(), string_color, reset_color });
            try writer.print(",\n  {s}\"{s}strength_lower_bound{s}\"{s}: {s}{d:.2}{s}", .{ key_color, reset_color, key_color, reset_color, number_color, sp.range.lower_bound, reset_color });
            try writer.print(",\n  {s}\"{s}strength_upper_bound{s}\"{s}: {s}{d:.2}{s}", .{ key_color, reset_color, key_color, reset_color, number_color, sp.range.upper_bound, reset_color });
            if (sp.range.typical_value) |tv| {
                try writer.print(",\n  {s}\"{s}strength_typical_value{s}\"{s}: {s}{d:.2}{s}", .{ key_color, reset_color, key_color, reset_color, number_color, tv, reset_color });
            } else {
                try writer.print(",\n  {s}\"{s}strength_typical_value{s}\"{s}: {s}{d:.2}{s}", .{ key_color, reset_color, key_color, reset_color, number_color, sp.range.getMidpoint(), reset_color });
            }
            try writer.print(",\n  {s}\"{s}strength_confidence{s}\"{s}: {s}{d:.2}{s}", .{ key_color, reset_color, key_color, reset_color, number_color, sp.confidence, reset_color });
        }

        // Add constituent guidance to JSON
        if (self.constituent_guidance) |cg| {
            try writer.print(",\n  {s}\"{s}constituent_proportions{s}\"{s}: {s}[{s}\n", .{ key_color, reset_color, key_color, reset_color, bracket_color, reset_color });
            for (cg.constituents, 0..) |constituent, i| {
                if (i > 0) try writer.writeAll(",\n");
                const typical = if (constituent.range.typical_value) |tv| tv else constituent.range.getMidpoint();
                try writer.print("    {s}{{{s}\n", .{ bracket_color, reset_color });
                try writer.print("      {s}\"{s}soil_type{s}\"{s}: {s}\"{s}{s}{s}\"{s},\n", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, constituent.soil_type, string_color, reset_color });
                try writer.print("      {s}\"{s}percentage_range{s}\"{s}: {s}\"{s}{d:.0}-{d:.0}{s}\"{s},\n", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, constituent.range.lower_bound, constituent.range.upper_bound, string_color, reset_color });
                try writer.print("      {s}\"{s}typical_percentage{s}\"{s}: {s}{d:.0}{s}\n", .{ key_color, reset_color, key_color, reset_color, number_color, typical, reset_color });
                try writer.print("    {s}}}{s}", .{ bracket_color, reset_color });
            }
            try writer.print("\n  {s}]{s}", .{ bracket_color, reset_color });
            try writer.print(",\n  {s}\"{s}constituent_confidence{s}\"{s}: {s}{d:.2}{s}", .{ key_color, reset_color, key_color, reset_color, number_color, cg.confidence, reset_color });
        }

        try writer.print(",\n  {s}\"{s}secondary_constituents{s}\"{s}: {s}[{s}\n", .{ key_color, reset_color, key_color, reset_color, bracket_color, reset_color });
        for (self.secondary_constituents, 0..) |sc, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.print("    {s}{{{s}\n", .{ bracket_color, reset_color });
            try writer.print("      {s}\"{s}amount{s}\"{s}: {s}\"{s}{s}{s}\"{s},\n", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, sc.amount, string_color, reset_color });
            try writer.print("      {s}\"{s}soil_type{s}\"{s}: {s}\"{s}{s}{s}\"{s}\n", .{ key_color, reset_color, key_color, reset_color, string_color, reset_color, sc.soil_type, string_color, reset_color });
            try writer.print("    {s}}}{s}", .{ bracket_color, reset_color });
        }
        try writer.print("\n  {s}]{s}", .{ bracket_color, reset_color });

        try writer.print(",\n  {s}\"{s}warnings{s}\"{s}: {s}[{s}\n", .{ key_color, reset_color, key_color, reset_color, bracket_color, reset_color });
        for (self.warnings, 0..) |warning, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.print("    {s}\"{s}{s}{s}\"{s}", .{ string_color, reset_color, warning, string_color, reset_color });
        }
        try writer.print("\n  {s}]{s}", .{ bracket_color, reset_color });

        try writer.print(",\n  {s}\"{s}confidence{s}\"{s}: {s}{d:.2}{s}", .{ key_color, reset_color, key_color, reset_color, number_color, self.confidence, reset_color });

        try writer.print(",\n  {s}\"{s}is_valid{s}\"{s}: {s}{s}{s}", .{ key_color, reset_color, key_color, reset_color, bool_color, if (self.is_valid) "true" else "false", reset_color });

        try writer.print("\n{s}}}{s}", .{ bracket_color, reset_color });

        return result.toOwnedSlice();
    }
};
