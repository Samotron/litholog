const std = @import("std");
const spatial = @import("parser/spatial.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n=== CLUSTERING QUALITY METRICS DEMO ===\n\n", .{});

    // Create sample boreholes with clear spatial clusters
    var units = std.ArrayList(spatial.SpatialUnit).init(allocator);
    defer {
        for (units.items) |*unit| {
            unit.deinit();
        }
        units.deinit();
    }

    const types = @import("parser/types.zig");

    // Cluster 1: Northern group (X: 0-10, Y: 0-10)
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-1",
        .{ .x = 5, .y = 5, .z = 0 },
        0,
        2,
        "Sandy CLAY",
        types.MaterialType.soil,
    ));
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-2",
        .{ .x = 7, .y = 6, .z = 0 },
        0,
        2.5,
        "Sandy CLAY",
        types.MaterialType.soil,
    ));
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-3",
        .{ .x = 6, .y = 8, .z = 0 },
        0,
        2.2,
        "Sandy CLAY",
        types.MaterialType.soil,
    ));

    // Cluster 2: Southern group (X: 50-60, Y: 50-60)
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-4",
        .{ .x = 55, .y = 55, .z = 0 },
        0,
        3,
        "SAND",
        types.MaterialType.soil,
    ));
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-5",
        .{ .x = 57, .y = 56, .z = 0 },
        0,
        2.8,
        "SAND",
        types.MaterialType.soil,
    ));
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-6",
        .{ .x = 54, .y = 58, .z = 0 },
        0,
        3.2,
        "SAND",
        types.MaterialType.soil,
    ));

    // Cluster 3: Eastern group (X: 100-110, Y: 25-35)
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-7",
        .{ .x = 105, .y = 30, .z = 0 },
        0,
        2.5,
        "Gravelly SAND",
        types.MaterialType.soil,
    ));
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-8",
        .{ .x = 107, .y = 32, .z = 0 },
        0,
        2.7,
        "Gravelly SAND",
        types.MaterialType.soil,
    ));
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-9",
        .{ .x = 104, .y = 28, .z = 0 },
        0,
        2.6,
        "Gravelly SAND",
        types.MaterialType.soil,
    ));

    // Outlier (noise point)
    try units.append(try spatial.SpatialUnit.init(
        allocator,
        "BH-10",
        .{ .x = 200, .y = 200, .z = 0 },
        0,
        2.0,
        "SILT",
        types.MaterialType.soil,
    ));

    try stdout.print("Sample Data:\n", .{});
    try stdout.print("- 10 boreholes in 3 distinct spatial clusters + 1 outlier\n", .{});
    try stdout.print("- Cluster 1 (North): BH-1, BH-2, BH-3\n", .{});
    try stdout.print("- Cluster 2 (South): BH-4, BH-5, BH-6\n", .{});
    try stdout.print("- Cluster 3 (East):  BH-7, BH-8, BH-9\n", .{});
    try stdout.print("- Outlier:           BH-10\n\n", .{});

    // Perform DBSCAN clustering
    const epsilon: f64 = 15.0; // Maximum distance for neighbors
    const min_points: usize = 2; // Minimum points to form cluster

    try stdout.print("DBSCAN Parameters:\n", .{});
    try stdout.print("- Epsilon (max distance): {d:.1}\n", .{epsilon});
    try stdout.print("- Min points: {d}\n\n", .{min_points});

    var clusterer = spatial.SpatialClusterer.init(allocator, epsilon, min_points);
    const labels = try clusterer.cluster(units.items);
    defer allocator.free(labels);

    const cluster_result = spatial.ClusterResult.init(allocator, labels);

    try stdout.print("Clustering Results:\n", .{});
    try stdout.print("- Number of clusters: {d}\n", .{cluster_result.num_clusters});
    try stdout.print("- Noise points: {d}\n\n", .{cluster_result.num_noise});

    // Display cluster assignments
    try stdout.print("Cluster Assignments:\n", .{});
    for (units.items, 0..) |unit, i| {
        const label = labels[i];
        if (label < 0) {
            try stdout.print("  {s}: NOISE\n", .{unit.borehole_id});
        } else {
            try stdout.print("  {s}: Cluster {d}\n", .{ unit.borehole_id, label });
        }
    }
    try stdout.print("\n", .{});

    // Calculate clustering quality metrics
    const metrics = try spatial.calculateClusteringMetrics(
        allocator,
        units.items,
        labels,
    );

    try stdout.print("=== CLUSTERING QUALITY METRICS ===\n\n", .{});

    // 1. Silhouette Score
    try stdout.print("1. Silhouette Score: {d:.4}\n", .{metrics.silhouette_score});
    try stdout.print("   Range: [-1, 1], where 1 is best\n", .{});
    try stdout.print("   Interpretation:\n", .{});
    if (metrics.silhouette_score > 0.7) {
        try stdout.print("   ✓ EXCELLENT: Strong, well-separated clusters\n", .{});
    } else if (metrics.silhouette_score > 0.5) {
        try stdout.print("   ✓ GOOD: Reasonable cluster structure\n", .{});
    } else if (metrics.silhouette_score > 0.25) {
        try stdout.print("   ~ FAIR: Weak cluster structure, some overlap\n", .{});
    } else {
        try stdout.print("   ✗ POOR: No meaningful cluster structure\n", .{});
    }
    try stdout.print("   Meaning: Measures how similar points are to their own cluster\n", .{});
    try stdout.print("            compared to other clusters\n\n", .{});

    // 2. Davies-Bouldin Index
    try stdout.print("2. Davies-Bouldin Index: {d:.4}\n", .{metrics.davies_bouldin_index});
    try stdout.print("   Range: [0, ∞), where lower is better\n", .{});
    try stdout.print("   Interpretation:\n", .{});
    if (metrics.davies_bouldin_index < 0.5) {
        try stdout.print("   ✓ EXCELLENT: Very well-separated clusters\n", .{});
    } else if (metrics.davies_bouldin_index < 1.0) {
        try stdout.print("   ✓ GOOD: Well-separated clusters\n", .{});
    } else if (metrics.davies_bouldin_index < 2.0) {
        try stdout.print("   ~ FAIR: Some cluster overlap\n", .{});
    } else {
        try stdout.print("   ✗ POOR: Significant cluster overlap\n", .{});
    }
    try stdout.print("   Meaning: Measures the average similarity between each cluster\n", .{});
    try stdout.print("            and its most similar cluster\n\n", .{});

    // 3. Calinski-Harabasz Index
    try stdout.print("3. Calinski-Harabasz Index: {d:.2}\n", .{metrics.calinski_harabasz_index});
    try stdout.print("   Range: [0, ∞), where higher is better\n", .{});
    try stdout.print("   Interpretation:\n", .{});
    if (metrics.calinski_harabasz_index > 100) {
        try stdout.print("   ✓ EXCELLENT: Very compact and well-separated clusters\n", .{});
    } else if (metrics.calinski_harabasz_index > 50) {
        try stdout.print("   ✓ GOOD: Compact and reasonably separated clusters\n", .{});
    } else if (metrics.calinski_harabasz_index > 20) {
        try stdout.print("   ~ FAIR: Moderate cluster quality\n", .{});
    } else {
        try stdout.print("   ✗ POOR: Weak cluster structure\n", .{});
    }
    try stdout.print("   Meaning: Ratio of between-cluster to within-cluster dispersion\n\n", .{});

    // Overall quality grade
    try stdout.print("=== OVERALL QUALITY: ", .{});
    switch (metrics.getQualityGrade()) {
        .excellent => try stdout.print("EXCELLENT ✓\n", .{}),
        .good => try stdout.print("GOOD ✓\n", .{}),
        .fair => try stdout.print("FAIR ~\n", .{}),
        .poor => try stdout.print("POOR ✗\n", .{}),
    }

    try stdout.print("\n=== RECOMMENDATIONS ===\n\n", .{});

    if (metrics.silhouette_score < 0.5) {
        try stdout.print("- Consider adjusting epsilon or min_points parameters\n", .{});
        try stdout.print("- Try different clustering algorithms (k-means, hierarchical)\n", .{});
    }

    if (metrics.davies_bouldin_index > 1.5) {
        try stdout.print("- Clusters may be overlapping - consider larger epsilon\n", .{});
    }

    if (metrics.calinski_harabasz_index < 30) {
        try stdout.print("- Clusters may not be well-separated\n", .{});
        try stdout.print("- Consider whether clustering is appropriate for this data\n", .{});
    }

    if (metrics.num_noise > units.items.len / 4) {
        try stdout.print("- High proportion of noise points ({d}/{d})\n", .{ metrics.num_noise, units.items.len });
        try stdout.print("- Consider reducing min_points or increasing epsilon\n", .{});
    }

    if (metrics.getQualityGrade() == .excellent or metrics.getQualityGrade() == .good) {
        try stdout.print("✓ Clustering quality is good - results are reliable!\n", .{});
    }

    try stdout.print("\n=== DEMO COMPLETE ===\n", .{});
}
