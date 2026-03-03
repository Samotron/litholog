const std = @import("std");
const ags_reader = @import("ags_reader");

test "ags reader parses proj loca geol" {
    const allocator = std.testing.allocator;
    var parser = ags_reader.Parser.init(allocator);

    const sample =
        "\"GROUP\",\"PROJ\"\n" ++
        "\"HEADING\",\"PROJ_ID\",\"PROJ_NAME\",\"PROJ_LOC\",\"PROJ_CLNT\"\n" ++
        "\"DATA\",\"P1\",\"Test\",\"Loc\",\"Client\"\n" ++
        "\"GROUP\",\"LOCA\"\n" ++
        "\"HEADING\",\"LOCA_ID\",\"LOCA_NATE\",\"LOCA_NATN\",\"LOCA_GL\",\"LOCA_TYPE\",\"LOCA_FDEP\"\n" ++
        "\"DATA\",\"BH1\",\"1\",\"2\",\"3\",\"BH\",\"4\"\n" ++
        "\"GROUP\",\"GEOL\"\n" ++
        "\"HEADING\",\"LOCA_ID\",\"GEOL_TOP\",\"GEOL_BASE\",\"GEOL_DESC\",\"GEOL_LEG\",\"GEOL_GEOL\",\"GEOL_FORM\"\n" ++
        "\"DATA\",\"BH1\",\"0\",\"1\",\"Firm CLAY\",\"\",\"\",\"\"\n";

    var ags = try ags_reader.parseSlice(allocator, &parser, sample);
    defer ags.deinit(allocator);

    try std.testing.expect(ags.project != null);
    try std.testing.expectEqual(@as(usize, 1), ags.locations.len);
    try std.testing.expectEqual(@as(usize, 1), ags.strata.len);
}
