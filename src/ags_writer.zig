const std = @import("std");
const ags_reader = @import("ags_reader.zig");

pub fn writeEnhanced(allocator: std.mem.Allocator, ags: *const ags_reader.AgsFile) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    const w = out.writer();

    if (ags.project) |p| {
        try writeRow(w, &[_][]const u8{ "GROUP", "PROJ" });
        try writeRow(w, &[_][]const u8{ "HEADING", "PROJ_ID", "PROJ_NAME", "PROJ_LOC", "PROJ_CLNT" });
        try writeRow(w, &[_][]const u8{ "UNIT", "", "", "", "" });
        try writeRow(w, &[_][]const u8{ "TYPE", "ID", "X", "X", "X" });
        try writeRow(w, &[_][]const u8{ "DATA", p.id, p.name, p.location, p.client });
        try w.writeByte('\n');
    }

    if (ags.locations.len > 0) {
        try writeRow(w, &[_][]const u8{ "GROUP", "LOCA" });
        try writeRow(w, &[_][]const u8{ "HEADING", "LOCA_ID", "LOCA_NATE", "LOCA_NATN", "LOCA_GL", "LOCA_TYPE", "LOCA_FDEP" });
        try writeRow(w, &[_][]const u8{ "UNIT", "", "m", "m", "m", "", "" });
        try writeRow(w, &[_][]const u8{ "TYPE", "ID", "2DP", "2DP", "2DP", "PA", "2DP" });

        for (ags.locations) |loc| {
            const easting = try std.fmt.allocPrint(allocator, "{d:.2}", .{loc.easting});
            defer allocator.free(easting);
            const northing = try std.fmt.allocPrint(allocator, "{d:.2}", .{loc.northing});
            defer allocator.free(northing);
            const gl = try std.fmt.allocPrint(allocator, "{d:.2}", .{loc.ground_level});
            defer allocator.free(gl);
            const fdep = try std.fmt.allocPrint(allocator, "{d:.2}", .{loc.final_depth});
            defer allocator.free(fdep);

            try writeRow(w, &[_][]const u8{ "DATA", loc.id, easting, northing, gl, loc.hole_type, fdep });
        }
        try w.writeByte('\n');
    }

    if (ags.strata.len > 0) {
        try writeRow(w, &[_][]const u8{ "GROUP", "GEOL" });
        try writeRow(w, &[_][]const u8{
            "HEADING",   "LOCA_ID",   "GEOL_TOP",  "GEOL_BASE", "GEOL_DESC", "GEOL_LEG",  "GEOL_GEOL", "GEOL_FORM",
            "GEOL_MTYP", "GEOL_CONS", "GEOL_DENS", "GEOL_PSOL", "GEOL_PRCK", "GEOL_RSTR", "GEOL_WETH", "GEOL_CONF",
            "GEOL_WARN",
        });
        try writeRow(w, &[_][]const u8{ "UNIT", "", "m", "m", "", "", "", "", "", "", "", "", "", "", "", "", "" });
        try writeRow(w, &[_][]const u8{ "TYPE", "ID", "2DP", "2DP", "X", "PA", "PA", "X", "X", "X", "X", "X", "X", "X", "X", "2DP", "X" });

        for (ags.strata) |s| {
            const top = try std.fmt.allocPrint(allocator, "{d:.2}", .{s.depth_top});
            defer allocator.free(top);
            const base = try std.fmt.allocPrint(allocator, "{d:.2}", .{s.depth_base});
            defer allocator.free(base);

            var mtyp: []const u8 = "";
            var cons: []const u8 = "";
            var dens: []const u8 = "";
            var psol: []const u8 = "";
            var prck: []const u8 = "";
            var rstr: []const u8 = "";
            var weth: []const u8 = "";
            var conf_value: []u8 = &[_]u8{};
            var warn_value: []u8 = &[_]u8{};

            if (s.parsed) |p| {
                mtyp = p.material_type.toString();
                if (p.consistency) |v| cons = v.toString();
                if (p.density) |v| dens = v.toString();
                if (p.primary_soil_type) |v| psol = v.toString();
                if (p.primary_rock_type) |v| prck = v.toString();
                if (p.rock_strength) |v| rstr = v.toString();
                if (p.weathering_grade) |v| weth = v.toString();
                conf_value = try std.fmt.allocPrint(allocator, "{d:.2}", .{p.confidence});
                if (p.warnings.len > 0) {
                    warn_value = try std.mem.join(allocator, "; ", p.warnings);
                }
            }
            defer if (conf_value.len > 0) allocator.free(conf_value);
            defer if (warn_value.len > 0) allocator.free(warn_value);

            try writeRow(w, &[_][]const u8{
                "DATA",
                s.location_id,
                top,
                base,
                s.description,
                s.legend_code orelse "",
                s.geology_code orelse "",
                s.formation orelse "",
                mtyp,
                cons,
                dens,
                psol,
                prck,
                rstr,
                weth,
                conf_value,
                warn_value,
            });
        }
    }

    return out.toOwnedSlice();
}

fn writeRow(writer: anytype, fields: []const []const u8) !void {
    for (fields, 0..) |field, i| {
        if (i > 0) try writer.writeByte(',');
        try writer.writeByte('"');
        for (field) |ch| {
            if (ch == '"') {
                try writer.writeAll("\"\"");
            } else {
                try writer.writeByte(ch);
            }
        }
        try writer.writeByte('"');
    }
    try writer.writeByte('\n');
}

test "write enhanced GEOL headings" {
    const allocator = std.testing.allocator;

    var ags = ags_reader.AgsFile{
        .project = null,
        .locations = &[_]ags_reader.AgsLocation{},
        .strata = &[_]ags_reader.AgsStratum{},
    };
    defer ags.deinit(allocator);

    const output = try writeEnhanced(allocator, &ags);
    defer allocator.free(output);

    try std.testing.expect(output.len == 0);
}
