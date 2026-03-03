const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");
const ags_reader = @import("ags_reader.zig");
const ags_writer = @import("ags_writer.zig");
const ags_validator = @import("ags_validator.zig");
const svg_renderer = @import("svg_renderer.zig");

pub fn handle(allocator: std.mem.Allocator, args: [][:0]u8) !bool {
    if (args.len <= 1) return false;

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "inspect")) {
        try handleInspect(allocator, args[2..]);
        return true;
    }
    if (std.mem.eql(u8, cmd, "enhance")) {
        try handleEnhance(allocator, args[2..]);
        return true;
    }
    if (std.mem.eql(u8, cmd, "validate")) {
        try handleValidate(allocator, args[2..]);
        return true;
    }

    return false;
}

fn handleInspect(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len == 0) return error.MissingFileArgument;

    const input_path = args[0];
    var format: []const u8 = "svg";
    var output_path: ?[]const u8 = null;
    var borehole: ?[]const u8 = null;
    var svg_config = svg_renderer.SvgConfig{};

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--format")) {
            if (i + 1 >= args.len) return error.MissingFormatArgument;
            i += 1;
            format = args[i];
        } else if (std.mem.eql(u8, args[i], "--svg")) {
            format = "svg";
        } else if (std.mem.eql(u8, args[i], "--json")) {
            format = "json";
        } else if (std.mem.eql(u8, args[i], "--borehole")) {
            if (i + 1 >= args.len) return error.MissingBoreholeArgument;
            i += 1;
            borehole = args[i];
        } else if (std.mem.eql(u8, args[i], "--scale")) {
            if (i + 1 >= args.len) return error.MissingScaleArgument;
            i += 1;
            svg_config.depth_scale = @floatCast(try std.fmt.parseFloat(f64, args[i]));
        } else if (std.mem.eql(u8, args[i], "--width")) {
            if (i + 1 >= args.len) return error.MissingWidthArgument;
            i += 1;
            svg_config.width = @floatCast(try std.fmt.parseFloat(f64, args[i]));
        } else if (std.mem.eql(u8, args[i], "--no-confidence")) {
            svg_config.show_confidence = false;
        } else if (std.mem.eql(u8, args[i], "--show-strength")) {
            svg_config.show_strength_params = true;
        } else if (std.mem.eql(u8, args[i], "--no-corrections")) {
            svg_config.highlight_corrections = false;
        } else if (std.mem.eql(u8, args[i], "--title")) {
            if (i + 1 >= args.len) return error.MissingTitleArgument;
            i += 1;
            svg_config.title = args[i];
        } else if (std.mem.eql(u8, args[i], "--output") or std.mem.eql(u8, args[i], "-o")) {
            if (i + 1 >= args.len) return error.MissingOutputArgument;
            i += 1;
            output_path = args[i];
        }
    }

    var parser = bs5930.Parser.init(allocator);
    var ags = try ags_reader.parseFile(allocator, &parser, input_path);
    defer ags.deinit(allocator);

    const output = if (std.mem.eql(u8, format, "json"))
        try toJsonInspect(allocator, &ags)
    else if (std.mem.eql(u8, format, "csv"))
        try toCsvInspect(allocator, &ags)
    else if (std.mem.eql(u8, format, "svg"))
        if (borehole) |id|
            try svg_renderer.renderBorehole(allocator, &ags, id, svg_config)
        else
            try svg_renderer.renderFirstBorehole(allocator, &ags, svg_config)
    else
        try toSummaryInspect(allocator, &ags);
    defer allocator.free(output);

    if (output_path) |path| {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(output);
    } else {
        try std.io.getStdOut().writer().print("{s}\n", .{output});
    }
}

fn handleEnhance(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len == 0) return error.MissingFileArgument;

    const input_path = args[0];
    var output_path: ?[]const u8 = null;
    var json_output = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--output") or std.mem.eql(u8, args[i], "-o")) {
            if (i + 1 >= args.len) return error.MissingOutputArgument;
            i += 1;
            output_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--json")) {
            json_output = true;
        }
    }

    if (output_path == null) return error.MissingOutputArgument;

    var parser = bs5930.Parser.init(allocator);
    var ags = try ags_reader.parseFile(allocator, &parser, input_path);
    defer ags.deinit(allocator);

    const enhanced = try ags_writer.writeEnhanced(allocator, &ags);
    defer allocator.free(enhanced);

    const file = try std.fs.cwd().createFile(output_path.?, .{});
    defer file.close();
    try file.writeAll(enhanced);

    if (json_output) {
        try std.io.getStdOut().writer().print("{{\"status\":\"ok\",\"output\":\"{s}\"}}\n", .{output_path.?});
    } else {
        try std.io.getStdOut().writer().print("Enhanced AGS written to {s}\n", .{output_path.?});
    }
}

fn handleValidate(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len == 0) return error.MissingFileArgument;
    const input_path = args[0];
    var json_output = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--json")) json_output = true;
    }

    var report = try ags_validator.validateFile(allocator, input_path);
    defer report.deinit(allocator);

    const stdout = std.io.getStdOut().writer();
    if (json_output) {
        try stdout.print("{{\"valid\":{s},\"issues\":[", .{if (report.is_valid) "true" else "false"});
        for (report.issues, 0..) |issue, i| {
            if (i > 0) try stdout.writeByte(',');
            try stdout.print("\"{s}\"", .{issue});
        }
        try stdout.writeAll("]}\n");
    } else if (report.is_valid) {
        try stdout.writeAll("AGS validation: PASS\n");
    } else {
        try stdout.print("AGS validation: FAIL ({d} issues)\n", .{report.issues.len});
        for (report.issues) |issue| {
            try stdout.print("- {s}\n", .{issue});
        }
    }
}

fn toSummaryInspect(allocator: std.mem.Allocator, ags: *const ags_reader.AgsFile) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    const w = out.writer();

    try w.print("Locations: {d}\n", .{ags.locations.len});
    try w.print("Strata: {d}\n", .{ags.strata.len});
    if (ags.project) |p| {
        try w.print("Project: {s} ({s})\n", .{ p.name, p.id });
    }

    var counts = std.StringHashMap(usize).init(allocator);
    defer counts.deinit();
    for (ags.strata) |s| {
        const entry = try counts.getOrPut(s.location_id);
        if (!entry.found_existing) entry.value_ptr.* = 0;
        entry.value_ptr.* += 1;
    }

    var it = counts.iterator();
    while (it.next()) |entry| {
        try w.print("- {s}: {d} strata\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    return out.toOwnedSlice();
}

fn toJsonInspect(allocator: std.mem.Allocator, ags: *const ags_reader.AgsFile) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    const w = out.writer();

    try w.writeAll("{\"locations\":[");
    for (ags.locations, 0..) |loc, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":\"{s}\",\"easting\":{d:.2},\"northing\":{d:.2},\"ground_level\":{d:.2},\"final_depth\":{d:.2}}}", .{
            loc.id,
            loc.easting,
            loc.northing,
            loc.ground_level,
            loc.final_depth,
        });
    }
    try w.writeAll("],\"strata\":[");
    for (ags.strata, 0..) |s, i| {
        if (i > 0) try w.writeByte(',');
        const mtyp = if (s.parsed) |p| p.material_type.toString() else "";
        try w.print("{{\"location_id\":\"{s}\",\"depth_top\":{d:.2},\"depth_base\":{d:.2},\"description\":\"{s}\",\"material_type\":\"{s}\"}}", .{
            s.location_id,
            s.depth_top,
            s.depth_base,
            s.description,
            mtyp,
        });
    }
    try w.writeAll("]}");

    return out.toOwnedSlice();
}

fn toCsvInspect(allocator: std.mem.Allocator, ags: *const ags_reader.AgsFile) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    const w = out.writer();

    try w.writeAll("location_id,depth_top,depth_base,description,material_type,primary_soil_type,confidence\n");
    for (ags.strata) |s| {
        const mtyp = if (s.parsed) |p| p.material_type.toString() else "";
        const psoil = if (s.parsed) |p| if (p.primary_soil_type) |pst| pst.toString() else "" else "";
        const conf: f32 = if (s.parsed) |p| p.confidence else 0;
        try w.print("{s},{d:.2},{d:.2},\"{s}\",{s},{s},{d:.2}\n", .{
            s.location_id,
            s.depth_top,
            s.depth_base,
            s.description,
            mtyp,
            psoil,
            conf,
        });
    }

    return out.toOwnedSlice();
}
