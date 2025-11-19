const std = @import("std");
const spatial = @import("parser/spatial.zig");
const types = @import("parser/types.zig");

test "Point3D distance calculations" {
    const p1 = spatial.Point3D{ .x = 0, .y = 0, .z = 0 };
    const p2 = spatial.Point3D{ .x = 3, .y = 4, .z = 0 };
    const p3 = spatial.Point3D{ .x = 0, .y = 0, .z = 5 };

    // 2D distance (3-4-5 triangle)
    try std.testing.expectApproxEqAbs(5.0, p1.distance(p2), 0.001);
    try std.testing.expectApproxEqAbs(5.0, p1.horizontalDistance(p2), 0.001);

    // Vertical distance
    try std.testing.expectApproxEqAbs(5.0, p1.verticalDistance(p3), 0.001);
    try std.testing.expectApproxEqAbs(0.0, p1.verticalDistance(p2), 0.001);

    // 3D distance
    const p4 = spatial.Point3D{ .x = 1, .y = 2, .z = 2 };
    try std.testing.expectApproxEqAbs(3.0, p1.distance(p4), 0.001);
}

test "SpatialUnit basic operations" {
    const allocator = std.testing.allocator;

    const location = spatial.Point3D{ .x = 100, .y = 200, .z = 50 };
    var unit = try spatial.SpatialUnit.init(
        allocator,
        "BH01",
        location,
        2.0,
        5.0,
        "Firm brown CLAY",
        .soil,
    );
    defer unit.deinit();

    // Check calculated fields
    try std.testing.expectApproxEqAbs(3.0, unit.thickness, 0.001);
    try std.testing.expectApproxEqAbs(3.5, unit.mid_depth, 0.001);

    // Check midpoint (Z should be location.z - mid_depth)
    const mid = unit.getMidPoint();
    try std.testing.expectApproxEqAbs(100.0, mid.x, 0.001);
    try std.testing.expectApproxEqAbs(200.0, mid.y, 0.001);
    try std.testing.expectApproxEqAbs(46.5, mid.z, 0.001);
}

test "SpatialAnalyzer basic operations" {
    const allocator = std.testing.allocator;

    var analyzer = spatial.SpatialAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Add boreholes
    try analyzer.addBorehole("BH01", 0, 0, 100);
    try analyzer.addBorehole("BH02", 10, 0, 100);
    try analyzer.addBorehole("BH03", 0, 10, 100);

    // Add units
    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(
        allocator,
        "BH01",
        loc1,
        0.0,
        2.0,
        "CLAY",
        .soil,
    );
    try analyzer.addUnit(unit1);

    const loc2 = spatial.Point3D{ .x = 10, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(
        allocator,
        "BH02",
        loc2,
        0.0,
        2.0,
        "CLAY",
        .soil,
    );
    try analyzer.addUnit(unit2);

    const loc3 = spatial.Point3D{ .x = 0, .y = 10, .z = 100 };
    const unit3 = try spatial.SpatialUnit.init(
        allocator,
        "BH03",
        loc3,
        0.0,
        2.0,
        "SAND",
        .soil,
    );
    try analyzer.addUnit(unit3);

    // Test finding nearest neighbors
    const neighbors = try analyzer.findNearestNeighbors(&unit1, 15.0, 10);
    defer allocator.free(neighbors);

    try std.testing.expectEqual(@as(usize, 2), neighbors.len);
}

test "Spatial statistics" {
    const allocator = std.testing.allocator;

    // Create units in a simple pattern
    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(
        allocator,
        "BH01",
        loc1,
        0.0,
        2.0,
        "CLAY",
        .soil,
    );
    defer unit1.deinit();

    const loc2 = spatial.Point3D{ .x = 10, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(
        allocator,
        "BH02",
        loc2,
        0.0,
        2.0,
        "CLAY",
        .soil,
    );
    defer unit2.deinit();

    const units = [_]spatial.SpatialUnit{ unit1, unit2 };

    const stats = spatial.SpatialStats.calculate(&units);

    // Centroid should be at midpoint
    try std.testing.expectApproxEqAbs(5.0, stats.centroid.x, 0.001);
    try std.testing.expectApproxEqAbs(0.0, stats.centroid.y, 0.001);

    // Mean distance should be 10.0 (only one pair)
    try std.testing.expectApproxEqAbs(10.0, stats.mean_distance, 0.001);
}

test "IDW weight calculation" {
    const allocator = std.testing.allocator;

    var analyzer = spatial.SpatialAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Create three units
    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(allocator, "BH01", loc1, 0.0, 2.0, "CLAY", .soil);

    const loc2 = spatial.Point3D{ .x = 10, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(allocator, "BH02", loc2, 0.0, 2.0, "CLAY", .soil);

    const loc3 = spatial.Point3D{ .x = 20, .y = 0, .z = 100 };
    const unit3 = try spatial.SpatialUnit.init(allocator, "BH03", loc3, 0.0, 2.0, "SAND", .soil);

    const units = [_]spatial.SpatialUnit{ unit1, unit2, unit3 };

    // Calculate weights for point at (5, 0, 99) - closer to unit1 and unit2
    const target = spatial.Point3D{ .x = 5, .y = 0, .z = 99 };
    const weights = try analyzer.calculateIDWWeights(target, &units, 2.0);
    defer allocator.free(weights);

    // Weights should sum to 1
    var sum: f64 = 0;
    for (weights) |w| {
        sum += w;
    }
    try std.testing.expectApproxEqAbs(1.0, sum, 0.001);

    // First weight should be larger (closer)
    try std.testing.expect(weights[0] > weights[1]);
    try std.testing.expect(weights[1] > weights[2]);

    unit1.deinit();
    unit2.deinit();
    unit3.deinit();
}

test "Correlation matrix" {
    const allocator = std.testing.allocator;

    var analyzer = spatial.SpatialAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Add two units
    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(allocator, "BH01", loc1, 0.0, 2.0, "CLAY", .soil);
    try analyzer.addUnit(unit1);

    const loc2 = spatial.Point3D{ .x = 5, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(allocator, "BH02", loc2, 0.0, 2.0, "SAND", .soil);
    try analyzer.addUnit(unit2);

    const matrix = try analyzer.calculateCorrelationMatrix();
    defer analyzer.freeCorrelationMatrix(matrix);

    // Diagonal should be zero
    try std.testing.expectApproxEqAbs(0.0, matrix[0][0], 0.001);
    try std.testing.expectApproxEqAbs(0.0, matrix[1][1], 0.001);

    // Off-diagonal should be distance (5.0)
    try std.testing.expectApproxEqAbs(5.0, matrix[0][1], 0.001);
    try std.testing.expectApproxEqAbs(5.0, matrix[1][0], 0.001);
}

test "Find units in region" {
    const allocator = std.testing.allocator;

    var analyzer = spatial.SpatialAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Add units at different locations
    const loc1 = spatial.Point3D{ .x = 5, .y = 5, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(allocator, "BH01", loc1, 1.0, 3.0, "CLAY", .soil);
    try analyzer.addUnit(unit1);

    const loc2 = spatial.Point3D{ .x = 15, .y = 5, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(allocator, "BH02", loc2, 1.0, 3.0, "SAND", .soil);
    try analyzer.addUnit(unit2);

    const loc3 = spatial.Point3D{ .x = 5, .y = 15, .z = 100 };
    const unit3 = try spatial.SpatialUnit.init(allocator, "BH03", loc3, 5.0, 7.0, "GRAVEL", .soil);
    try analyzer.addUnit(unit3);

    // Find units in region (0-10, 0-10, 0-4 depth)
    const units_in_region = try analyzer.findUnitsInRegion(0, 10, 0, 10, 0, 4);
    defer allocator.free(units_in_region);

    // Should find unit1 only (unit2 is outside X range, unit3 is outside depth range)
    try std.testing.expectEqual(@as(usize, 1), units_in_region.len);
    try std.testing.expect(std.mem.eql(u8, "BH01", units_in_region[0].borehole_id));
}

test "Spatial clustering with DBSCAN" {
    const allocator = std.testing.allocator;

    // Create units in two distinct clusters
    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(allocator, "BH01", loc1, 0.0, 2.0, "CLAY", .soil);
    defer unit1.deinit();

    const loc2 = spatial.Point3D{ .x = 1, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(allocator, "BH02", loc2, 0.0, 2.0, "CLAY", .soil);
    defer unit2.deinit();

    const loc3 = spatial.Point3D{ .x = 0, .y = 1, .z = 100 };
    const unit3 = try spatial.SpatialUnit.init(allocator, "BH03", loc3, 0.0, 2.0, "CLAY", .soil);
    defer unit3.deinit();

    // Far away unit (noise)
    const loc4 = spatial.Point3D{ .x = 100, .y = 100, .z = 100 };
    const unit4 = try spatial.SpatialUnit.init(allocator, "BH04", loc4, 0.0, 2.0, "SAND", .soil);
    defer unit4.deinit();

    const units = [_]spatial.SpatialUnit{ unit1, unit2, unit3, unit4 };

    var clusterer = spatial.SpatialClusterer.init(allocator, 2.0, 2);
    const labels = try clusterer.cluster(&units);

    var result = spatial.ClusterResult.init(allocator, labels);
    defer result.deinit();

    // Should have 1 cluster (first 3 units)
    try std.testing.expectEqual(@as(usize, 1), result.num_clusters);

    // Unit 4 should be noise
    try std.testing.expectEqual(@as(usize, 1), result.num_noise);

    // First 3 units should be in same cluster
    try std.testing.expectEqual(labels[0], labels[1]);
    try std.testing.expectEqual(labels[0], labels[2]);
    try std.testing.expectEqual(spatial.SpatialClusterer.NOISE, labels[3]);
}

test "Spatial interpolation - nearest neighbor" {
    const allocator = std.testing.allocator;

    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(allocator, "BH01", loc1, 0.0, 2.0, "CLAY", .soil);
    defer unit1.deinit();

    const loc2 = spatial.Point3D{ .x = 10, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(allocator, "BH02", loc2, 0.0, 2.0, "LIMESTONE", .rock);
    defer unit2.deinit();

    const units = [_]spatial.SpatialUnit{ unit1, unit2 };

    var interpolator = spatial.SpatialInterpolator.init(allocator, .nearest_neighbor);

    // Point closer to unit1
    const target1 = spatial.Point3D{ .x = 2, .y = 0, .z = 99 };
    const result1 = try interpolator.interpolateMaterialType(target1, &units, 1);
    try std.testing.expectEqual(types.MaterialType.soil, result1);

    // Point closer to unit2
    const target2 = spatial.Point3D{ .x = 9, .y = 0, .z = 99 };
    const result2 = try interpolator.interpolateMaterialType(target2, &units, 1);
    try std.testing.expectEqual(types.MaterialType.rock, result2);
}

test "Cluster statistics" {
    const allocator = std.testing.allocator;

    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(allocator, "BH01", loc1, 0.0, 2.0, "CLAY", .soil);
    defer unit1.deinit();

    const loc2 = spatial.Point3D{ .x = 1, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(allocator, "BH02", loc2, 0.0, 2.0, "CLAY", .soil);
    defer unit2.deinit();

    const loc3 = spatial.Point3D{ .x = 0, .y = 1, .z = 100 };
    const unit3 = try spatial.SpatialUnit.init(allocator, "BH03", loc3, 0.0, 2.0, "CLAY", .soil);
    defer unit3.deinit();

    const units = [_]spatial.SpatialUnit{ unit1, unit2, unit3 };

    var clusterer = spatial.SpatialClusterer.init(allocator, 2.0, 2);
    const labels = try clusterer.cluster(&units);

    var result = spatial.ClusterResult.init(allocator, labels);
    defer result.deinit();

    const sizes = try result.getClusterSizes();
    defer allocator.free(sizes);

    // All 3 should be in cluster 0
    try std.testing.expectEqual(@as(usize, 3), sizes[0]);
}
