const std = @import("std");
const ags_reader = @import("ags_reader");
const ags_writer = @import("ags_writer");

test "ags writer emits enhanced geol fields" {
    const allocator = std.testing.allocator;
    var strata = try allocator.alloc(ags_reader.AgsStratum, 1);
    strata[0] = .{
        .location_id = try allocator.dupe(u8, "BH1"),
        .depth_top = 0.0,
        .depth_base = 1.0,
        .description = try allocator.dupe(u8, "Firm CLAY"),
        .legend_code = null,
        .geology_code = null,
        .formation = null,
        .parsed = null,
    };
    var ags = ags_reader.AgsFile{
        .project = null,
        .locations = try allocator.alloc(ags_reader.AgsLocation, 0),
        .strata = strata,
    };
    defer ags.deinit(allocator);

    const out = try ags_writer.writeEnhanced(allocator, &ags);
    defer allocator.free(out);

    try std.testing.expect(std.mem.indexOf(u8, out, "GEOL_MTYP") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "GEOL_CONF") != null);
}
