const std = @import("std");
const types = @import("types.zig");

/// DBSCAN (Density-Based Spatial Clustering of Applications with Noise)
/// clustering algorithm for geological unit identification
pub const DBSCAN = struct {
    allocator: std.mem.Allocator,
    eps: f64, // Distance threshold
    min_samples: usize, // Minimum points to form a cluster

    pub const ClusterLabel = union(enum) {
        noise: void,
        cluster: usize,
        unvisited: void,
    };

    pub const Point = struct {
        index: usize,
        features: []f64,
        label: ClusterLabel,

        pub fn deinit(self: *Point, allocator: std.mem.Allocator) void {
            allocator.free(self.features);
        }
    };

    pub fn init(allocator: std.mem.Allocator, eps: f64, min_samples: usize) DBSCAN {
        return DBSCAN{
            .allocator = allocator,
            .eps = eps,
            .min_samples = min_samples,
        };
    }

    /// Run DBSCAN clustering on a set of points
    pub fn cluster(self: *DBSCAN, points: []Point) ![][]usize {
        var current_cluster: usize = 0;
        var clusters = std.ArrayList(std.ArrayList(usize)).init(self.allocator);
        errdefer {
            for (clusters.items) |c| {
                c.deinit();
            }
            clusters.deinit();
        }

        for (points, 0..) |*point, idx| {
            if (@as(u8, @intFromEnum(point.label)) != @intFromEnum(ClusterLabel.unvisited)) {
                continue;
            }

            // Find neighbors
            var neighbors = try self.regionQuery(points, idx);
            defer neighbors.deinit();

            if (neighbors.items.len < self.min_samples) {
                point.label = .noise;
            } else {
                // Start a new cluster
                var new_cluster = std.ArrayList(usize).init(self.allocator);
                try self.expandCluster(points, idx, neighbors.items, &new_cluster, current_cluster);
                try clusters.append(new_cluster);
                current_cluster += 1;
            }
        }

        // Convert to slice of slices
        var result = try self.allocator.alloc([]usize, clusters.items.len);
        for (clusters.items, 0..) |cluster_list, i| {
            result[i] = try cluster_list.toOwnedSlice();
        }

        clusters.deinit();
        return result;
    }

    fn expandCluster(
        self: *DBSCAN,
        points: []Point,
        point_idx: usize,
        neighbors: []usize,
        cluster_list: *std.ArrayList(usize),
        cluster_label: usize,
    ) !void {
        points[point_idx].label = .{ .cluster = cluster_label };
        try cluster_list.append(point_idx);

        var i: usize = 0;
        while (i < neighbors.len) : (i += 1) {
            const neighbor_idx = neighbors[i];
            const neighbor = &points[neighbor_idx];

            if (@as(u8, @intFromEnum(neighbor.label)) == @intFromEnum(ClusterLabel.unvisited)) {
                neighbor.label = .{ .cluster = cluster_label };
                try cluster_list.append(neighbor_idx);

                var neighbor_neighbors = try self.regionQuery(points, neighbor_idx);
                defer neighbor_neighbors.deinit();

                if (neighbor_neighbors.items.len >= self.min_samples) {
                    // Expand the neighbors list
                    for (neighbor_neighbors.items) |nn_idx| {
                        var found = false;
                        for (neighbors) |existing_idx| {
                            if (existing_idx == nn_idx) {
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            // Note: This is a simplified approach
                            // Full DBSCAN would dynamically grow the neighbors array
                        }
                    }
                }
            } else if (@as(u8, @intFromEnum(neighbor.label)) == @intFromEnum(ClusterLabel.noise)) {
                neighbor.label = .{ .cluster = cluster_label };
                try cluster_list.append(neighbor_idx);
            }
        }
    }

    fn regionQuery(self: *DBSCAN, points: []Point, point_idx: usize) !std.ArrayList(usize) {
        var neighbors = std.ArrayList(usize).init(self.allocator);
        errdefer neighbors.deinit();

        const point = &points[point_idx];

        for (points, 0..) |other_point, other_idx| {
            if (point_idx == other_idx) continue;

            const dist = distance(point.features, other_point.features);
            if (dist <= self.eps) {
                try neighbors.append(other_idx);
            }
        }

        return neighbors;
    }

    fn distance(a: []const f64, b: []const f64) f64 {
        if (a.len != b.len) return std.math.inf(f64);

        var sum: f64 = 0.0;
        for (a, b) |a_val, b_val| {
            const diff = a_val - b_val;
            sum += diff * diff;
        }

        return @sqrt(sum);
    }
};

/// Hierarchical clustering implementation
pub const HierarchicalClustering = struct {
    allocator: std.mem.Allocator,
    linkage_method: LinkageMethod,

    pub const LinkageMethod = enum {
        single, // Min distance between clusters
        complete, // Max distance between clusters
        average, // Average distance between clusters
    };

    pub const Dendrogram = struct {
        nodes: []DendrogramNode,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *Dendrogram) void {
            self.allocator.free(self.nodes);
        }
    };

    pub const DendrogramNode = struct {
        left: ?usize,
        right: ?usize,
        distance: f64,
        size: usize,
    };

    pub fn init(allocator: std.mem.Allocator, linkage_method: LinkageMethod) HierarchicalClustering {
        return HierarchicalClustering{
            .allocator = allocator,
            .linkage_method = linkage_method,
        };
    }

    /// Perform hierarchical clustering and return dendrogram
    pub fn cluster(self: *HierarchicalClustering, points: []const []const f64) !Dendrogram {
        const n = points.len;

        // Initialize distance matrix
        var dist_matrix = try self.allocator.alloc([]f64, n);
        defer {
            for (dist_matrix) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(dist_matrix);
        }

        for (0..n) |i| {
            dist_matrix[i] = try self.allocator.alloc(f64, n);
            for (0..n) |j| {
                if (i == j) {
                    dist_matrix[i][j] = std.math.inf(f64);
                } else {
                    dist_matrix[i][j] = euclideanDistance(points[i], points[j]);
                }
            }
        }

        // Build dendrogram
        var nodes = std.ArrayList(DendrogramNode).init(self.allocator);
        defer nodes.deinit();

        var active_clusters = try self.allocator.alloc(bool, n * 2);
        defer self.allocator.free(active_clusters);
        @memset(active_clusters, true);

        // Agglomerative clustering
        var merge_count: usize = 0;
        while (merge_count < n - 1) : (merge_count += 1) {
            // Find closest pair
            var min_dist: f64 = std.math.inf(f64);
            var min_i: usize = 0;
            var min_j: usize = 0;

            for (0..n) |i| {
                if (!active_clusters[i]) continue;
                for (i + 1..n) |j| {
                    if (!active_clusters[j]) continue;
                    if (dist_matrix[i][j] < min_dist) {
                        min_dist = dist_matrix[i][j];
                        min_i = i;
                        min_j = j;
                    }
                }
            }

            // Merge clusters
            try nodes.append(.{
                .left = min_i,
                .right = min_j,
                .distance = min_dist,
                .size = 2,
            });

            // Update distance matrix
            for (0..n) |k| {
                if (k == min_i or k == min_j or !active_clusters[k]) continue;

                const new_dist = switch (self.linkage_method) {
                    .single => @min(dist_matrix[min_i][k], dist_matrix[min_j][k]),
                    .complete => @max(dist_matrix[min_i][k], dist_matrix[min_j][k]),
                    .average => (dist_matrix[min_i][k] + dist_matrix[min_j][k]) / 2.0,
                };

                dist_matrix[min_i][k] = new_dist;
                dist_matrix[k][min_i] = new_dist;
            }

            // Deactivate merged cluster
            active_clusters[min_j] = false;
        }

        return Dendrogram{
            .nodes = try nodes.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    /// Cut dendrogram at threshold to get flat clusters
    pub fn cut(self: *HierarchicalClustering, dendrogram: *const Dendrogram, threshold: f64) ![][]usize {
        _ = self;
        _ = dendrogram;
        _ = threshold;
        // Simplified implementation - return empty for now
        return &[_][]usize{};
    }

    fn euclideanDistance(a: []const f64, b: []const f64) f64 {
        if (a.len != b.len) return std.math.inf(f64);

        var sum: f64 = 0.0;
        for (a, b) |a_val, b_val| {
            const diff = a_val - b_val;
            sum += diff * diff;
        }

        return @sqrt(sum);
    }
};
