const std = @import("std");
const ags_reader = @import("ags_reader.zig");

pub const ValidationReport = struct {
    is_valid: bool,
    issues: [][]const u8,

    pub fn deinit(self: *ValidationReport, allocator: std.mem.Allocator) void {
        for (self.issues) |issue| allocator.free(issue);
        allocator.free(self.issues);
    }
};

pub fn validateFile(allocator: std.mem.Allocator, path: []const u8) !ValidationReport {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 20 * 1024 * 1024);
    defer allocator.free(content);

    return validateSlice(allocator, content);
}

pub fn validateSlice(allocator: std.mem.Allocator, content: []const u8) !ValidationReport {
    var issues = std.ArrayList([]const u8).init(allocator);
    defer issues.deinit();

    for (content) |ch| {
        if (ch > 127) {
            try issues.append(try allocator.dupe(u8, "Rule 1: AGS file must be ASCII only"));
            break;
        }
    }

    var has_proj = false;
    var has_tran = false;
    var proj_data_rows: usize = 0;

    var loca_ids = std.StringHashMap(void).init(allocator);
    defer loca_ids.deinit();

    var current_group_name: []const u8 = "";
    var current_group_name_owned: ?[]u8 = null;
    defer if (current_group_name_owned) |name| allocator.free(name);
    var current_group_kind = GroupKind.none;
    var current_has_heading = false;
    var current_has_unit = false;
    var current_has_type = false;

    var headings = std.ArrayList([]const u8).init(allocator);
    defer {
        for (headings.items) |h| allocator.free(h);
        headings.deinit();
    }

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;

        if (line[0] != '"') {
            try issues.append(try allocator.dupe(u8, "Rule 5/6: AGS rows must be quoted CSV fields"));
            continue;
        }

        const fields = try ags_reader.parseQuotedCsvLine(allocator, line);
        defer freeFields(allocator, fields);
        if (fields.len == 0) continue;

        const descriptor = fields[0];
        if (std.mem.eql(u8, descriptor, "GROUP")) {
            if (current_group_name.len > 0) {
                if (!current_has_heading or !current_has_unit or !current_has_type) {
                    try issues.append(try std.fmt.allocPrint(
                        allocator,
                        "Rule 2: GROUP {s} missing HEADING/UNIT/TYPE rows",
                        .{current_group_name},
                    ));
                }
            }

            if (current_group_name_owned) |name| allocator.free(name);
            current_group_name_owned = if (fields.len > 1) try allocator.dupe(u8, fields[1]) else null;
            current_group_name = current_group_name_owned orelse "";
            current_group_kind = parseGroupKind(current_group_name);
            current_has_heading = false;
            current_has_unit = false;
            current_has_type = false;

            if (current_group_kind == .proj) has_proj = true;
            if (current_group_kind == .tran) has_tran = true;

            for (headings.items) |h| allocator.free(h);
            headings.clearRetainingCapacity();
            continue;
        }

        if (std.mem.eql(u8, descriptor, "HEADING")) {
            current_has_heading = true;
            for (headings.items) |h| allocator.free(h);
            headings.clearRetainingCapacity();
            for (fields) |f| try headings.append(try allocator.dupe(u8, f));
            continue;
        }

        if (std.mem.eql(u8, descriptor, "UNIT")) {
            current_has_unit = true;
            continue;
        }

        if (std.mem.eql(u8, descriptor, "TYPE")) {
            current_has_type = true;
            continue;
        }

        if (!std.mem.eql(u8, descriptor, "DATA")) continue;

        if (current_group_kind == .proj) {
            proj_data_rows += 1;
        }

        if (current_group_kind == .loca) {
            const loca_id = getFieldByHeading(headings.items, fields, "LOCA_ID") orelse "";
            if (loca_id.len == 0) {
                try issues.append(try allocator.dupe(u8, "Rule 10: LOCA_ID key field is required in LOCA DATA rows"));
            } else {
                if (loca_ids.contains(loca_id)) {
                    try issues.append(try std.fmt.allocPrint(allocator, "Rule 10: Duplicate LOCA_ID '{s}'", .{loca_id}));
                } else {
                    try loca_ids.put(try allocator.dupe(u8, loca_id), {});
                }
            }
        }
    }

    if (current_group_name.len > 0) {
        if (!current_has_heading or !current_has_unit or !current_has_type) {
            try issues.append(try std.fmt.allocPrint(
                allocator,
                "Rule 2: GROUP {s} missing HEADING/UNIT/TYPE rows",
                .{current_group_name},
            ));
        }
    }

    if (!has_proj) {
        try issues.append(try allocator.dupe(u8, "Rule 13: PROJ group is required"));
    }
    if (proj_data_rows != 1) {
        try issues.append(try allocator.dupe(u8, "Rule 13: PROJ group must contain exactly one DATA row"));
    }
    if (!has_tran) {
        try issues.append(try allocator.dupe(u8, "Rule 14: TRAN group is required"));
    }

    // Free duplicated keys in loca_ids
    var key_it = loca_ids.keyIterator();
    while (key_it.next()) |key_ptr| allocator.free(key_ptr.*);

    return ValidationReport{
        .is_valid = issues.items.len == 0,
        .issues = try issues.toOwnedSlice(),
    };
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

const GroupKind = enum { none, proj, tran, loca, geol, other };

fn parseGroupKind(name: []const u8) GroupKind {
    if (std.mem.eql(u8, name, "PROJ")) return .proj;
    if (std.mem.eql(u8, name, "TRAN")) return .tran;
    if (std.mem.eql(u8, name, "LOCA")) return .loca;
    if (std.mem.eql(u8, name, "GEOL")) return .geol;
    return .other;
}

test "validator catches missing TRAN" {
    const allocator = std.testing.allocator;

    const sample =
        "\"GROUP\",\"PROJ\"\n" ++
        "\"HEADING\",\"PROJ_ID\"\n" ++
        "\"UNIT\",\"\"\n" ++
        "\"TYPE\",\"ID\"\n" ++
        "\"DATA\",\"P1\"\n";

    var report = try validateSlice(allocator, sample);
    defer report.deinit(allocator);

    try std.testing.expect(!report.is_valid);
    var found = false;
    for (report.issues) |issue| {
        if (std.mem.indexOf(u8, issue, "TRAN") != null) found = true;
    }
    try std.testing.expect(found);
}
