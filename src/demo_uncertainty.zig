// Demo program showing uncertainty quantification capabilities
const std = @import("std");
const spatial = @import("parser/spatial.zig");
const uncertainty = @import("parser/uncertainty.zig");
const types = @import("parser/types.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== LITHOLOG UNCERTAINTY QUANTIFICATION DEMO ===\n\n", .{});

    // Create geological units
    const loc1 = spatial.Point3D{ .x = 0.0, .y = 0.0, .z = 100.0 };
    var unit1 = try spatial.SpatialUnit.init(
        allocator,
        "BH01",
        loc1,
        1.0,
        3.5,
        "Firm brown CLAY",
        .soil,
    );
    defer unit1.deinit();

    const loc2 = spatial.Point3D{ .x = 10.0, .y = 0.0, .z = 100.0 };
    var unit2 = try spatial.SpatialUnit.init(
        allocator,
        "BH02",
        loc2,
        0.9,
        3.2,
        "Firm brown CLAY",
        .soil,
    );
    defer unit2.deinit();

    const loc3 = spatial.Point3D{ .x = 0.0, .y = 10.0, .z = 100.0 };
    var unit3 = try spatial.SpatialUnit.init(
        allocator,
        "BH03",
        loc3,
        1.2,
        3.8,
        "Stiff brown CLAY",
        .soil,
    );
    defer unit3.deinit();

    const loc4 = spatial.Point3D{ .x = 50.0, .y = 50.0, .z = 100.0 };
    var unit4 = try spatial.SpatialUnit.init(
        allocator,
        "BH04",
        loc4,
        1.0,
        3.0,
        "Dense brown SAND",
        .soil,
    );
    defer unit4.deinit();

    std.debug.print("Created 4 geological units:\n", .{});
    std.debug.print("  BH01 (0,0):     CLAY, 1.0-3.5m depth\n", .{});
    std.debug.print("  BH02 (10,0):    CLAY, 0.9-3.2m depth\n", .{});
    std.debug.print("  BH03 (0,10):    CLAY, 1.2-3.8m depth\n", .{});
    std.debug.print("  BH04 (50,50):   SAND, 1.0-3.0m depth\n\n", .{});

    var quantifier = uncertainty.UncertaintyQuantifier.init(allocator);

    // Calculate boundary uncertainty for unit1 using nearby units
    const nearby = [_]spatial.SpatialUnit{ unit2, unit3 };

    std.debug.print("BOUNDARY UNCERTAINTY ANALYSIS\n", .{});
    std.debug.print("─────────────────────────────\n", .{});
    std.debug.print("Target: BH01 CLAY unit\n", .{});
    std.debug.print("Nearby boreholes: BH02 (10m away), BH03 (10m away)\n\n", .{});

    const boundary = try quantifier.calculateBoundaryUncertainty(&unit1, &nearby, 0.95);

    std.debug.print("Depth Top (95% CI):\n", .{});
    std.debug.print("  Mean:  {d:.2}m\n", .{boundary.depth_top_ci.mean});
    std.debug.print("  Range: {d:.2}m - {d:.2}m\n", .{
        boundary.depth_top_ci.lower_bound,
        boundary.depth_top_ci.upper_bound,
    });
    std.debug.print("  Width: {d:.2}m\n\n", .{boundary.depth_top_ci.width()});

    std.debug.print("Depth Bottom (95% CI):\n", .{});
    std.debug.print("  Mean:  {d:.2}m\n", .{boundary.depth_bottom_ci.mean});
    std.debug.print("  Range: {d:.2}m - {d:.2}m\n", .{
        boundary.depth_bottom_ci.lower_bound,
        boundary.depth_bottom_ci.upper_bound,
    });
    std.debug.print("  Width: {d:.2}m\n\n", .{boundary.depth_bottom_ci.width()});

    std.debug.print("Thickness (95% CI):\n", .{});
    std.debug.print("  Mean:  {d:.2}m\n", .{boundary.thickness_ci.mean});
    std.debug.print("  Range: {d:.2}m - {d:.2}m\n", .{
        boundary.thickness_ci.lower_bound,
        boundary.thickness_ci.upper_bound,
    });
    std.debug.print("  Width: {d:.2}m\n\n", .{boundary.thickness_ci.width()});

    std.debug.print("Boundary Quality Score: {d:.2} ({s})\n", .{
        boundary.boundary_quality,
        if (boundary.isReliable(0.7)) "Reliable" else "Needs more data",
    });

    // Interpolation quality analysis
    const all_units = [_]spatial.SpatialUnit{ unit1, unit2, unit3, unit4 };

    std.debug.print("\n\nINTERPOLATION QUALITY ANALYSIS\n", .{});
    std.debug.print("────────────────────────────────\n\n", .{});

    // Point near data
    const target1 = spatial.Point3D{ .x = 5.0, .y = 0.0, .z = 99.0 };
    const quality1 = try quantifier.calculateInterpolationQuality(target1, &all_units, 3);

    std.debug.print("Target Point 1: (5.0, 0.0, 99.0) - Between BH01 and BH02\n", .{});
    std.debug.print("  Nearest Distance:  {d:.2}m\n", .{quality1.nearest_distance});
    std.debug.print("  Neighbors Used:    {}\n", .{quality1.num_neighbors});
    std.debug.print("  Prediction Confidence: {d:.2}\n", .{quality1.prediction_confidence});
    std.debug.print("  Variance:          {d:.3}\n", .{quality1.variance});
    std.debug.print("  Quality Grade:     {s}\n", .{quality1.getQualityGrade().toString()});
    std.debug.print("  High Quality?      {s}\n\n", .{if (quality1.isHighQuality()) "Yes" else "No"});

    // Point far from data
    const target2 = spatial.Point3D{ .x = 100.0, .y = 100.0, .z = 99.0 };
    const quality2 = try quantifier.calculateInterpolationQuality(target2, &all_units, 3);

    std.debug.print("Target Point 2: (100.0, 100.0, 99.0) - Far from all boreholes\n", .{});
    std.debug.print("  Nearest Distance:  {d:.2}m\n", .{quality2.nearest_distance});
    std.debug.print("  Neighbors Used:    {}\n", .{quality2.num_neighbors});
    std.debug.print("  Prediction Confidence: {d:.2}\n", .{quality2.prediction_confidence});
    std.debug.print("  Variance:          {d:.3}\n", .{quality2.variance});
    std.debug.print("  Quality Grade:     {s}\n", .{quality2.getQualityGrade().toString()});
    std.debug.print("  High Quality?      {s}\n\n", .{if (quality2.isHighQuality()) "Yes" else "No"});

    // Cross-validation
    std.debug.print("\nCROSS-VALIDATION ANALYSIS\n", .{});
    std.debug.print("───────────────────────────\n", .{});
    std.debug.print("Method: Leave-one-out cross-validation\n", .{});
    std.debug.print("Interpolation: IDW with k=3 neighbors\n\n", .{});

    const cv_result = try quantifier.crossValidate(&all_units, 3);

    std.debug.print("Results:\n", .{});
    std.debug.print("  Total Predictions:   {}\n", .{cv_result.total_predictions});
    std.debug.print("  Correct Predictions: {}\n", .{cv_result.correct_predictions});
    std.debug.print("  Accuracy:            {d:.1}%\n", .{cv_result.accuracy * 100.0});
    std.debug.print("  Reliable?            {s}\n", .{if (cv_result.isReliable()) "Yes (≥80%)" else "No (<80%)"});

    std.debug.print("\n=== KEY INSIGHTS ===\n", .{});
    std.debug.print("• Confidence intervals widen with fewer nearby boreholes\n", .{});
    std.debug.print("• Interpolation quality degrades with distance from data\n", .{});
    std.debug.print("• Cross-validation accuracy indicates model reliability\n", .{});
    std.debug.print("• Boundary quality scores guide decision-making confidence\n\n", .{});

    std.debug.print("=== DEMO COMPLETE ===\n\n", .{});
}
