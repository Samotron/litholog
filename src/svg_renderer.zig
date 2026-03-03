const std = @import("std");
const ags_reader = @import("ags_reader.zig");
const svg_patterns = @import("svg_patterns.zig");

pub const SvgConfig = struct {
    width: f32 = 900,
    depth_scale: f32 = 45,
    min_stratum_height: f32 = 24,
    header_height: f32 = 100,
    depth_column_width: f32 = 70,
    legend_column_width: f32 = 90,
    description_column_width: f32 = 480,
    samples_column_width: f32 = 220,
    show_confidence: bool = true,
    show_warnings: bool = true,
    show_strength_params: bool = false,
    highlight_corrections: bool = true,
    title: ?[]const u8 = null,
};

pub fn renderBorehole(
    allocator: std.mem.Allocator,
    ags: *const ags_reader.AgsFile,
    borehole_id: []const u8,
    config: SvgConfig,
) ![]u8 {
    var strata = std.ArrayList(ags_reader.AgsStratum).init(allocator);
    defer strata.deinit();

    var max_depth: f64 = 0;
    for (ags.strata) |s| {
        if (std.mem.eql(u8, s.location_id, borehole_id)) {
            try strata.append(s);
            if (s.depth_base > max_depth) max_depth = s.depth_base;
        }
    }

    if (strata.items.len == 0) return error.BoreholeNotFound;

    std.sort.block(ags_reader.AgsStratum, strata.items, {}, lessDepthTop);

    const body_height = @as(f32, @floatCast(max_depth)) * config.depth_scale + 20;
    const height = config.header_height + 45 + body_height;

    const depth_x: f32 = 20;
    const legend_x = depth_x + config.depth_column_width;
    const desc_x = legend_x + config.legend_column_width;
    const top_y = config.header_height + 30;

    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    const w = out.writer();

    try w.print("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{d:.0}\" height=\"{d:.0}\" viewBox=\"0 0 {d:.0} {d:.0}\">\n", .{
        config.width,
        height,
        config.width,
        height,
    });
    try w.writeAll(svg_patterns.defs());
    try w.writeAll("\n");

    try w.print("<rect x=\"0\" y=\"0\" width=\"{d:.0}\" height=\"{d:.0}\" fill=\"#fff\"/>\n", .{ config.width, height });
    const title = config.title orelse "LITHOLOG STRIP LOG";
    try w.print("<text x=\"20\" y=\"22\" font-size=\"14\" font-family=\"Arial\" font-weight=\"bold\">{s}</text>\n", .{title});
    try w.print("<text x=\"20\" y=\"42\" font-size=\"16\" font-family=\"Arial\" font-weight=\"bold\">BOREHOLE: {s}</text>\n", .{borehole_id});

    if (findLocation(ags, borehole_id)) |loc| {
        try w.print("<text x=\"20\" y=\"64\" font-size=\"11\" font-family=\"Arial\">LOCATION: E{d:.2} N{d:.2} | GL: {d:.2} m | TYPE: {s} | FINAL DEPTH: {d:.2} m</text>\n", .{
            loc.easting,
            loc.northing,
            loc.ground_level,
            loc.hole_type,
            loc.final_depth,
        });
    }

    try w.print("<rect x=\"{d:.0}\" y=\"{d:.0}\" width=\"{d:.0}\" height=\"{d:.0}\" fill=\"none\" stroke=\"#000\"/>\n", .{ depth_x, top_y, config.width - 40, body_height });
    try drawHeaders(w, depth_x, top_y - 20, config);

    for (strata.items) |s| {
        const y = top_y + @as(f32, @floatCast(s.depth_top)) * config.depth_scale;
        var h = (@as(f32, @floatCast(s.depth_base - s.depth_top))) * config.depth_scale;
        if (h < config.min_stratum_height) h = config.min_stratum_height;
        const samp_x = desc_x + config.description_column_width;

        const pat = svg_patterns.patternForStratum(s);
        try w.print("<rect x=\"{d:.0}\" y=\"{d:.1}\" width=\"{d:.0}\" height=\"{d:.1}\" fill=\"url(#{s})\" stroke=\"#444\" stroke-width=\"0.6\"/>\n", .{
            legend_x,
            y,
            config.legend_column_width,
            h,
            pat,
        });

        try w.print("<text x=\"{d:.0}\" y=\"{d:.1}\" font-size=\"10\" font-family=\"Arial\">{d:.2}</text>\n", .{ depth_x + 6, y + 12, s.depth_top });
        try w.print("<text x=\"{d:.0}\" y=\"{d:.1}\" font-size=\"10\" font-family=\"Arial\">{d:.2}</text>\n", .{ depth_x + 6, y + h - 4, s.depth_base });

        const desc = if (s.formation) |f|
            try std.fmt.allocPrint(allocator, "{s} ({s})", .{ s.description, f })
        else
            try allocator.dupe(u8, s.description);
        defer allocator.free(desc);

        try writeWrappedText(w, desc_x + 6, y + 12, config.description_column_width - 12, desc);

        if (s.parsed) |p| {
            const conf_color = if (p.confidence > 0.85) "#4caf50" else if (p.confidence > 0.6) "#ffb300" else "#e53935";
            if (config.show_confidence) {
                try w.print("<rect x=\"{d:.0}\" y=\"{d:.1}\" width=\"4\" height=\"{d:.1}\" fill=\"{s}\"/>\n", .{ desc_x, y, h, conf_color });
            }
            if (config.show_warnings and p.warnings.len > 0) {
                const warning_text = try std.mem.join(allocator, "; ", p.warnings);
                defer allocator.free(warning_text);
                try w.print("<text x=\"{d:.0}\" y=\"{d:.1}\" font-size=\"11\" font-family=\"Arial\">⚠<title>{s}</title></text>\n", .{ desc_x + config.description_column_width - 14, y + 12, warning_text });
            }
            if (config.show_strength_params) {
                if (p.strength_parameters) |sp| {
                    try w.print("<text x=\"{d:.0}\" y=\"{d:.1}\" font-size=\"9\" font-family=\"Arial\">{s}: {d:.1}-{d:.1} {s}</text>\n", .{
                        samp_x + 6,
                        y + 12,
                        sp.parameter_type.toString(),
                        sp.range.lower_bound,
                        sp.range.upper_bound,
                        sp.parameter_type.getUnits(),
                    });
                }
            }
        }

        try w.print("<line x1=\"{d:.0}\" y1=\"{d:.1}\" x2=\"{d:.0}\" y2=\"{d:.1}\" stroke=\"#ddd\"/>\n", .{ depth_x, y + h, config.width - 20, y + h });
    }

    try w.writeAll("</svg>\n");
    return out.toOwnedSlice();
}

pub fn renderFirstBorehole(allocator: std.mem.Allocator, ags: *const ags_reader.AgsFile, config: SvgConfig) ![]u8 {
    if (ags.locations.len > 0) return renderBorehole(allocator, ags, ags.locations[0].id, config);
    if (ags.strata.len > 0) return renderBorehole(allocator, ags, ags.strata[0].location_id, config);
    return error.BoreholeNotFound;
}

fn findLocation(ags: *const ags_reader.AgsFile, id: []const u8) ?ags_reader.AgsLocation {
    for (ags.locations) |loc| {
        if (std.mem.eql(u8, loc.id, id)) return loc;
    }
    return null;
}

fn lessDepthTop(_: void, a: ags_reader.AgsStratum, b: ags_reader.AgsStratum) bool {
    return a.depth_top < b.depth_top;
}

fn drawHeaders(writer: anytype, x: f32, y: f32, config: SvgConfig) !void {
    const legend_x = x + config.depth_column_width;
    const desc_x = legend_x + config.legend_column_width;
    const samp_x = desc_x + config.description_column_width;

    try writer.print("<rect x=\"{d:.0}\" y=\"{d:.0}\" width=\"{d:.0}\" height=\"20\" fill=\"#f3f3f3\" stroke=\"#000\"/>\n", .{ x, y, config.width - 40 });
    try writer.print("<text x=\"{d:.0}\" y=\"{d:.0}\" font-size=\"10\" font-family=\"Arial\" font-weight=\"bold\">Depth (m)</text>\n", .{ x + 6, y + 14 });
    try writer.print("<text x=\"{d:.0}\" y=\"{d:.0}\" font-size=\"10\" font-family=\"Arial\" font-weight=\"bold\">Legend</text>\n", .{ legend_x + 6, y + 14 });
    try writer.print("<text x=\"{d:.0}\" y=\"{d:.0}\" font-size=\"10\" font-family=\"Arial\" font-weight=\"bold\">Description</text>\n", .{ desc_x + 6, y + 14 });
    try writer.print("<text x=\"{d:.0}\" y=\"{d:.0}\" font-size=\"10\" font-family=\"Arial\" font-weight=\"bold\">Samples/Notes</text>\n", .{ samp_x + 6, y + 14 });

    try writer.print("<line x1=\"{d:.0}\" y1=\"{d:.0}\" x2=\"{d:.0}\" y2=\"{d:.0}\" stroke=\"#000\"/>\n", .{ legend_x, y, legend_x, y + 20 });
    try writer.print("<line x1=\"{d:.0}\" y1=\"{d:.0}\" x2=\"{d:.0}\" y2=\"{d:.0}\" stroke=\"#000\"/>\n", .{ desc_x, y, desc_x, y + 20 });
    try writer.print("<line x1=\"{d:.0}\" y1=\"{d:.0}\" x2=\"{d:.0}\" y2=\"{d:.0}\" stroke=\"#000\"/>\n", .{ samp_x, y, samp_x, y + 20 });
}

fn writeWrappedText(writer: anytype, x: f32, y: f32, width: f32, text: []const u8) !void {
    _ = width;
    var line_y = y;
    var parts = std.mem.splitScalar(u8, text, ' ');
    var current_len: usize = 0;
    var line_buf: [512]u8 = undefined;
    var line_writer = std.io.fixedBufferStream(&line_buf);

    while (parts.next()) |word| {
        const add_len: usize = word.len + (if (current_len > 0) @as(usize, 1) else @as(usize, 0));
        if (current_len + add_len > 42 and current_len > 0) {
            try writer.print("<text x=\"{d:.0}\" y=\"{d:.1}\" font-size=\"10\" font-family=\"Arial\">{s}</text>\n", .{ x, line_y, line_writer.getWritten() });
            line_y += 12;
            line_writer = std.io.fixedBufferStream(&line_buf);
            current_len = 0;
        }

        if (current_len > 0) try line_writer.writer().writeByte(' ');
        try line_writer.writer().writeAll(word);
        current_len += add_len;
    }

    if (current_len > 0) {
        try writer.print("<text x=\"{d:.0}\" y=\"{d:.1}\" font-size=\"10\" font-family=\"Arial\">{s}</text>\n", .{ x, line_y, line_writer.getWritten() });
    }
}
