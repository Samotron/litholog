// Demo program showing spatial analysis capabilities
const std = @import("std");
const spatial = @import("parser/spatial.zig");
const types = @import("parser/types.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n===  LITHOLOG SPATIAL ANALYSIS DEMO ===\n\n", .{});

    // Create spatial analyzer
    var analyzer = spatial.SpatialAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Add borehole locations
    try analyzer.addBorehole("BH01", 0.0, 0.0, 100.0);
    try analyzer.addBorehole("BH02", 10.0, 0.0, 100.0);
    try analyzer.addBorehole("BH03", 0.0, 10.0, 100.0);

    std.debug.print("Added 3 boreholes:\n", .{});
    std.debug.print("  BH01: (0.0, 0.0, 100.0)\n", .{});
    std.debug.print("  BH02: (10.0, 0.0, 100.0)\n", .{});
    std.debug.print("  BH03: (0.0, 10.0, 100.0)\n\n", .{});

    // Create geological units
    const loc1 = spatial.Point3D{ .x = 0.0, .y = 0.0, .z = 100.0 };
    const unit1 = try spatial.SpatialUnit.init(
        allocator,
        "BH01",
        loc1,
        0.0,
        1.5,
        "Firm brown CLAY",
        .soil,
    );
    try analyzer.addUnit(unit1);

    const loc2 = spatial.Point3D{ .x = 10.0, .y = 0.0, .z = 100.0 };
    const unit2 = try spatial.SpatialUnit.init(
        allocator,
        "BH02",
        loc2,
        0.0,
        1.2,
        "Firm brown CLAY",
        .soil,
    );
    try analyzer.addUnit(unit2);

    const loc3 = spatial.Point3D{ .x = 0.0, .y = 10.0, .z = 100.0 };
    const unit3 = try spatial.SpatialUnit.init(
        allocator,
        "BH03",
        loc3,
        0.0,
        1.8,
        "Stiff brown CLAY",
        .soil,
    );
    try analyzer.addUnit(unit3);

    std.debug.print("Created 3 geological units (CLAY layers):\n", .{});
    std.debug.print("  Unit 1 (BH01): 0.0-1.5m depth, thickness: {d:.2}m\n", .{unit1.thickness});
    std.debug.print("  Unit 2 (BH02): 0.0-1.2m depth, thickness: {d:.2}m\n", .{unit2.thickness});
    std.debug.print("  Unit 3 (BH03): 0.0-1.8m depth, thickness: {d:.2}m\n\n", .{unit3.thickness});

    // Calculate distances
    std.debug.print("3D Distances between units:\n", .{});
    std.debug.print("  Unit 1 <-> Unit 2: {d:.2}m\n", .{unit1.distanceTo(unit2)});
    std.debug.print("  Unit 1 <-> Unit 3: {d:.2}m\n", .{unit1.distanceTo(unit3)});
    std.debug.print("  Unit 2 <-> Unit 3: {d:.2}m\n\n", .{unit2.distanceTo(unit3)});

    // Spatial clustering
    std.debug.print("Performing spatial clustering (DBSCAN):\n", .{});
    std.debug.print("  Parameters: epsilon=15.0m, min_points=2\n", .{});

    var clusterer = spatial.SpatialClusterer.init(allocator, 15.0, 2);
    const units = [_]spatial.SpatialUnit{ unit1, unit2, unit3 };
    const labels = try clusterer.cluster(&units);

    var result = spatial.ClusterResult.init(allocator, labels);
    defer result.deinit();

    std.debug.print("  Found {} cluster(s)\n", .{result.num_clusters});
    std.debug.print("  Cluster assignments:\n", .{});
    for (labels, 0..) |label, i| {
        if (label >= 0) {
            std.debug.print("    Unit {}: Cluster {}\n", .{ i + 1, label });
        } else {
            std.debug.print("    Unit {}: NOISE\n", .{i + 1});
        }
    }

    // Spatial statistics
    std.debug.print("\nSpatial Statistics:\n", .{});
    const stats = spatial.SpatialStats.calculate(&units);
    std.debug.print("  Centroid: ({d:.2}, {d:.2}, {d:.2})\n", .{ stats.centroid.x, stats.centroid.y, stats.centroid.z });
    std.debug.print("  Std Deviation: {d:.2}m\n", .{stats.std_deviation});
    std.debug.print("  Min Distance: {d:.2}m\n", .{stats.min_distance});
    std.debug.print("  Max Distance: {d:.2}m\n", .{stats.max_distance});
    std.debug.print("  Mean Distance: {d:.2}m\n", .{stats.mean_distance});

    // Spatial interpolation
    std.debug.print("\nSpatial Interpolation (IDW):\n", .{});
    var interpolator = spatial.SpatialInterpolator.init(allocator, .idw);

    const target1 = spatial.Point3D{ .x = 5.0, .y = 0.0, .z = 99.0 };
    const mat_type1 = try interpolator.interpolateMaterialType(target1, &units, 3);
    std.debug.print("  Point (5.0, 0.0, 99.0): {s}\n", .{mat_type1.toString()});

    const target2 = spatial.Point3D{ .x = 5.0, .y = 5.0, .z = 99.0 };
    const mat_type2 = try interpolator.interpolateMaterialType(target2, &units, 3);
    std.debug.print("  Point (5.0, 5.0, 99.0): {s}\n", .{mat_type2.toString()});

    std.debug.print("\n=== DEMO COMPLETE ===\n\n", .{});
}
