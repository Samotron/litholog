const std = @import("std");
const uncertainty = @import("parser/uncertainty.zig");
const spatial = @import("parser/spatial.zig");
const types = @import("parser/types.zig");

test "Confidence interval basic operations" {
    const ci = uncertainty.ConfidenceInterval{
        .lower_bound = 1.0,
        .upper_bound = 3.0,
        .mean = 2.0,
        .confidence_level = 0.95,
    };

    try std.testing.expect(ci.contains(2.0));
    try std.testing.expect(ci.contains(1.5));
    try std.testing.expect(!ci.contains(0.5));
    try std.testing.expect(!ci.contains(3.5));
    try std.testing.expectApproxEqAbs(2.0, ci.width(), 0.001);
}

test "Boundary uncertainty with no nearby data" {
    const allocator = std.testing.allocator;

    const loc = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit = try spatial.SpatialUnit.init(
        allocator,
        "BH01",
        loc,
        1.0,
        3.0,
        "CLAY",
        .soil,
    );
    defer unit.deinit();

    var quantifier = uncertainty.UncertaintyQuantifier.init(allocator);
    const empty_nearby: []const spatial.SpatialUnit = &[_]spatial.SpatialUnit{};

    const result = try quantifier.calculateBoundaryUncertainty(&unit, empty_nearby, 0.95);

    // With no nearby data, quality should be low
    try std.testing.expect(result.boundary_quality < 0.5);

    // CI should be centered around actual depth
    try std.testing.expectApproxEqAbs(1.0, result.depth_top_ci.mean, 0.1);
    try std.testing.expectApproxEqAbs(3.0, result.depth_bottom_ci.mean, 0.1);
}

test "Boundary uncertainty with nearby data" {
    const allocator = std.testing.allocator;

    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(
        allocator,
        "BH01",
        loc1,
        1.0,
        3.0,
        "CLAY",
        .soil,
    );
    defer unit1.deinit();

    // Create nearby units with similar depths
    const loc2 = spatial.Point3D{ .x = 5, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(
        allocator,
        "BH02",
        loc2,
        0.9,
        2.9,
        "CLAY",
        .soil,
    );
    defer unit2.deinit();

    const loc3 = spatial.Point3D{ .x = 0, .y = 5, .z = 100 };
    const unit3 = try spatial.SpatialUnit.init(
        allocator,
        "BH03",
        loc3,
        1.1,
        3.1,
        "CLAY",
        .soil,
    );
    defer unit3.deinit();

    const nearby = [_]spatial.SpatialUnit{ unit2, unit3 };

    var quantifier = uncertainty.UncertaintyQuantifier.init(allocator);
    const result = try quantifier.calculateBoundaryUncertainty(&unit1, &nearby, 0.95);

    // With nearby data, quality should be higher
    try std.testing.expect(result.boundary_quality > 0.5);

    // CI bounds should be reasonable
    try std.testing.expect(result.depth_top_ci.lower_bound < result.depth_top_ci.upper_bound);
    try std.testing.expect(result.depth_bottom_ci.lower_bound < result.depth_bottom_ci.upper_bound);

    // Mean should be close to actual depths
    try std.testing.expectApproxEqAbs(1.0, result.depth_top_ci.mean, 0.2);
}

test "Interpolation quality metrics" {
    const allocator = std.testing.allocator;

    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(allocator, "BH01", loc1, 0.0, 2.0, "CLAY", .soil);
    defer unit1.deinit();

    const loc2 = spatial.Point3D{ .x = 10, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(allocator, "BH02", loc2, 0.0, 2.0, "CLAY", .soil);
    defer unit2.deinit();

    const loc3 = spatial.Point3D{ .x = 20, .y = 0, .z = 100 };
    const unit3 = try spatial.SpatialUnit.init(allocator, "BH03", loc3, 0.0, 2.0, "SAND", .rock);
    defer unit3.deinit();

    const units = [_]spatial.SpatialUnit{ unit1, unit2, unit3 };

    var quantifier = uncertainty.UncertaintyQuantifier.init(allocator);

    // Test point close to unit1
    const target1 = spatial.Point3D{ .x = 2, .y = 0, .z = 99 };
    const quality1 = try quantifier.calculateInterpolationQuality(target1, &units, 3);

    try std.testing.expect(quality1.nearest_distance < 5.0);
    try std.testing.expect(quality1.num_neighbors == 3);
    try std.testing.expect(quality1.prediction_confidence > 0.5);

    // Test point far from all units
    const target2 = spatial.Point3D{ .x = 100, .y = 100, .z = 99 };
    const quality2 = try quantifier.calculateInterpolationQuality(target2, &units, 3);

    try std.testing.expect(quality2.nearest_distance > 50.0);
    try std.testing.expect(quality2.prediction_confidence < 0.5);
}

test "Interpolation quality grades" {
    const excellent = uncertainty.InterpolationQuality{
        .prediction_confidence = 0.95,
        .nearest_distance = 5.0,
        .num_neighbors = 5,
        .variance = 0.05,
    };
    try std.testing.expectEqual(
        uncertainty.InterpolationQuality.QualityGrade.excellent,
        excellent.getQualityGrade(),
    );

    const good = uncertainty.InterpolationQuality{
        .prediction_confidence = 0.75,
        .nearest_distance = 30.0,
        .num_neighbors = 3,
        .variance = 0.15,
    };
    try std.testing.expectEqual(
        uncertainty.InterpolationQuality.QualityGrade.good,
        good.getQualityGrade(),
    );

    const poor = uncertainty.InterpolationQuality{
        .prediction_confidence = 0.3,
        .nearest_distance = 80.0,
        .num_neighbors = 2,
        .variance = 0.4,
    };
    try std.testing.expectEqual(
        uncertainty.InterpolationQuality.QualityGrade.poor,
        poor.getQualityGrade(),
    );
}

test "Cross-validation" {
    const allocator = std.testing.allocator;

    // Create units in a pattern
    const loc1 = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit1 = try spatial.SpatialUnit.init(allocator, "BH01", loc1, 0.0, 2.0, "CLAY", .soil);
    defer unit1.deinit();

    const loc2 = spatial.Point3D{ .x = 5, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(allocator, "BH02", loc2, 0.0, 2.0, "CLAY", .soil);
    defer unit2.deinit();

    const loc3 = spatial.Point3D{ .x = 10, .y = 0, .z = 100 };
    const unit3 = try spatial.SpatialUnit.init(allocator, "BH03", loc3, 0.0, 2.0, "CLAY", .soil);
    defer unit3.deinit();

    const units = [_]spatial.SpatialUnit{ unit1, unit2, unit3 };

    var quantifier = uncertainty.UncertaintyQuantifier.init(allocator);
    const cv_result = try quantifier.crossValidate(&units, 2);

    // All units are same material type, so accuracy should be high
    try std.testing.expect(cv_result.accuracy >= 0.66); // At least 2/3 correct
    try std.testing.expectEqual(@as(usize, 3), cv_result.total_predictions);
}

test "Boundary quality factors" {
    const allocator = std.testing.allocator;

    const loc = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const unit = try spatial.SpatialUnit.init(allocator, "BH01", loc, 1.0, 3.0, "CLAY", .soil);
    defer unit.deinit();

    // Test with varying numbers of neighbors and distances
    var quantifier = uncertainty.UncertaintyQuantifier.init(allocator);

    // Many close neighbors = high quality
    const loc2 = spatial.Point3D{ .x = 2, .y = 0, .z = 100 };
    const unit2 = try spatial.SpatialUnit.init(allocator, "BH02", loc2, 1.0, 3.0, "CLAY", .soil);
    defer unit2.deinit();

    const loc3 = spatial.Point3D{ .x = 0, .y = 2, .z = 100 };
    const unit3 = try spatial.SpatialUnit.init(allocator, "BH03", loc3, 1.0, 3.0, "CLAY", .soil);
    defer unit3.deinit();

    const loc4 = spatial.Point3D{ .x = 2, .y = 2, .z = 100 };
    const unit4 = try spatial.SpatialUnit.init(allocator, "BH04", loc4, 1.0, 3.0, "CLAY", .soil);
    defer unit4.deinit();

    const nearby = [_]spatial.SpatialUnit{ unit2, unit3, unit4 };
    const result = try quantifier.calculateBoundaryUncertainty(&unit, &nearby, 0.95);

    try std.testing.expect(result.boundary_quality > 0.6);
    try std.testing.expect(result.isReliable(0.5));
}

test "Empty dataset handling" {
    const allocator = std.testing.allocator;

    var quantifier = uncertainty.UncertaintyQuantifier.init(allocator);

    const target = spatial.Point3D{ .x = 0, .y = 0, .z = 100 };
    const empty: []const spatial.SpatialUnit = &[_]spatial.SpatialUnit{};

    const quality = try quantifier.calculateInterpolationQuality(target, empty, 3);

    try std.testing.expectEqual(@as(usize, 0), quality.num_neighbors);
    try std.testing.expectEqual(@as(f64, 0.0), quality.prediction_confidence);
    try std.testing.expect(!quality.isHighQuality());
}
