const std = @import("std");
const types = @import("types.zig");

/// 3D coordinate point
pub const Point3D = struct {
    x: f64,
    y: f64,
    z: f64,

    /// Calculate Euclidean distance between two 3D points
    pub fn distance(self: Point3D, other: Point3D) f64 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    /// Calculate 2D horizontal distance (ignoring Z)
    pub fn horizontalDistance(self: Point3D, other: Point3D) f64 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }

    /// Calculate vertical distance (Z only)
    pub fn verticalDistance(self: Point3D, other: Point3D) f64 {
        return @abs(self.z - other.z);
    }

    /// Calculate angle to another point in XY plane (radians)
    pub fn angleToPoint(self: Point3D, other: Point3D) f64 {
        const dx = other.x - self.x;
        const dy = other.y - self.y;
        return std.math.atan2(dy, dx);
    }
};

/// Borehole location with coordinates
pub const BoreholeLocation = struct {
    id: []const u8,
    location: Point3D,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, x: f64, y: f64, z: f64) !BoreholeLocation {
        return BoreholeLocation{
            .id = try allocator.dupe(u8, id),
            .location = Point3D{ .x = x, .y = y, .z = z },
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BoreholeLocation) void {
        self.allocator.free(self.id);
    }
};

/// Geological unit with spatial information
pub const SpatialUnit = struct {
    borehole_id: []const u8,
    location: Point3D,
    depth_top: f64,
    depth_bottom: f64,
    description: []const u8,
    material_type: types.MaterialType,

    // Optional fields for more detailed spatial analysis
    thickness: f64,
    mid_depth: f64,

    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        borehole_id: []const u8,
        location: Point3D,
        depth_top: f64,
        depth_bottom: f64,
        description: []const u8,
        material_type: types.MaterialType,
    ) !SpatialUnit {
        const thickness = depth_bottom - depth_top;
        const mid_depth = (depth_top + depth_bottom) / 2.0;

        return SpatialUnit{
            .borehole_id = try allocator.dupe(u8, borehole_id),
            .location = location,
            .depth_top = depth_top,
            .depth_bottom = depth_bottom,
            .description = try allocator.dupe(u8, description),
            .material_type = material_type,
            .thickness = thickness,
            .mid_depth = mid_depth,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SpatialUnit) void {
        self.allocator.free(self.borehole_id);
        self.allocator.free(self.description);
    }

    /// Get 3D coordinate at unit midpoint (considering depth)
    pub fn getMidPoint(self: SpatialUnit) Point3D {
        return Point3D{
            .x = self.location.x,
            .y = self.location.y,
            .z = self.location.z - self.mid_depth, // Z decreases with depth
        };
    }

    /// Calculate 3D distance between unit midpoints
    pub fn distanceTo(self: SpatialUnit, other: SpatialUnit) f64 {
        return self.getMidPoint().distance(other.getMidPoint());
    }

    /// Calculate horizontal distance between boreholes
    pub fn horizontalDistanceTo(self: SpatialUnit, other: SpatialUnit) f64 {
        return self.location.horizontalDistance(other.location);
    }

    /// Calculate depth difference between unit midpoints
    pub fn depthDifferenceTo(self: SpatialUnit, other: SpatialUnit) f64 {
        return @abs(self.mid_depth - other.mid_depth);
    }
};

/// Spatial analyzer for geological units
pub const SpatialAnalyzer = struct {
    allocator: std.mem.Allocator,
    boreholes: std.StringHashMap(BoreholeLocation),
    units: std.ArrayList(SpatialUnit),

    pub fn init(allocator: std.mem.Allocator) SpatialAnalyzer {
        return SpatialAnalyzer{
            .allocator = allocator,
            .boreholes = std.StringHashMap(BoreholeLocation).init(allocator),
            .units = std.ArrayList(SpatialUnit).init(allocator),
        };
    }

    pub fn deinit(self: *SpatialAnalyzer) void {
        var iter = self.boreholes.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var loc = entry.value_ptr.*;
            loc.deinit();
        }
        self.boreholes.deinit();

        for (self.units.items) |*unit| {
            unit.deinit();
        }
        self.units.deinit();
    }

    /// Add a borehole location
    pub fn addBorehole(self: *SpatialAnalyzer, id: []const u8, x: f64, y: f64, z: f64) !void {
        const location = try BoreholeLocation.init(self.allocator, id, x, y, z);
        try self.boreholes.put(try self.allocator.dupe(u8, id), location);
    }

    /// Add a geological unit
    pub fn addUnit(self: *SpatialAnalyzer, unit: SpatialUnit) !void {
        try self.units.append(unit);
    }

    /// Find nearest neighbors to a unit within a given radius
    pub fn findNearestNeighbors(
        self: *SpatialAnalyzer,
        unit: *const SpatialUnit,
        max_distance: f64,
        max_neighbors: usize,
    ) ![]SpatialUnit {
        var neighbors = std.ArrayList(struct { unit: SpatialUnit, distance: f64 }).init(self.allocator);
        defer neighbors.deinit();

        for (self.units.items) |other_unit| {
            // Skip same borehole
            if (std.mem.eql(u8, unit.borehole_id, other_unit.borehole_id)) {
                continue;
            }

            const dist = unit.distanceTo(other_unit);
            if (dist <= max_distance) {
                try neighbors.append(.{ .unit = other_unit, .distance = dist });
            }
        }

        // Sort by distance
        std.sort.pdq(
            @TypeOf(neighbors.items[0]),
            neighbors.items,
            {},
            struct {
                fn lessThan(_: void, a: @TypeOf(neighbors.items[0]), b: @TypeOf(neighbors.items[0])) bool {
                    return a.distance < b.distance;
                }
            }.lessThan,
        );

        // Return up to max_neighbors
        const count = @min(neighbors.items.len, max_neighbors);
        var result = try self.allocator.alloc(SpatialUnit, count);
        for (0..count) |i| {
            result[i] = neighbors.items[i].unit;
        }

        return result;
    }

    /// Calculate spatial correlation matrix between units
    pub fn calculateCorrelationMatrix(self: *SpatialAnalyzer) ![][]f64 {
        const n = self.units.items.len;
        var matrix = try self.allocator.alloc([]f64, n);

        for (0..n) |i| {
            matrix[i] = try self.allocator.alloc(f64, n);
            for (0..n) |j| {
                if (i == j) {
                    matrix[i][j] = 0.0;
                } else {
                    matrix[i][j] = self.units.items[i].distanceTo(self.units.items[j]);
                }
            }
        }

        return matrix;
    }

    /// Free correlation matrix
    pub fn freeCorrelationMatrix(self: *SpatialAnalyzer, matrix: [][]f64) void {
        for (matrix) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(matrix);
    }

    /// Find units within a spatial region (bounding box)
    pub fn findUnitsInRegion(
        self: *SpatialAnalyzer,
        min_x: f64,
        max_x: f64,
        min_y: f64,
        max_y: f64,
        min_depth: f64,
        max_depth: f64,
    ) ![]SpatialUnit {
        var result = std.ArrayList(SpatialUnit).init(self.allocator);
        defer result.deinit();

        for (self.units.items) |unit| {
            const in_x = unit.location.x >= min_x and unit.location.x <= max_x;
            const in_y = unit.location.y >= min_y and unit.location.y <= max_y;
            const in_depth = unit.mid_depth >= min_depth and unit.mid_depth <= max_depth;

            if (in_x and in_y and in_depth) {
                try result.append(unit);
            }
        }

        return result.toOwnedSlice();
    }

    /// Calculate centroid of a group of units
    pub fn calculateCentroid(units: []const SpatialUnit) Point3D {
        if (units.len == 0) return Point3D{ .x = 0, .y = 0, .z = 0 };

        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        var sum_z: f64 = 0;

        for (units) |unit| {
            const mid = unit.getMidPoint();
            sum_x += mid.x;
            sum_y += mid.y;
            sum_z += mid.z;
        }

        const n: f64 = @floatFromInt(units.len);
        return Point3D{
            .x = sum_x / n,
            .y = sum_y / n,
            .z = sum_z / n,
        };
    }

    /// Calculate spatial variance of units
    pub fn calculateSpatialVariance(units: []const SpatialUnit) f64 {
        if (units.len < 2) return 0.0;

        const centroid = calculateCentroid(units);
        var sum_sq_dist: f64 = 0;

        for (units) |unit| {
            const dist = unit.getMidPoint().distance(centroid);
            sum_sq_dist += dist * dist;
        }

        const n: f64 = @floatFromInt(units.len);
        return sum_sq_dist / n;
    }

    /// Generate spatial interpolation weights (Inverse Distance Weighting)
    pub fn calculateIDWWeights(
        self: *SpatialAnalyzer,
        target: Point3D,
        units: []const SpatialUnit,
        power: f64,
    ) ![]f64 {
        var weights = try self.allocator.alloc(f64, units.len);
        var sum_weights: f64 = 0;

        for (units, 0..) |unit, i| {
            const dist = target.distance(unit.getMidPoint());
            if (dist < 1e-10) {
                // Target is very close to this unit - give it all weight
                @memset(weights, 0);
                weights[i] = 1.0;
                return weights;
            }
            weights[i] = 1.0 / std.math.pow(f64, dist, power);
            sum_weights += weights[i];
        }

        // Normalize weights
        for (weights) |*w| {
            w.* /= sum_weights;
        }

        return weights;
    }
};

/// Spatial statistics result
pub const SpatialStats = struct {
    centroid: Point3D,
    variance: f64,
    std_deviation: f64,
    min_distance: f64,
    max_distance: f64,
    mean_distance: f64,

    pub fn calculate(units: []const SpatialUnit) SpatialStats {
        const centroid = SpatialAnalyzer.calculateCentroid(units);
        const variance = SpatialAnalyzer.calculateSpatialVariance(units);

        var min_dist: f64 = std.math.inf(f64);
        var max_dist: f64 = 0;
        var sum_dist: f64 = 0;
        var count: usize = 0;

        // Calculate pairwise distances
        for (units, 0..) |unit1, i| {
            for (units[i + 1 ..]) |unit2| {
                const dist = unit1.distanceTo(unit2);
                min_dist = @min(min_dist, dist);
                max_dist = @max(max_dist, dist);
                sum_dist += dist;
                count += 1;
            }
        }

        const mean_dist = if (count > 0) sum_dist / @as(f64, @floatFromInt(count)) else 0;

        return SpatialStats{
            .centroid = centroid,
            .variance = variance,
            .std_deviation = @sqrt(variance),
            .min_distance = if (min_dist == std.math.inf(f64)) 0 else min_dist,
            .max_distance = max_dist,
            .mean_distance = mean_dist,
        };
    }
};

/// Spatial clustering using DBSCAN adapted for geological units
pub const SpatialClusterer = struct {
    allocator: std.mem.Allocator,
    epsilon: f64, // Maximum distance for neighborhood
    min_points: usize, // Minimum points to form a cluster

    const UNCLASSIFIED: i32 = -1;
    const NOISE: i32 = -2;

    pub fn init(allocator: std.mem.Allocator, epsilon: f64, min_points: usize) SpatialClusterer {
        return SpatialClusterer{
            .allocator = allocator,
            .epsilon = epsilon,
            .min_points = min_points,
        };
    }

    /// Cluster units using DBSCAN algorithm
    pub fn cluster(self: *SpatialClusterer, units: []const SpatialUnit) ![]i32 {
        var labels = try self.allocator.alloc(i32, units.len);
        @memset(labels, UNCLASSIFIED);

        var cluster_id: i32 = 0;

        for (units, 0..) |_, i| {
            if (labels[i] != UNCLASSIFIED) continue;

            // Find neighbors
            var neighbors = try self.findNeighbors(units, i);
            defer neighbors.deinit();

            if (neighbors.items.len < self.min_points) {
                labels[i] = NOISE;
                continue;
            }

            // Start new cluster
            labels[i] = cluster_id;

            // Expand cluster
            var seed_idx: usize = 0;
            while (seed_idx < neighbors.items.len) {
                const neighbor_idx = neighbors.items[seed_idx];

                if (labels[neighbor_idx] == NOISE) {
                    labels[neighbor_idx] = cluster_id;
                }

                if (labels[neighbor_idx] != UNCLASSIFIED) {
                    seed_idx += 1;
                    continue;
                }

                labels[neighbor_idx] = cluster_id;

                // Find neighbors of neighbor
                var neighbor_neighbors = try self.findNeighbors(units, neighbor_idx);
                defer neighbor_neighbors.deinit();

                if (neighbor_neighbors.items.len >= self.min_points) {
                    // Add new neighbors to seed set
                    for (neighbor_neighbors.items) |nn| {
                        var found = false;
                        for (neighbors.items) |existing| {
                            if (existing == nn) {
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            try neighbors.append(nn);
                        }
                    }
                }

                seed_idx += 1;
            }

            cluster_id += 1;
        }

        return labels;
    }

    fn findNeighbors(self: *SpatialClusterer, units: []const SpatialUnit, idx: usize) !std.ArrayList(usize) {
        var neighbors = std.ArrayList(usize).init(self.allocator);

        for (units, 0..) |unit, i| {
            if (i == idx) continue;

            const dist = units[idx].distanceTo(unit);
            if (dist <= self.epsilon) {
                try neighbors.append(i);
            }
        }

        return neighbors;
    }
};

/// Clustering result with statistics
pub const ClusterResult = struct {
    labels: []i32,
    num_clusters: usize,
    num_noise: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, labels: []i32) ClusterResult {
        var max_label: i32 = -1;
        var noise_count: usize = 0;

        for (labels) |label| {
            if (label == SpatialClusterer.NOISE) {
                noise_count += 1;
            } else if (label > max_label) {
                max_label = label;
            }
        }

        const num_clusters = if (max_label >= 0) @as(usize, @intCast(max_label + 1)) else 0;

        return ClusterResult{
            .labels = labels,
            .num_clusters = num_clusters,
            .num_noise = noise_count,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ClusterResult) void {
        self.allocator.free(self.labels);
    }

    /// Get indices of units in a specific cluster
    pub fn getClusterIndices(self: ClusterResult, cluster_id: i32) ![]usize {
        var indices = std.ArrayList(usize).init(self.allocator);
        defer indices.deinit();

        for (self.labels, 0..) |label, i| {
            if (label == cluster_id) {
                try indices.append(i);
            }
        }

        return indices.toOwnedSlice();
    }

    /// Get cluster sizes
    pub fn getClusterSizes(self: ClusterResult) ![]usize {
        var sizes = try self.allocator.alloc(usize, self.num_clusters);
        @memset(sizes, 0);

        for (self.labels) |label| {
            if (label >= 0) {
                const idx: usize = @intCast(label);
                sizes[idx] += 1;
            }
        }

        return sizes;
    }
};

/// Clustering quality metrics
pub const ClusteringMetrics = struct {
    silhouette_score: f64, // Range: [-1, 1], higher is better
    davies_bouldin_index: f64, // Lower is better (0 is best)
    calinski_harabasz_index: f64, // Higher is better
    num_clusters: usize,
    num_noise: usize,

    /// Overall quality assessment
    pub fn getQualityGrade(self: ClusteringMetrics) QualityGrade {
        // Good clustering: high silhouette, low DB, high CH
        const silhouette_good = self.silhouette_score > 0.5;
        const db_good = self.davies_bouldin_index < 1.0;
        const ch_good = self.calinski_harabasz_index > 100.0;

        const good_metrics = @as(usize, @intFromBool(silhouette_good)) +
            @as(usize, @intFromBool(db_good)) +
            @as(usize, @intFromBool(ch_good));

        return switch (good_metrics) {
            3 => .excellent,
            2 => .good,
            1 => .fair,
            else => .poor,
        };
    }

    pub const QualityGrade = enum {
        excellent,
        good,
        fair,
        poor,

        pub fn toString(self: QualityGrade) []const u8 {
            return switch (self) {
                .excellent => "Excellent",
                .good => "Good",
                .fair => "Fair",
                .poor => "Poor",
            };
        }
    };
};

/// Calculate Silhouette Score
/// Measures how similar a point is to its own cluster compared to other clusters
/// Range: [-1, 1], where 1 is best
fn calculateSilhouetteScore(
    allocator: std.mem.Allocator,
    units: []const SpatialUnit,
    labels: []const i32,
) !f64 {
    const result = ClusterResult.init(allocator, @constCast(labels));

    if (result.num_clusters < 2) return 0.0;

    var total_silhouette: f64 = 0;
    var count: usize = 0;

    // For each point
    for (units, 0..) |unit, i| {
        const label = labels[i];
        if (label < 0) continue; // Skip noise points

        // Calculate a(i): average distance to points in same cluster
        var same_cluster_dist: f64 = 0;
        var same_count: usize = 0;
        for (units, 0..) |other_unit, j| {
            if (i == j) continue;
            if (labels[j] == label) {
                same_cluster_dist += unit.getMidPoint().distance(other_unit.getMidPoint());
                same_count += 1;
            }
        }
        if (same_count == 0) continue;
        const a = same_cluster_dist / @as(f64, @floatFromInt(same_count));

        // Calculate b(i): minimum average distance to points in other clusters
        var min_other_dist: f64 = std.math.inf(f64);
        var cluster_id: i32 = 0;
        while (cluster_id < result.num_clusters) : (cluster_id += 1) {
            if (cluster_id == label) continue;

            var other_cluster_dist: f64 = 0;
            var other_count: usize = 0;
            for (units, 0..) |other_unit, j| {
                if (labels[j] == cluster_id) {
                    other_cluster_dist += unit.getMidPoint().distance(other_unit.getMidPoint());
                    other_count += 1;
                }
            }
            if (other_count > 0) {
                const avg_dist = other_cluster_dist / @as(f64, @floatFromInt(other_count));
                min_other_dist = @min(min_other_dist, avg_dist);
            }
        }

        if (std.math.isInf(min_other_dist)) continue;

        // Calculate silhouette for this point
        const b = min_other_dist;
        const s = (b - a) / @max(a, b);
        total_silhouette += s;
        count += 1;
    }

    if (count == 0) return 0.0;
    return total_silhouette / @as(f64, @floatFromInt(count));
}

/// Calculate Davies-Bouldin Index
/// Measures the average similarity between clusters
/// Range: [0, ∞), where lower is better
fn calculateDaviesBouldinIndex(
    allocator: std.mem.Allocator,
    units: []const SpatialUnit,
    labels: []const i32,
) !f64 {
    const result = ClusterResult.init(allocator, @constCast(labels));

    if (result.num_clusters < 2) return std.math.inf(f64);

    // Calculate cluster centroids and dispersions
    var centroids = std.ArrayList(Point3D).init(allocator);
    defer centroids.deinit();
    var dispersions = std.ArrayList(f64).init(allocator);
    defer dispersions.deinit();

    var cluster_id: i32 = 0;
    while (cluster_id < result.num_clusters) : (cluster_id += 1) {
        var cluster_units = std.ArrayList(SpatialUnit).init(allocator);
        defer cluster_units.deinit();

        for (units, 0..) |unit, i| {
            if (labels[i] == cluster_id) {
                try cluster_units.append(unit);
            }
        }

        if (cluster_units.items.len == 0) continue;

        // Calculate centroid
        const centroid = SpatialAnalyzer.calculateCentroid(cluster_units.items);
        try centroids.append(centroid);

        // Calculate dispersion (average distance to centroid)
        var disp: f64 = 0;
        for (cluster_units.items) |unit| {
            disp += unit.getMidPoint().distance(centroid);
        }
        disp /= @as(f64, @floatFromInt(cluster_units.items.len));
        try dispersions.append(disp);
    }

    // Calculate DB index
    var db_sum: f64 = 0;

    for (0..centroids.items.len) |i| {
        var max_ratio: f64 = 0;

        for (0..centroids.items.len) |j| {
            if (i == j) continue;

            const centroid_dist = centroids.items[i].distance(centroids.items[j]);
            if (centroid_dist < 1e-10) continue;

            const ratio = (dispersions.items[i] + dispersions.items[j]) / centroid_dist;
            max_ratio = @max(max_ratio, ratio);
        }

        db_sum += max_ratio;
    }

    return db_sum / @as(f64, @floatFromInt(centroids.items.len));
}

/// Calculate Calinski-Harabasz Index (Variance Ratio Criterion)
/// Ratio of between-cluster to within-cluster dispersion
/// Range: [0, ∞), where higher is better
fn calculateCalinskiHarabaszIndex(
    allocator: std.mem.Allocator,
    units: []const SpatialUnit,
    labels: []const i32,
) !f64 {
    const result = ClusterResult.init(allocator, @constCast(labels));

    if (result.num_clusters < 2) return 0.0;

    // Count non-noise points
    var n: usize = 0;
    for (labels) |label| {
        if (label >= 0) n += 1;
    }

    if (n == 0) return 0.0;

    // Calculate overall centroid
    var all_clustered_units = std.ArrayList(SpatialUnit).init(allocator);
    defer all_clustered_units.deinit();

    for (units, 0..) |unit, i| {
        if (labels[i] >= 0) {
            try all_clustered_units.append(unit);
        }
    }

    const overall_centroid = SpatialAnalyzer.calculateCentroid(all_clustered_units.items);

    // Calculate between-cluster dispersion (BGSS)
    var bgss: f64 = 0;

    var cluster_id: i32 = 0;
    while (cluster_id < result.num_clusters) : (cluster_id += 1) {
        var cluster_units = std.ArrayList(SpatialUnit).init(allocator);
        defer cluster_units.deinit();

        for (units, 0..) |unit, i| {
            if (labels[i] == cluster_id) {
                try cluster_units.append(unit);
            }
        }

        if (cluster_units.items.len == 0) continue;

        const cluster_centroid = SpatialAnalyzer.calculateCentroid(cluster_units.items);
        const dist = cluster_centroid.distance(overall_centroid);
        const n_k: f64 = @floatFromInt(cluster_units.items.len);

        bgss += n_k * dist * dist;
    }

    // Calculate within-cluster dispersion (WGSS)
    var wgss: f64 = 0;

    cluster_id = 0;
    while (cluster_id < result.num_clusters) : (cluster_id += 1) {
        var cluster_units = std.ArrayList(SpatialUnit).init(allocator);
        defer cluster_units.deinit();

        for (units, 0..) |unit, i| {
            if (labels[i] == cluster_id) {
                try cluster_units.append(unit);
            }
        }

        if (cluster_units.items.len == 0) continue;

        const cluster_centroid = SpatialAnalyzer.calculateCentroid(cluster_units.items);

        for (cluster_units.items) |unit| {
            const dist = unit.getMidPoint().distance(cluster_centroid);
            wgss += dist * dist;
        }
    }

    if (wgss < 1e-10) return std.math.inf(f64);

    const n_f64: f64 = @floatFromInt(n);
    const k_f64: f64 = @floatFromInt(result.num_clusters);

    // CH = (BGSS / (k-1)) / (WGSS / (n-k))
    return (bgss / (k_f64 - 1.0)) / (wgss / (n_f64 - k_f64));
}

/// Calculate clustering quality metrics
pub fn calculateClusteringMetrics(
    allocator: std.mem.Allocator,
    units: []const SpatialUnit,
    labels: []const i32,
) !ClusteringMetrics {
    const result = ClusterResult.init(allocator, @constCast(labels));

    if (result.num_clusters == 0) {
        return ClusteringMetrics{
            .silhouette_score = -1.0,
            .davies_bouldin_index = std.math.inf(f64),
            .calinski_harabasz_index = 0.0,
            .num_clusters = 0,
            .num_noise = result.num_noise,
        };
    }

    const silhouette = try calculateSilhouetteScore(allocator, units, labels);
    const db_index = try calculateDaviesBouldinIndex(allocator, units, labels);
    const ch_index = try calculateCalinskiHarabaszIndex(allocator, units, labels);

    return ClusteringMetrics{
        .silhouette_score = silhouette,
        .davies_bouldin_index = db_index,
        .calinski_harabasz_index = ch_index,
        .num_clusters = result.num_clusters,
        .num_noise = result.num_noise,
    };
}

/// Spatial interpolator for predicting geological properties
pub const SpatialInterpolator = struct {
    allocator: std.mem.Allocator,
    method: InterpolationMethod,

    pub const InterpolationMethod = enum {
        idw, // Inverse Distance Weighting
        nearest_neighbor,
        kriging, // Simple kriging (placeholder for future)
    };

    pub fn init(allocator: std.mem.Allocator, method: InterpolationMethod) SpatialInterpolator {
        return SpatialInterpolator{
            .allocator = allocator,
            .method = method,
        };
    }

    /// Interpolate material type at a given point
    pub fn interpolateMaterialType(
        self: *SpatialInterpolator,
        target: Point3D,
        units: []const SpatialUnit,
        k_neighbors: usize,
    ) !types.MaterialType {
        switch (self.method) {
            .nearest_neighbor => {
                return self.nearestNeighborMaterialType(target, units);
            },
            .idw => {
                return self.idwMaterialType(target, units, k_neighbors, 2.0);
            },
            .kriging => {
                // TODO: Implement kriging
                return self.nearestNeighborMaterialType(target, units);
            },
        }
    }

    fn nearestNeighborMaterialType(
        self: *SpatialInterpolator,
        target: Point3D,
        units: []const SpatialUnit,
    ) types.MaterialType {
        _ = self;
        if (units.len == 0) return .soil;

        var min_dist: f64 = std.math.inf(f64);
        var nearest_idx: usize = 0;

        for (units, 0..) |unit, i| {
            const dist = target.distance(unit.getMidPoint());
            if (dist < min_dist) {
                min_dist = dist;
                nearest_idx = i;
            }
        }

        return units[nearest_idx].material_type;
    }

    fn idwMaterialType(
        self: *SpatialInterpolator,
        target: Point3D,
        units: []const SpatialUnit,
        k: usize,
        power: f64,
    ) !types.MaterialType {
        if (units.len == 0) return .soil;

        // Find k nearest neighbors
        var neighbors = std.ArrayList(struct { unit: SpatialUnit, distance: f64 }).init(self.allocator);
        defer neighbors.deinit();

        for (units) |unit| {
            const dist = target.distance(unit.getMidPoint());
            try neighbors.append(.{ .unit = unit, .distance = dist });
        }

        // Sort by distance
        std.sort.pdq(
            @TypeOf(neighbors.items[0]),
            neighbors.items,
            {},
            struct {
                fn lessThan(_: void, a: @TypeOf(neighbors.items[0]), b: @TypeOf(neighbors.items[0])) bool {
                    return a.distance < b.distance;
                }
            }.lessThan,
        );

        // Use top k neighbors
        const num_neighbors = @min(k, neighbors.items.len);

        // Count weighted votes for each material type
        var soil_weight: f64 = 0;
        var rock_weight: f64 = 0;

        for (neighbors.items[0..num_neighbors]) |neighbor| {
            const weight = if (neighbor.distance < 1e-10)
                1.0
            else
                1.0 / std.math.pow(f64, neighbor.distance, power);

            switch (neighbor.unit.material_type) {
                .soil => soil_weight += weight,
                .rock => rock_weight += weight,
            }
        }

        return if (soil_weight >= rock_weight) .soil else .rock;
    }
};
