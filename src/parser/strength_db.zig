const std = @import("std");
const types = @import("types.zig");

const Consistency = types.Consistency;
const Density = types.Density;
const RockStrength = types.RockStrength;
const SoilType = types.SoilType;

pub const StrengthParameterType = enum {
    undrained_shear_strength, // cu for cohesive soils (kPa)
    spt_n_value, // SPT N for granular soils (blows/300mm)
    ucs, // Unconfined compressive strength for rock (MPa)

    pub fn toString(self: StrengthParameterType) []const u8 {
        return switch (self) {
            .undrained_shear_strength => "cu",
            .spt_n_value => "SPT-N",
            .ucs => "UCS",
        };
    }

    pub fn getUnits(self: StrengthParameterType) []const u8 {
        return switch (self) {
            .undrained_shear_strength => "kPa",
            .spt_n_value => "blows/300mm",
            .ucs => "MPa",
        };
    }
};

pub const StrengthRange = struct {
    lower_bound: f32,
    upper_bound: f32,
    typical_value: ?f32 = null,

    pub fn contains(self: StrengthRange, value: f32) bool {
        return value >= self.lower_bound and value <= self.upper_bound;
    }

    pub fn getMidpoint(self: StrengthRange) f32 {
        return (self.lower_bound + self.upper_bound) / 2.0;
    }
};

pub const StrengthParameters = struct {
    parameter_type: StrengthParameterType,
    range: StrengthRange,
    confidence: f32 = 0.8, // Default confidence level

    pub fn toString(self: StrengthParameters, allocator: std.mem.Allocator) ![]u8 {
        const typical = if (self.range.typical_value) |tv| tv else self.range.getMidpoint();
        return std.fmt.allocPrint(allocator, "{s}: {d:.1}-{d:.1} {s} (typical: {d:.1})", .{
            self.parameter_type.toString(),
            self.range.lower_bound,
            self.range.upper_bound,
            self.parameter_type.getUnits(),
            typical,
        });
    }
};

// Database for cohesive soil strength parameters (cu in kPa) based on consistency
const COHESIVE_STRENGTH_DB = std.EnumMap(Consistency, StrengthRange).init(.{
    .very_soft = StrengthRange{ .lower_bound = 0, .upper_bound = 12, .typical_value = 6 },
    .soft = StrengthRange{ .lower_bound = 12, .upper_bound = 25, .typical_value = 18 },
    .firm = StrengthRange{ .lower_bound = 25, .upper_bound = 50, .typical_value = 37 },
    .stiff = StrengthRange{ .lower_bound = 50, .upper_bound = 100, .typical_value = 75 },
    .very_stiff = StrengthRange{ .lower_bound = 100, .upper_bound = 200, .typical_value = 150 },
    .hard = StrengthRange{ .lower_bound = 200, .upper_bound = 400, .typical_value = 300 },
    // Ranges - use the wider range covering both end points
    .soft_to_firm = StrengthRange{ .lower_bound = 12, .upper_bound = 50, .typical_value = 31 },
    .firm_to_stiff = StrengthRange{ .lower_bound = 25, .upper_bound = 100, .typical_value = 62 },
    .stiff_to_very_stiff = StrengthRange{ .lower_bound = 50, .upper_bound = 200, .typical_value = 125 },
});

// Database for granular soil strength parameters (SPT N-value) based on density
const GRANULAR_STRENGTH_DB = std.EnumMap(Density, StrengthRange).init(.{
    .very_loose = StrengthRange{ .lower_bound = 0, .upper_bound = 4, .typical_value = 2 },
    .loose = StrengthRange{ .lower_bound = 4, .upper_bound = 10, .typical_value = 7 },
    .medium_dense = StrengthRange{ .lower_bound = 10, .upper_bound = 30, .typical_value = 20 },
    .dense = StrengthRange{ .lower_bound = 30, .upper_bound = 50, .typical_value = 40 },
    .very_dense = StrengthRange{ .lower_bound = 50, .upper_bound = 100, .typical_value = 75 },
});

// Database for rock strength parameters (UCS in MPa) based on rock strength
const ROCK_STRENGTH_DB = std.EnumMap(RockStrength, StrengthRange).init(.{
    .very_weak = StrengthRange{ .lower_bound = 0.25, .upper_bound = 1.0, .typical_value = 0.6 },
    .weak = StrengthRange{ .lower_bound = 1.0, .upper_bound = 5.0, .typical_value = 2.5 },
    .moderately_weak = StrengthRange{ .lower_bound = 5.0, .upper_bound = 12.5, .typical_value = 8.0 },
    .moderately_strong = StrengthRange{ .lower_bound = 12.5, .upper_bound = 50.0, .typical_value = 25.0 },
    .strong = StrengthRange{ .lower_bound = 50.0, .upper_bound = 100.0, .typical_value = 75.0 },
    .very_strong = StrengthRange{ .lower_bound = 100.0, .upper_bound = 200.0, .typical_value = 150.0 },
    .extremely_strong = StrengthRange{ .lower_bound = 200.0, .upper_bound = 500.0, .typical_value = 300.0 },
});

pub const StrengthDatabase = struct {
    pub fn getStrengthParameters(
        material_type: types.MaterialType,
        consistency: ?Consistency,
        density: ?Density,
        rock_strength: ?RockStrength,
        primary_soil_type: ?SoilType,
    ) ?StrengthParameters {
        switch (material_type) {
            .soil => {
                // For cohesive soils, use undrained shear strength
                if (primary_soil_type) |soil_type| {
                    if (soil_type.isCohesive()) {
                        if (consistency) |c| {
                            if (COHESIVE_STRENGTH_DB.get(c)) |range| {
                                return StrengthParameters{
                                    .parameter_type = .undrained_shear_strength,
                                    .range = range,
                                    .confidence = 0.8,
                                };
                            }
                        }
                    }
                    // For granular soils, use SPT N-value
                    else if (soil_type.isGranular()) {
                        if (density) |d| {
                            if (GRANULAR_STRENGTH_DB.get(d)) |range| {
                                return StrengthParameters{
                                    .parameter_type = .spt_n_value,
                                    .range = range,
                                    .confidence = 0.75, // Slightly lower confidence for SPT correlations
                                };
                            }
                        }
                    }
                }
            },
            .rock => {
                // For rock, use unconfined compressive strength
                if (rock_strength) |rs| {
                    if (ROCK_STRENGTH_DB.get(rs)) |range| {
                        return StrengthParameters{
                            .parameter_type = .ucs,
                            .range = range,
                            .confidence = 0.7, // Lower confidence for rock strength correlations
                        };
                    }
                }
            },
        }
        return null;
    }

    pub fn estimateParameterFromValue(parameter_type: StrengthParameterType, value: f32) ?[]const u8 {
        switch (parameter_type) {
            .undrained_shear_strength => {
                if (value < 12) return "very soft";
                if (value < 25) return "soft";
                if (value < 50) return "firm";
                if (value < 100) return "stiff";
                if (value < 200) return "very stiff";
                return "hard";
            },
            .spt_n_value => {
                if (value < 4) return "very loose";
                if (value < 10) return "loose";
                if (value < 30) return "medium dense";
                if (value < 50) return "dense";
                return "very dense";
            },
            .ucs => {
                if (value < 1.0) return "very weak";
                if (value < 5.0) return "weak";
                if (value < 12.5) return "moderately weak";
                if (value < 50.0) return "moderately strong";
                if (value < 100.0) return "strong";
                if (value < 200.0) return "very strong";
                return "extremely strong";
            },
        }
    }
};

// Tests
test "cohesive strength parameters" {
    const params = StrengthDatabase.getStrengthParameters(
        .soil,
        .firm,
        null,
        null,
        .clay,
    );

    try std.testing.expect(params != null);
    try std.testing.expect(params.?.parameter_type == .undrained_shear_strength);
    try std.testing.expect(params.?.range.lower_bound == 25);
    try std.testing.expect(params.?.range.upper_bound == 50);
    try std.testing.expect(params.?.range.typical_value.? == 37);
}

test "granular strength parameters" {
    const params = StrengthDatabase.getStrengthParameters(
        .soil,
        null,
        .dense,
        null,
        .sand,
    );

    try std.testing.expect(params != null);
    try std.testing.expect(params.?.parameter_type == .spt_n_value);
    try std.testing.expect(params.?.range.lower_bound == 30);
    try std.testing.expect(params.?.range.upper_bound == 50);
}

test "rock strength parameters" {
    const params = StrengthDatabase.getStrengthParameters(
        .rock,
        null,
        null,
        .strong,
        null,
    );

    try std.testing.expect(params != null);
    try std.testing.expect(params.?.parameter_type == .ucs);
    try std.testing.expect(params.?.range.lower_bound == 50.0);
    try std.testing.expect(params.?.range.upper_bound == 100.0);
}

test "parameter estimation from value" {
    const cu_desc = StrengthDatabase.estimateParameterFromValue(.undrained_shear_strength, 75);
    try std.testing.expect(std.mem.eql(u8, cu_desc.?, "stiff"));

    const spt_desc = StrengthDatabase.estimateParameterFromValue(.spt_n_value, 25);
    try std.testing.expect(std.mem.eql(u8, spt_desc.?, "medium dense"));

    const ucs_desc = StrengthDatabase.estimateParameterFromValue(.ucs, 75);
    try std.testing.expect(std.mem.eql(u8, ucs_desc.?, "strong"));
}
