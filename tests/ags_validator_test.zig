const std = @import("std");
const ags_validator = @import("ags_validator");

test "ags validator validates minimal valid structure" {
    const allocator = std.testing.allocator;

    const sample =
        "\"GROUP\",\"PROJ\"\n" ++
        "\"HEADING\",\"PROJ_ID\"\n" ++
        "\"UNIT\",\"\"\n" ++
        "\"TYPE\",\"ID\"\n" ++
        "\"DATA\",\"P1\"\n" ++
        "\"GROUP\",\"TRAN\"\n" ++
        "\"HEADING\",\"TRAN_ISNO\"\n" ++
        "\"UNIT\",\"\"\n" ++
        "\"TYPE\",\"ID\"\n" ++
        "\"DATA\",\"1\"\n";

    var report = try ags_validator.validateSlice(allocator, sample);
    defer report.deinit(allocator);

    try std.testing.expect(report.is_valid);
}
