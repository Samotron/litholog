const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

const StrengthDatabase = parser.StrengthDatabase;
const StrengthParameterType = parser.StrengthParameterType;
const Consistency = parser.Consistency;
const Density = parser.Density;
const RockStrength = parser.RockStrength;
const MaterialType = parser.MaterialType;
const SoilType = parser.SoilType;

test "strength_db: cohesive soil strength parameters" {
    const params = StrengthDatabase.getStrengthParameters(.soil, .firm, null, null, .clay);
    try testing.expect(params != null);

    const p = params.?;
    try testing.expectEqual(StrengthParameterType.undrained_shear_strength, p.parameter_type);
    try testing.expect(p.range.lower_bound >= 20);
    try testing.expect(p.range.upper_bound <= 60);
}

test "strength_db: granular soil strength parameters" {
    const params = StrengthDatabase.getStrengthParameters(.soil, null, .dense, null, .sand);
    try testing.expect(params != null);

    const p = params.?;
    try testing.expectEqual(StrengthParameterType.spt_n_value, p.parameter_type);
    try testing.expect(p.range.lower_bound >= 25);
    try testing.expect(p.range.upper_bound <= 55);
}

test "strength_db: rock strength parameters" {
    const params = StrengthDatabase.getStrengthParameters(.rock, null, null, .strong, null);
    try testing.expect(params != null);

    const p = params.?;
    try testing.expectEqual(StrengthParameterType.ucs, p.parameter_type);
    try testing.expect(p.range.lower_bound >= 40);
    try testing.expect(p.range.upper_bound <= 120);
}

test "strength_db: all consistency levels have parameters" {
    const consistencies = [_]Consistency{
        .very_soft,    .soft,          .firm,                .stiff, .very_stiff, .hard,
        .soft_to_firm, .firm_to_stiff, .stiff_to_very_stiff,
    };

    for (consistencies) |consistency| {
        const params = StrengthDatabase.getStrengthParameters(.soil, consistency, null, null, .clay);
        try testing.expect(params != null);
        try testing.expectEqual(StrengthParameterType.undrained_shear_strength, params.?.parameter_type);
    }
}

test "strength_db: all density levels have parameters" {
    const densities = [_]Density{
        .very_loose, .loose, .medium_dense, .dense, .very_dense,
    };

    for (densities) |density| {
        const params = StrengthDatabase.getStrengthParameters(.soil, null, density, null, .sand);
        try testing.expect(params != null);
        try testing.expectEqual(StrengthParameterType.spt_n_value, params.?.parameter_type);
    }
}

test "strength_db: all rock strength levels have parameters" {
    const strengths = [_]RockStrength{
        .very_weak, .weak,        .moderately_weak,  .moderately_strong,
        .strong,    .very_strong, .extremely_strong,
    };

    for (strengths) |strength| {
        const params = StrengthDatabase.getStrengthParameters(.rock, null, null, strength, null);
        try testing.expect(params != null);
        try testing.expectEqual(StrengthParameterType.ucs, params.?.parameter_type);
    }
}

test "strength_db: strength increases with consistency" {
    const firm = StrengthDatabase.getStrengthParameters(.soil, .firm, null, null, .clay);
    const stiff = StrengthDatabase.getStrengthParameters(.soil, .stiff, null, null, .clay);

    try testing.expect(firm != null);
    try testing.expect(stiff != null);
    try testing.expect(stiff.?.range.lower_bound > firm.?.range.lower_bound);
    try testing.expect(stiff.?.range.upper_bound > firm.?.range.upper_bound);
}

test "strength_db: strength increases with density" {
    const loose = StrengthDatabase.getStrengthParameters(.soil, null, .loose, null, .sand);
    const dense = StrengthDatabase.getStrengthParameters(.soil, null, .dense, null, .sand);

    try testing.expect(loose != null);
    try testing.expect(dense != null);
    try testing.expect(dense.?.range.lower_bound > loose.?.range.lower_bound);
    try testing.expect(dense.?.range.upper_bound > loose.?.range.upper_bound);
}

test "strength_db: strength increases with rock strength" {
    const weak = StrengthDatabase.getStrengthParameters(.rock, null, null, .weak, null);
    const strong = StrengthDatabase.getStrengthParameters(.rock, null, null, .strong, null);

    try testing.expect(weak != null);
    try testing.expect(strong != null);
    try testing.expect(strong.?.range.lower_bound > weak.?.range.lower_bound);
    try testing.expect(strong.?.range.upper_bound > weak.?.range.upper_bound);
}

test "strength_db: range midpoint calculation" {
    const params = StrengthDatabase.getStrengthParameters(.soil, .firm, null, null, .clay);
    try testing.expect(params != null);

    const midpoint = params.?.range.getMidpoint();
    try testing.expect(midpoint > params.?.range.lower_bound);
    try testing.expect(midpoint < params.?.range.upper_bound);
    try testing.expect(midpoint == (params.?.range.lower_bound + params.?.range.upper_bound) / 2.0);
}

test "strength_db: range contains check" {
    const params = StrengthDatabase.getStrengthParameters(.soil, .firm, null, null, .clay);
    try testing.expect(params != null);

    const range = params.?.range;
    try testing.expect(range.contains(range.lower_bound));
    try testing.expect(range.contains(range.upper_bound));
    try testing.expect(range.contains(range.getMidpoint()));
    try testing.expect(!range.contains(range.lower_bound - 1));
    try testing.expect(!range.contains(range.upper_bound + 1));
}

test "strength_db: parameter type toString" {
    try testing.expectEqualStrings("cu", StrengthParameterType.undrained_shear_strength.toString());
    try testing.expectEqualStrings("SPT-N", StrengthParameterType.spt_n_value.toString());
    try testing.expectEqualStrings("UCS", StrengthParameterType.ucs.toString());
}

test "strength_db: parameter type getUnits" {
    try testing.expectEqualStrings("kPa", StrengthParameterType.undrained_shear_strength.getUnits());
    try testing.expectEqualStrings("blows/300mm", StrengthParameterType.spt_n_value.getUnits());
    try testing.expectEqualStrings("MPa", StrengthParameterType.ucs.getUnits());
}

test "strength_db: confidence level is set" {
    const params = StrengthDatabase.getStrengthParameters(.soil, .firm, null, null, .clay);
    try testing.expect(params != null);
    try testing.expect(params.?.confidence > 0.0);
    try testing.expect(params.?.confidence <= 1.0);
}

test "strength_db: typical values are reasonable" {
    const params = StrengthDatabase.getStrengthParameters(.soil, .firm, null, null, .clay);
    try testing.expect(params != null);

    if (params.?.range.typical_value) |tv| {
        try testing.expect(tv >= params.?.range.lower_bound);
        try testing.expect(tv <= params.?.range.upper_bound);
    }
}
