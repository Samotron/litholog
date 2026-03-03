const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");
pub const Parser = bs5930.Parser;

pub const AgsProject = struct {
    id: []const u8,
    name: []const u8,
    location: []const u8,
    client: []const u8,
};

pub const AgsLocation = struct {
    id: []const u8,
    easting: f64,
    northing: f64,
    ground_level: f64,
    hole_type: []const u8,
    final_depth: f64,
};

pub const AgsStratum = struct {
    location_id: []const u8,
    depth_top: f64,
    depth_base: f64,
    description: []const u8,
    legend_code: ?[]const u8,
    geology_code: ?[]const u8,
    formation: ?[]const u8,
    parsed: ?bs5930.SoilDescription,
};

pub const AgsFile = struct {
    project: ?AgsProject = null,
    locations: []AgsLocation,
    strata: []AgsStratum,

    pub fn deinit(self: *AgsFile, allocator: std.mem.Allocator) void {
        if (self.project) |project| {
            allocator.free(project.id);
            allocator.free(project.name);
            allocator.free(project.location);
            allocator.free(project.client);
        }

        for (self.locations) |loc| {
            allocator.free(loc.id);
            allocator.free(loc.hole_type);
        }
        allocator.free(self.locations);

        for (self.strata) |stratum| {
            allocator.free(stratum.location_id);
            allocator.free(stratum.description);
            if (stratum.legend_code) |v| allocator.free(v);
            if (stratum.geology_code) |v| allocator.free(v);
            if (stratum.formation) |v| allocator.free(v);
            if (stratum.parsed) |parsed| parsed.deinit(allocator);
        }
        allocator.free(self.strata);
    }
};

pub fn parseFile(allocator: std.mem.Allocator, parser: *bs5930.Parser, path: []const u8) !AgsFile {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 20 * 1024 * 1024);
    defer allocator.free(content);

    return parseSlice(allocator, parser, content);
}

pub fn parseSlice(allocator: std.mem.Allocator, parser: *bs5930.Parser, content: []const u8) !AgsFile {
    var locations = std.ArrayList(AgsLocation).init(allocator);
    defer locations.deinit();

    var strata = std.ArrayList(AgsStratum).init(allocator);
    defer strata.deinit();

    var project: ?AgsProject = null;

    var group_kind = GroupKind.none;
    var headings = std.ArrayList([]const u8).init(allocator);
    defer {
        for (headings.items) |h| allocator.free(h);
        headings.deinit();
    }

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;

        const fields = try parseQuotedCsvLine(allocator, line);
        defer freeFields(allocator, fields);
        if (fields.len == 0) continue;

        const descriptor = fields[0];
        if (std.mem.eql(u8, descriptor, "GROUP")) {
            group_kind = parseGroupKind(if (fields.len > 1) fields[1] else "");
            for (headings.items) |h| allocator.free(h);
            headings.clearRetainingCapacity();
            continue;
        }

        if (std.mem.eql(u8, descriptor, "HEADING")) {
            for (headings.items) |h| allocator.free(h);
            headings.clearRetainingCapacity();
            for (fields) |f| {
                try headings.append(try allocator.dupe(u8, f));
            }
            continue;
        }

        if (!std.mem.eql(u8, descriptor, "DATA")) continue;

        switch (group_kind) {
            .proj => {
                if (project == null) {
                    project = try parseProjectRow(allocator, headings.items, fields);
                }
            },
            .loca => {
                try locations.append(try parseLocationRow(allocator, headings.items, fields));
            },
            .geol => {
                try strata.append(try parseStratumRow(allocator, parser, headings.items, fields));
            },
            else => {},
        }
    }

    return AgsFile{
        .project = project,
        .locations = try locations.toOwnedSlice(),
        .strata = try strata.toOwnedSlice(),
    };
}

const GroupKind = enum { none, proj, loca, geol, other };

fn parseGroupKind(name: []const u8) GroupKind {
    if (std.mem.eql(u8, name, "PROJ")) return .proj;
    if (std.mem.eql(u8, name, "LOCA")) return .loca;
    if (std.mem.eql(u8, name, "GEOL")) return .geol;
    return .other;
}

fn parseProjectRow(allocator: std.mem.Allocator, headings: []const []const u8, fields: []const []const u8) !AgsProject {
    return AgsProject{
        .id = try allocator.dupe(u8, getFieldByHeading(headings, fields, "PROJ_ID") orelse ""),
        .name = try allocator.dupe(u8, getFieldByHeading(headings, fields, "PROJ_NAME") orelse ""),
        .location = try allocator.dupe(u8, getFieldByHeading(headings, fields, "PROJ_LOC") orelse ""),
        .client = try allocator.dupe(u8, getFieldByHeading(headings, fields, "PROJ_CLNT") orelse ""),
    };
}

fn parseLocationRow(allocator: std.mem.Allocator, headings: []const []const u8, fields: []const []const u8) !AgsLocation {
    return AgsLocation{
        .id = try allocator.dupe(u8, getFieldByHeading(headings, fields, "LOCA_ID") orelse ""),
        .easting = parseFloatOrDefault(getFieldByHeading(headings, fields, "LOCA_NATE"), 0),
        .northing = parseFloatOrDefault(getFieldByHeading(headings, fields, "LOCA_NATN"), 0),
        .ground_level = parseFloatOrDefault(getFieldByHeading(headings, fields, "LOCA_GL"), 0),
        .hole_type = try allocator.dupe(u8, getFieldByHeading(headings, fields, "LOCA_TYPE") orelse ""),
        .final_depth = parseFloatOrDefault(getFieldByHeading(headings, fields, "LOCA_FDEP"), 0),
    };
}

fn parseStratumRow(
    allocator: std.mem.Allocator,
    parser: *bs5930.Parser,
    headings: []const []const u8,
    fields: []const []const u8,
) !AgsStratum {
    const desc = getFieldByHeading(headings, fields, "GEOL_DESC") orelse "";
    const parsed_desc: ?bs5930.SoilDescription = parser.parse(desc) catch null;

    const formation_from_field = getFieldByHeading(headings, fields, "GEOL_FORM");
    var formation: ?[]const u8 = null;
    if (formation_from_field) |f| {
        if (f.len > 0) formation = try allocator.dupe(u8, f);
    } else if (parsed_desc) |p| {
        if (p.geological_formation) |gf| {
            formation = try allocator.dupe(u8, gf);
        }
    }

    return AgsStratum{
        .location_id = try allocator.dupe(u8, getFieldByHeading(headings, fields, "LOCA_ID") orelse ""),
        .depth_top = parseFloatOrDefault(getFieldByHeading(headings, fields, "GEOL_TOP"), 0),
        .depth_base = parseFloatOrDefault(getFieldByHeading(headings, fields, "GEOL_BASE"), 0),
        .description = try allocator.dupe(u8, desc),
        .legend_code = try dupOptional(allocator, getFieldByHeading(headings, fields, "GEOL_LEG")),
        .geology_code = try dupOptional(allocator, getFieldByHeading(headings, fields, "GEOL_GEOL")),
        .formation = formation,
        .parsed = parsed_desc,
    };
}

fn parseFloatOrDefault(maybe_value: ?[]const u8, default: f64) f64 {
    if (maybe_value) |value| {
        if (value.len == 0) return default;
        return std.fmt.parseFloat(f64, value) catch default;
    }
    return default;
}

fn dupOptional(allocator: std.mem.Allocator, maybe_value: ?[]const u8) !?[]const u8 {
    if (maybe_value) |value| {
        if (value.len > 0) return try allocator.dupe(u8, value);
    }
    return null;
}

fn getFieldByHeading(headings: []const []const u8, fields: []const []const u8, heading: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i < headings.len) : (i += 1) {
        if (!std.mem.eql(u8, headings[i], heading)) continue;
        if (i < fields.len) return fields[i];
        return null;
    }
    return null;
}

fn freeFields(allocator: std.mem.Allocator, fields: []const []const u8) void {
    for (fields) |f| allocator.free(f);
    allocator.free(fields);
}

pub fn parseQuotedCsvLine(allocator: std.mem.Allocator, line: []const u8) ![]const []const u8 {
    var fields = std.ArrayList([]const u8).init(allocator);
    defer fields.deinit();

    var field = std.ArrayList(u8).init(allocator);
    defer field.deinit();

    var i: usize = 0;
    var in_quotes = false;

    while (i < line.len) : (i += 1) {
        const ch = line[i];
        if (ch == '"') {
            if (in_quotes and i + 1 < line.len and line[i + 1] == '"') {
                try field.append('"');
                i += 1;
            } else {
                in_quotes = !in_quotes;
            }
            continue;
        }

        if (ch == ',' and !in_quotes) {
            try fields.append(try field.toOwnedSlice());
            field.clearRetainingCapacity();
            continue;
        }

        try field.append(ch);
    }

    try fields.append(try field.toOwnedSlice());
    return fields.toOwnedSlice();
}

test "parse basic AGS groups" {
    const allocator = std.testing.allocator;
    var parser = bs5930.Parser.init(allocator);

    const sample =
        "\"GROUP\",\"PROJ\"\n" ++
        "\"HEADING\",\"PROJ_ID\",\"PROJ_NAME\",\"PROJ_LOC\",\"PROJ_CLNT\"\n" ++
        "\"DATA\",\"25001\",\"M1 Junction 12\",\"Bedfordshire\",\"Highways England\"\n" ++
        "\"GROUP\",\"LOCA\"\n" ++
        "\"HEADING\",\"LOCA_ID\",\"LOCA_NATE\",\"LOCA_NATN\",\"LOCA_GL\",\"LOCA_TYPE\",\"LOCA_FDEP\"\n" ++
        "\"DATA\",\"BH01\",\"510234.00\",\"226789.00\",\"85.40\",\"BH\",\"15.50\"\n" ++
        "\"GROUP\",\"GEOL\"\n" ++
        "\"HEADING\",\"LOCA_ID\",\"GEOL_TOP\",\"GEOL_BASE\",\"GEOL_DESC\",\"GEOL_LEG\",\"GEOL_GEOL\",\"GEOL_FORM\"\n" ++
        "\"DATA\",\"BH01\",\"0.30\",\"2.50\",\"Firm brown CLAY\",\"102\",\"LC\",\"London Clay Formation\"\n";

    var ags = try parseSlice(allocator, &parser, sample);
    defer ags.deinit(allocator);

    try std.testing.expect(ags.project != null);
    try std.testing.expectEqualStrings("25001", ags.project.?.id);
    try std.testing.expectEqual(@as(usize, 1), ags.locations.len);
    try std.testing.expectEqual(@as(usize, 1), ags.strata.len);
    try std.testing.expect(ags.strata[0].parsed != null);
}
