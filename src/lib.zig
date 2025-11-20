const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");
const types = @import("parser/types.zig");
const version = @import("version.zig");

const MaterialType = types.MaterialType;
const SoilDescription = types.SoilDescription;
const Consistency = types.Consistency;
const Density = types.Density;
const RockStrength = types.RockStrength;
const SoilType = types.SoilType;
const RockType = types.RockType;
const WeatheringGrade = types.WeatheringGrade;
const RockStructure = types.RockStructure;
const SecondaryConstituent = types.SecondaryConstituent;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const CSecondaryConstituent = extern struct {
    amount: [*:0]const u8,
    soil_type: [*:0]const u8,
};

const CStrengthRange = extern struct {
    lower_bound: f64,
    upper_bound: f64,
    typical_value: f64,
    has_typical_value: i32,
};

const CStrengthParameters = extern struct {
    parameter_type: i32,
    value_range: CStrengthRange,
    confidence: f64,
};

const CSoilDescription = extern struct {
    raw_description: [*:0]const u8,
    material_type: i32,
    consistency: i32,
    density: i32,
    primary_soil_type: i32,
    rock_strength: i32,
    weathering_grade: i32,
    rock_structure: i32,
    primary_rock_type: i32,
    secondary_constituents: [*]CSecondaryConstituent,
    secondary_constituents_count: i32,
    strength_parameters: ?*CStrengthParameters,
    has_strength_parameters: i32,
    confidence: f64,
};

fn zigToC(description: SoilDescription) !*CSoilDescription {
    const c_desc = try allocator.create(CSoilDescription);

    // Copy raw description
    const raw_desc_copy = try allocator.dupeZ(u8, description.raw_description);
    c_desc.raw_description = raw_desc_copy.ptr;

    // Material type
    c_desc.material_type = @intFromEnum(description.material_type);

    // Optional fields - use -1 for None
    c_desc.consistency = if (description.consistency) |c| @intFromEnum(c) else -1;
    c_desc.density = if (description.density) |d| @intFromEnum(d) else -1;
    c_desc.primary_soil_type = if (description.primary_soil_type) |pst| @intFromEnum(pst) else -1;
    c_desc.rock_strength = if (description.rock_strength) |rs| @intFromEnum(rs) else -1;
    c_desc.weathering_grade = if (description.weathering_grade) |wg| @intFromEnum(wg) else -1;
    c_desc.rock_structure = if (description.rock_structure) |rs| @intFromEnum(rs) else -1;
    c_desc.primary_rock_type = if (description.primary_rock_type) |prt| @intFromEnum(prt) else -1;

    // Secondary constituents
    c_desc.secondary_constituents_count = @intCast(description.secondary_constituents.len);
    if (description.secondary_constituents.len > 0) {
        const c_constituents = try allocator.alloc(CSecondaryConstituent, description.secondary_constituents.len);
        for (description.secondary_constituents, 0..) |sc, i| {
            const amount_copy = try allocator.dupeZ(u8, sc.amount);
            const type_copy = try allocator.dupeZ(u8, sc.soil_type);
            c_constituents[i] = CSecondaryConstituent{
                .amount = amount_copy.ptr,
                .soil_type = type_copy.ptr,
            };
        }
        c_desc.secondary_constituents = c_constituents.ptr;
    } else {
        c_desc.secondary_constituents = undefined;
    }

    // Strength parameters
    if (description.strength_parameters) |sp| {
        const c_strength = try allocator.create(CStrengthParameters);
        c_strength.parameter_type = @intFromEnum(sp.parameter_type);
        c_strength.value_range = CStrengthRange{
            .lower_bound = sp.range.lower_bound,
            .upper_bound = sp.range.upper_bound,
            .typical_value = sp.range.typical_value orelse sp.range.getMidpoint(),
            .has_typical_value = if (sp.range.typical_value != null) 1 else 0,
        };
        c_strength.confidence = sp.confidence;
        c_desc.strength_parameters = c_strength;
        c_desc.has_strength_parameters = 1;
    } else {
        c_desc.strength_parameters = null;
        c_desc.has_strength_parameters = 0;
    }

    c_desc.confidence = description.confidence;

    return c_desc;
}

export fn litholog_parse(description: [*:0]const u8) ?*CSoilDescription {
    const desc_slice = std.mem.span(description);

    var parser = bs5930.Parser.init(allocator);
    const result = parser.parse(desc_slice) catch return null;

    return zigToC(result) catch null;
}

export fn litholog_free_description(description: ?*CSoilDescription) void {
    if (description) |desc| {
        // Free raw description
        allocator.free(std.mem.span(desc.raw_description));

        // Free secondary constituents
        if (desc.secondary_constituents_count > 0) {
            const constituents = desc.secondary_constituents[0..@intCast(desc.secondary_constituents_count)];
            for (constituents) |sc| {
                allocator.free(std.mem.span(sc.amount));
                allocator.free(std.mem.span(sc.soil_type));
            }
            allocator.free(constituents);
        }

        // Free strength parameters
        if (desc.strength_parameters) |sp| {
            allocator.destroy(sp);
        }

        allocator.destroy(desc);
    }
}

export fn litholog_description_to_json(description: ?*const CSoilDescription) ?[*:0]const u8 {
    if (description) |desc| {
        // Convert back to Zig description
        var zig_desc = SoilDescription{
            .raw_description = std.mem.span(desc.raw_description),
            .material_type = @enumFromInt(desc.material_type),
            .confidence = @floatCast(desc.confidence),
        };

        // Convert optional fields
        if (desc.consistency >= 0) {
            zig_desc.consistency = @enumFromInt(desc.consistency);
        }
        if (desc.density >= 0) {
            zig_desc.density = @enumFromInt(desc.density);
        }
        if (desc.primary_soil_type >= 0) {
            zig_desc.primary_soil_type = @enumFromInt(desc.primary_soil_type);
        }
        if (desc.rock_strength >= 0) {
            zig_desc.rock_strength = @enumFromInt(desc.rock_strength);
        }
        if (desc.weathering_grade >= 0) {
            zig_desc.weathering_grade = @enumFromInt(desc.weathering_grade);
        }
        if (desc.rock_structure >= 0) {
            zig_desc.rock_structure = @enumFromInt(desc.rock_structure);
        }
        if (desc.primary_rock_type >= 0) {
            zig_desc.primary_rock_type = @enumFromInt(desc.primary_rock_type);
        }

        const json = zig_desc.toJson(allocator) catch return null;
        const json_z = allocator.dupeZ(u8, json) catch return null;
        allocator.free(json);
        return json_z.ptr;
    }
    return null;
}

export fn litholog_free_string(str: ?[*:0]const u8) void {
    if (str) |s| {
        allocator.free(std.mem.span(s));
    }
}

// Utility functions
export fn litholog_material_type_to_string(material_type: i32) [*:0]const u8 {
    const mt: MaterialType = @enumFromInt(material_type);
    return switch (mt) {
        .soil => "soil",
        .rock => "rock",
    };
}

export fn litholog_consistency_to_string(consistency: i32) [*:0]const u8 {
    const c: Consistency = @enumFromInt(consistency);
    const str = c.toString();
    const z_str = allocator.dupeZ(u8, str) catch return "error";
    return z_str.ptr;
}

export fn litholog_density_to_string(density: i32) [*:0]const u8 {
    const d: Density = @enumFromInt(density);
    const str = d.toString();
    const z_str = allocator.dupeZ(u8, str) catch return "error";
    return z_str.ptr;
}

export fn litholog_rock_strength_to_string(strength: i32) [*:0]const u8 {
    const rs: RockStrength = @enumFromInt(strength);
    const str = rs.toString();
    const z_str = allocator.dupeZ(u8, str) catch return "error";
    return z_str.ptr;
}

export fn litholog_soil_type_to_string(soil_type: i32) [*:0]const u8 {
    const st: SoilType = @enumFromInt(soil_type);
    const str = st.toString();
    const z_str = allocator.dupeZ(u8, str) catch return "error";
    return z_str.ptr;
}

export fn litholog_rock_type_to_string(rock_type: i32) [*:0]const u8 {
    const rt: RockType = @enumFromInt(rock_type);
    const str = rt.toString();
    const z_str = allocator.dupeZ(u8, str) catch return "error";
    return z_str.ptr;
}

export fn litholog_weathering_grade_to_string(grade: i32) [*:0]const u8 {
    const wg: WeatheringGrade = @enumFromInt(grade);
    const str = wg.toString();
    const z_str = allocator.dupeZ(u8, str) catch return "error";
    return z_str.ptr;
}

export fn litholog_rock_structure_to_string(structure: i32) [*:0]const u8 {
    const rs: RockStructure = @enumFromInt(structure);
    const str = rs.toString();
    const z_str = allocator.dupeZ(u8, str) catch return "error";
    return z_str.ptr;
}

export fn litholog_strength_parameter_type_to_string(param_type: i32) [*:0]const u8 {
    return switch (param_type) {
        0 => "UCS",
        1 => "Undrained Shear Strength",
        2 => "SPT N-value",
        3 => "Friction Angle",
        else => "Unknown",
    };
}

// Export version functions from the version module
pub const litholog_version_major = version.litholog_version_major;
pub const litholog_version_minor = version.litholog_version_minor;
pub const litholog_version_patch = version.litholog_version_patch;
pub const litholog_version_string = version.litholog_version_string;

// New feature exports

const generator = @import("parser/generator.zig");
const fuzzy = @import("parser/fuzzy.zig");

/// Generate a description string from a parsed description
export fn litholog_generate_description(description: ?*const CSoilDescription) ?[*:0]const u8 {
    if (description) |desc| {
        // Convert C description back to Zig
        var zig_desc = SoilDescription{
            .raw_description = std.mem.span(desc.raw_description),
            .material_type = @enumFromInt(desc.material_type),
            .confidence = @floatCast(desc.confidence),
        };

        if (desc.consistency >= 0) {
            zig_desc.consistency = @enumFromInt(desc.consistency);
        }
        if (desc.density >= 0) {
            zig_desc.density = @enumFromInt(desc.density);
        }
        if (desc.primary_soil_type >= 0) {
            zig_desc.primary_soil_type = @enumFromInt(desc.primary_soil_type);
        }
        if (desc.rock_strength >= 0) {
            zig_desc.rock_strength = @enumFromInt(desc.rock_strength);
        }
        if (desc.weathering_grade >= 0) {
            zig_desc.weathering_grade = @enumFromInt(desc.weathering_grade);
        }
        if (desc.rock_structure >= 0) {
            zig_desc.rock_structure = @enumFromInt(desc.rock_structure);
        }
        if (desc.primary_rock_type >= 0) {
            zig_desc.primary_rock_type = @enumFromInt(desc.primary_rock_type);
        }

        const generated = generator.generate(zig_desc, allocator) catch return null;
        const generated_z = allocator.dupeZ(u8, generated) catch return null;
        allocator.free(generated);
        return generated_z.ptr;
    }
    return null;
}

/// Generate a concise description
export fn litholog_generate_concise(description: ?*const CSoilDescription) ?[*:0]const u8 {
    if (description) |desc| {
        var zig_desc = SoilDescription{
            .raw_description = std.mem.span(desc.raw_description),
            .material_type = @enumFromInt(desc.material_type),
            .confidence = @floatCast(desc.confidence),
        };

        if (desc.consistency >= 0) {
            zig_desc.consistency = @enumFromInt(desc.consistency);
        }
        if (desc.density >= 0) {
            zig_desc.density = @enumFromInt(desc.density);
        }
        if (desc.primary_soil_type >= 0) {
            zig_desc.primary_soil_type = @enumFromInt(desc.primary_soil_type);
        }
        if (desc.rock_strength >= 0) {
            zig_desc.rock_strength = @enumFromInt(desc.rock_strength);
        }
        if (desc.primary_rock_type >= 0) {
            zig_desc.primary_rock_type = @enumFromInt(desc.primary_rock_type);
        }

        const generated = generator.generateConcise(zig_desc, allocator) catch return null;
        const generated_z = allocator.dupeZ(u8, generated) catch return null;
        allocator.free(generated);
        return generated_z.ptr;
    }
    return null;
}

/// Fuzzy match a string against options
export fn litholog_fuzzy_match(target: [*:0]const u8, options_ptr: [*][*:0]const u8, options_count: i32, threshold: f32) ?[*:0]const u8 {
    const target_slice = std.mem.span(target);

    var options = allocator.alloc([]const u8, @intCast(options_count)) catch return null;
    defer allocator.free(options);

    for (0..@intCast(options_count)) |i| {
        options[i] = std.mem.span(options_ptr[i]);
    }

    const match = fuzzy.fuzzyMatchCaseInsensitive(target_slice, options, threshold, allocator) catch return null;

    if (match) |m| {
        const match_z = allocator.dupeZ(u8, m) catch return null;
        return match_z.ptr;
    }

    return null;
}

/// Calculate similarity between two strings (0.0 to 1.0)
export fn litholog_similarity(s1: [*:0]const u8, s2: [*:0]const u8) f32 {
    const s1_slice = std.mem.span(s1);
    const s2_slice = std.mem.span(s2);

    return fuzzy.similarityRatio(s1_slice, s2_slice, allocator) catch 0.0;
}

/// Generate a description from JSON string
export fn litholog_generate_from_json(json_str: [*:0]const u8) ?[*:0]const u8 {
    const json_slice = std.mem.span(json_str);

    // Parse JSON to SoilDescription
    const desc = types.SoilDescription.fromJson(json_slice, allocator) catch return null;
    defer desc.deinit(allocator);

    // Generate standard format
    const generated = generator.generate(desc, allocator) catch return null;
    const generated_z = allocator.dupeZ(u8, generated) catch return null;
    allocator.free(generated);
    return generated_z.ptr;
}

/// Generate a description from JSON string with format option
export fn litholog_generate_from_json_format(json_str: [*:0]const u8, format: i32) ?[*:0]const u8 {
    const json_slice = std.mem.span(json_str);

    // Parse JSON to SoilDescription
    const desc = types.SoilDescription.fromJson(json_slice, allocator) catch return null;
    defer desc.deinit(allocator);

    // Generate based on format: 0=standard, 1=concise, 2=verbose, 3=bs5930
    const generated = switch (format) {
        0 => generator.generate(desc, allocator) catch return null,
        1 => generator.generateConcise(desc, allocator) catch return null,
        2 => generator.generateVerbose(desc, allocator) catch return null,
        3 => generator.generateBS5930(desc, allocator) catch return null,
        else => return null,
    };
    const generated_z = allocator.dupeZ(u8, generated) catch return null;
    allocator.free(generated);
    return generated_z.ptr;
}
