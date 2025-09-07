const std = @import("std");

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

// Forward declaration for strength database
pub const StrengthParameters = @import("strength_db.zig").StrengthParameters;

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
    // Strength parameters
    strength_parameters: ?StrengthParameters = null,
    // Common properties
    color: ?[]const u8 = null,
    structure: ?[]const u8 = null,
    confidence: f32 = 1.0,
    warnings: [][]const u8 = &[_][]const u8{},

    pub fn deinit(self: SoilDescription, allocator: std.mem.Allocator) void {
        allocator.free(self.raw_description);
        allocator.free(self.secondary_constituents);
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

        try writer.writeAll(",\"secondary_constituents\":[");
        for (self.secondary_constituents, 0..) |sc, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{{\"amount\":\"{s}\",\"soil_type\":\"{s}\"}}", .{ sc.amount, sc.soil_type });
        }
        try writer.writeAll("]");

        try writer.print(",\"confidence\":{d:.2}", .{self.confidence});

        try writer.writeAll("}");

        return result.toOwnedSlice();
    }
};
