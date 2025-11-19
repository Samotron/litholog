const std = @import("std");
const spatial = @import("spatial.zig");

/// Confidence interval for a value
pub const ConfidenceInterval = struct {
    lower_bound: f64,
    upper_bound: f64,
    mean: f64,
    confidence_level: f64, // e.g., 0.95 for 95%

    pub fn contains(self: ConfidenceInterval, value: f64) bool {
        return value >= self.lower_bound and value <= self.upper_bound;
    }

    pub fn width(self: ConfidenceInterval) f64 {
        return self.upper_bound - self.lower_bound;
    }
};

/// Uncertainty metrics for unit boundaries
pub const BoundaryUncertainty = struct {
    depth_top_ci: ConfidenceInterval,
    depth_bottom_ci: ConfidenceInterval,
    thickness_ci: ConfidenceInterval,
    boundary_quality: f64, // 0-1, based on nearby boreholes

    pub fn isReliable(self: BoundaryUncertainty, threshold: f64) bool {
        return self.boundary_quality >= threshold;
    }
};

/// Interpolation quality metrics
pub const InterpolationQuality = struct {
    prediction_confidence: f64, // 0-1
    nearest_distance: f64, // Distance to nearest data point
    num_neighbors: usize, // Number of neighbors used
    variance: f64, // Variance of neighbor values
    cross_validation_error: ?f64 = null, // Optional CV error

    pub fn isHighQuality(self: InterpolationQuality) bool {
        return self.prediction_confidence > 0.7 and
            self.nearest_distance < 50.0; // 50m threshold
    }

    pub fn getQualityGrade(self: InterpolationQuality) QualityGrade {
        if (self.prediction_confidence > 0.9 and self.nearest_distance < 20.0) {
            return .excellent;
        } else if (self.prediction_confidence > 0.7 and self.nearest_distance < 50.0) {
            return .good;
        } else if (self.prediction_confidence > 0.5) {
            return .fair;
        } else {
            return .poor;
        }
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

/// Uncertainty quantifier for geological data
pub const UncertaintyQuantifier = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) UncertaintyQuantifier {
        return UncertaintyQuantifier{
            .allocator = allocator,
        };
    }

    /// Calculate confidence interval for unit boundary based on nearby observations
    pub fn calculateBoundaryUncertainty(
        self: UncertaintyQuantifier,
        target_unit: *const spatial.SpatialUnit,
        nearby_units: []const spatial.SpatialUnit,
        confidence_level: f64,
    ) !BoundaryUncertainty {
        if (nearby_units.len == 0) {
            // No nearby data - high uncertainty
            return BoundaryUncertainty{
                .depth_top_ci = ConfidenceInterval{
                    .lower_bound = target_unit.depth_top - 2.0,
                    .upper_bound = target_unit.depth_top + 2.0,
                    .mean = target_unit.depth_top,
                    .confidence_level = confidence_level,
                },
                .depth_bottom_ci = ConfidenceInterval{
                    .lower_bound = target_unit.depth_bottom - 2.0,
                    .upper_bound = target_unit.depth_bottom + 2.0,
                    .mean = target_unit.depth_bottom,
                    .confidence_level = confidence_level,
                },
                .thickness_ci = ConfidenceInterval{
                    .lower_bound = target_unit.thickness - 1.0,
                    .upper_bound = target_unit.thickness + 1.0,
                    .mean = target_unit.thickness,
                    .confidence_level = confidence_level,
                },
                .boundary_quality = 0.2, // Low quality with no nearby data
            };
        }

        // Calculate statistics from nearby units
        var top_depths = std.ArrayList(f64).init(self.allocator);
        defer top_depths.deinit();
        var bottom_depths = std.ArrayList(f64).init(self.allocator);
        defer bottom_depths.deinit();
        var distances = std.ArrayList(f64).init(self.allocator);
        defer distances.deinit();

        for (nearby_units) |unit| {
            try top_depths.append(unit.depth_top);
            try bottom_depths.append(unit.depth_bottom);
            try distances.append(target_unit.horizontalDistanceTo(unit));
        }

        // Calculate weighted mean and variance using inverse distance weighting
        const top_stats = try calculateWeightedStats(top_depths.items, distances.items);
        const bottom_stats = try calculateWeightedStats(bottom_depths.items, distances.items);

        // Calculate margin of error based on t-distribution
        const z_score = getZScore(confidence_level);
        const n_f64: f64 = @floatFromInt(nearby_units.len);

        const top_margin = z_score * top_stats.std_dev / @sqrt(n_f64);
        const bottom_margin = z_score * bottom_stats.std_dev / @sqrt(n_f64);

        // Calculate boundary quality based on nearby data
        const quality = calculateBoundaryQuality(distances.items, nearby_units.len);

        const thickness_mean = bottom_stats.mean - top_stats.mean;
        const thickness_std = @sqrt(top_stats.variance + bottom_stats.variance);
        const thickness_margin = z_score * thickness_std / @sqrt(n_f64);

        return BoundaryUncertainty{
            .depth_top_ci = ConfidenceInterval{
                .lower_bound = top_stats.mean - top_margin,
                .upper_bound = top_stats.mean + top_margin,
                .mean = top_stats.mean,
                .confidence_level = confidence_level,
            },
            .depth_bottom_ci = ConfidenceInterval{
                .lower_bound = bottom_stats.mean - bottom_margin,
                .upper_bound = bottom_stats.mean + bottom_margin,
                .mean = bottom_stats.mean,
                .confidence_level = confidence_level,
            },
            .thickness_ci = ConfidenceInterval{
                .lower_bound = thickness_mean - thickness_margin,
                .upper_bound = thickness_mean + thickness_margin,
                .mean = thickness_mean,
                .confidence_level = confidence_level,
            },
            .boundary_quality = quality,
        };
    }

    /// Calculate interpolation quality for a target point
    pub fn calculateInterpolationQuality(
        self: UncertaintyQuantifier,
        target: spatial.Point3D,
        units: []const spatial.SpatialUnit,
        k_neighbors: usize,
    ) !InterpolationQuality {
        if (units.len == 0) {
            return InterpolationQuality{
                .prediction_confidence = 0.0,
                .nearest_distance = std.math.inf(f64),
                .num_neighbors = 0,
                .variance = 0.0,
            };
        }

        // Find k nearest neighbors
        var neighbors = std.ArrayList(struct { unit: spatial.SpatialUnit, distance: f64 }).init(self.allocator);
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

        const num_neighbors = @min(k_neighbors, neighbors.items.len);
        const nearest_dist = neighbors.items[0].distance;

        // Calculate variance of neighbor material types
        var soil_count: usize = 0;
        for (neighbors.items[0..num_neighbors]) |n| {
            if (n.unit.material_type == .soil) soil_count += 1;
        }
        const soil_prop: f64 = @as(f64, @floatFromInt(soil_count)) / @as(f64, @floatFromInt(num_neighbors));
        const variance = soil_prop * (1.0 - soil_prop); // Binomial variance

        // Calculate confidence based on distance and consistency
        const distance_factor = @exp(-nearest_dist / 50.0); // Decay over 50m
        const consistency_factor: f64 = if (variance < 0.1) 0.9 else if (variance < 0.25) 0.7 else 0.4;
        const confidence = distance_factor * consistency_factor;

        return InterpolationQuality{
            .prediction_confidence = confidence,
            .nearest_distance = nearest_dist,
            .num_neighbors = num_neighbors,
            .variance = variance,
        };
    }

    /// Perform leave-one-out cross-validation
    pub fn crossValidate(
        self: *UncertaintyQuantifier,
        units: []const spatial.SpatialUnit,
        k_neighbors: usize,
    ) !CrossValidationResult {
        var errors = std.ArrayList(f64).init(self.allocator);
        defer errors.deinit();

        var correct: usize = 0;
        var total: usize = 0;

        // Leave-one-out cross-validation
        for (units, 0..) |test_unit, test_idx| {
            // Create training set (all except test_unit)
            var training = std.ArrayList(spatial.SpatialUnit).init(self.allocator);
            defer training.deinit();

            for (units, 0..) |unit, i| {
                if (i != test_idx) {
                    try training.append(unit);
                }
            }

            // Predict material type for test point
            var interpolator = spatial.SpatialInterpolator.init(self.allocator, .idw);
            const predicted = try interpolator.interpolateMaterialType(
                test_unit.getMidPoint(),
                training.items,
                k_neighbors,
            );

            // Check if prediction matches
            if (predicted == test_unit.material_type) {
                correct += 1;
            }

            total += 1;
        }

        const accuracy: f64 = @as(f64, @floatFromInt(correct)) / @as(f64, @floatFromInt(total));

        return CrossValidationResult{
            .accuracy = accuracy,
            .correct_predictions = correct,
            .total_predictions = total,
        };
    }
};

/// Cross-validation result
pub const CrossValidationResult = struct {
    accuracy: f64,
    correct_predictions: usize,
    total_predictions: usize,

    pub fn isReliable(self: CrossValidationResult) bool {
        return self.accuracy >= 0.8;
    }
};

/// Weighted statistics
const WeightedStats = struct {
    mean: f64,
    variance: f64,
    std_dev: f64,
};

fn calculateWeightedStats(values: []const f64, distances: []const f64) !WeightedStats {
    if (values.len == 0) return error.EmptyArray;

    // Calculate weights (inverse distance)
    var weights = std.ArrayList(f64).init(std.heap.page_allocator);
    defer weights.deinit();

    var sum_weights: f64 = 0;
    for (distances) |dist| {
        const weight = if (dist < 1e-10) 1000.0 else 1.0 / dist;
        try weights.append(weight);
        sum_weights += weight;
    }

    // Normalize weights
    for (weights.items) |*w| {
        w.* /= sum_weights;
    }

    // Weighted mean
    var mean: f64 = 0;
    for (values, 0..) |value, i| {
        mean += value * weights.items[i];
    }

    // Weighted variance
    var variance: f64 = 0;
    for (values, 0..) |value, i| {
        const diff = value - mean;
        variance += weights.items[i] * diff * diff;
    }

    return WeightedStats{
        .mean = mean,
        .variance = variance,
        .std_dev = @sqrt(variance),
    };
}

fn calculateBoundaryQuality(distances: []const f64, num_neighbors: usize) f64 {
    if (num_neighbors == 0) return 0.1;

    // Find minimum distance
    var min_dist: f64 = std.math.inf(f64);
    for (distances) |dist| {
        min_dist = @min(min_dist, dist);
    }

    // Quality factors:
    // 1. Number of neighbors (more is better)
    const n_f64: f64 = @floatFromInt(num_neighbors);
    const neighbor_factor = @min(1.0, n_f64 / 5.0); // Saturates at 5 neighbors

    // 2. Nearest distance (closer is better)
    const distance_factor = @exp(-min_dist / 30.0); // Decays over 30m

    // Combined quality
    return 0.3 + 0.4 * neighbor_factor + 0.3 * distance_factor;
}

fn getZScore(confidence_level: f64) f64 {
    // Approximate z-scores for common confidence levels
    if (confidence_level >= 0.99) return 2.576;
    if (confidence_level >= 0.95) return 1.960;
    if (confidence_level >= 0.90) return 1.645;
    if (confidence_level >= 0.80) return 1.282;
    return 1.645; // Default to 90%
}
