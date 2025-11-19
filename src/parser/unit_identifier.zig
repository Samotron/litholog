const std = @import("std");
const types = @import("types.zig");
const fuzzy = @import("fuzzy.zig");
const clustering = @import("clustering.zig");

/// Represents a borehole log entry with depth information
pub const BoreholeEntry = struct {
    borehole_id: []const u8,
    depth_top: f64,
    depth_bottom: f64,
    description: types.SoilDescription,

    pub fn deinit(self: *BoreholeEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.borehole_id);
        self.description.deinit(allocator);
    }
};

/// Represents a geological unit identified across multiple boreholes
pub const GeologicalUnit = struct {
    unit_id: usize, // e.g., 1, 2, 3
    typical_description: []const u8,
    material_type: types.MaterialType,
    primary_soil_type: ?types.SoilType,
    primary_rock_type: ?types.RockType,
    consistency: ?types.Consistency,
    density: ?types.Density,
    rock_strength: ?types.RockStrength,

    // Depth statistics
    min_depth_top: f64,
    max_depth_top: f64,
    min_depth_bottom: f64,
    max_depth_bottom: f64,
    avg_thickness: f64,

    // Occurrence information
    borehole_ids: [][]const u8,
    entry_count: usize,

    pub fn deinit(self: *GeologicalUnit, allocator: std.mem.Allocator) void {
        allocator.free(self.typical_description);
        for (self.borehole_ids) |bh_id| {
            allocator.free(bh_id);
        }
        allocator.free(self.borehole_ids);
    }
};

/// Summary of all geological units identified
pub const UnitSummary = struct {
    units: []GeologicalUnit,
    total_boreholes: usize,
    entry_to_unit: []usize, // Maps entry index to unit_id

    pub fn deinit(self: *UnitSummary, allocator: std.mem.Allocator) void {
        for (self.units) |*unit| {
            unit.deinit(allocator);
        }
        allocator.free(self.units);
        allocator.free(self.entry_to_unit);
    }
};

/// Identifies geological units from borehole entries
pub const UnitIdentifier = struct {
    allocator: std.mem.Allocator,
    similarity_threshold: f64,
    clustering_method: ClusteringMethod,

    pub const ClusteringMethod = enum {
        simple, // Original greedy algorithm
        dbscan, // Density-based clustering
        hierarchical, // Hierarchical clustering
    };

    pub fn init(allocator: std.mem.Allocator) UnitIdentifier {
        return UnitIdentifier{
            .allocator = allocator,
            .similarity_threshold = 0.7, // 70% similarity to be considered same unit
            .clustering_method = .simple,
        };
    }

    pub fn initWithMethod(allocator: std.mem.Allocator, method: ClusteringMethod) UnitIdentifier {
        return UnitIdentifier{
            .allocator = allocator,
            .similarity_threshold = 0.7,
            .clustering_method = method,
        };
    }

    /// Identify units from a list of borehole entries
    pub fn identifyUnits(self: *UnitIdentifier, entries: []BoreholeEntry) !UnitSummary {
        if (entries.len == 0) {
            return UnitSummary{
                .units = &[_]GeologicalUnit{},
                .total_boreholes = 0,
                .entry_to_unit = &[_]usize{},
            };
        }

        // Group entries by similarity
        var clusters = std.ArrayList(std.ArrayList(usize)).init(self.allocator);
        defer {
            for (clusters.items) |cluster| {
                cluster.deinit();
            }
            clusters.deinit();
        }

        // Simple clustering algorithm
        for (entries, 0..) |entry, i| {
            var assigned = false;

            // Try to assign to existing cluster
            for (clusters.items) |*cluster| {
                const representative_idx = cluster.items[0];
                const representative = &entries[representative_idx];

                if (try self.areSimilar(&entry.description, &representative.description)) {
                    try cluster.append(i);
                    assigned = true;
                    break;
                }
            }

            // Create new cluster if not assigned
            if (!assigned) {
                var new_cluster = std.ArrayList(usize).init(self.allocator);
                try new_cluster.append(i);
                try clusters.append(new_cluster);
            }
        }

        // Sort clusters by average depth to get stratigraphic order
        const sorted_clusters = try self.sortClustersByDepth(clusters.items, entries);
        defer self.allocator.free(sorted_clusters);

        // Build entry-to-unit mapping
        var entry_to_unit = try self.allocator.alloc(usize, entries.len);

        // Build geological units from clusters
        var units = std.ArrayList(GeologicalUnit).init(self.allocator);
        errdefer {
            for (units.items) |*unit| {
                unit.deinit(self.allocator);
            }
            units.deinit();
        }

        for (sorted_clusters, 0..) |cluster_idx, unit_id| {
            const cluster = clusters.items[cluster_idx];
            const unit = try self.buildUnit(unit_id + 1, cluster.items, entries);
            try units.append(unit);

            // Map all entries in this cluster to this unit_id
            for (cluster.items) |entry_idx| {
                entry_to_unit[entry_idx] = unit_id + 1;
            }
        }

        // Count unique boreholes
        var borehole_set = std.StringHashMap(void).init(self.allocator);
        defer borehole_set.deinit();
        for (entries) |entry| {
            try borehole_set.put(entry.borehole_id, {});
        }

        return UnitSummary{
            .units = try units.toOwnedSlice(),
            .total_boreholes = borehole_set.count(),
            .entry_to_unit = entry_to_unit,
        };
    }

    /// Check if two descriptions are similar enough to belong to same unit
    pub fn areSimilar(self: *UnitIdentifier, desc1: *const types.SoilDescription, desc2: *const types.SoilDescription) !bool {
        // Must be same material type
        if (desc1.material_type != desc2.material_type) return false;

        var similarity_score: f64 = 0;
        var criteria_count: f64 = 0;

        // Compare material type (already checked above, but contributes to score)
        similarity_score += 1.0;
        criteria_count += 1.0;

        // Compare primary soil type
        if (desc1.material_type == .soil) {
            if (desc1.primary_soil_type != null and desc2.primary_soil_type != null) {
                if (desc1.primary_soil_type.? == desc2.primary_soil_type.?) {
                    similarity_score += 1.0;
                }
                criteria_count += 1.0;
            }

            // Compare consistency (less strict - allow adjacent values)
            if (desc1.consistency != null and desc2.consistency != null) {
                const c1 = @intFromEnum(desc1.consistency.?);
                const c2 = @intFromEnum(desc2.consistency.?);
                const diff = if (c1 > c2) c1 - c2 else c2 - c1;
                if (diff <= 1) { // Allow one step difference
                    similarity_score += 0.8;
                } else if (diff == 2) {
                    similarity_score += 0.4;
                }
                criteria_count += 1.0;
            }

            // Compare density (less strict - allow adjacent values)
            if (desc1.density != null and desc2.density != null) {
                const d1 = @intFromEnum(desc1.density.?);
                const d2 = @intFromEnum(desc2.density.?);
                const diff = if (d1 > d2) d1 - d2 else d2 - d1;
                if (diff <= 1) {
                    similarity_score += 0.8;
                } else if (diff == 2) {
                    similarity_score += 0.4;
                }
                criteria_count += 1.0;
            }
        } else {
            // Rock comparison
            if (desc1.primary_rock_type != null and desc2.primary_rock_type != null) {
                if (desc1.primary_rock_type.? == desc2.primary_rock_type.?) {
                    similarity_score += 1.0;
                }
                criteria_count += 1.0;
            }

            // Compare rock strength
            if (desc1.rock_strength != null and desc2.rock_strength != null) {
                const r1 = @intFromEnum(desc1.rock_strength.?);
                const r2 = @intFromEnum(desc2.rock_strength.?);
                const diff = if (r1 > r2) r1 - r2 else r2 - r1;
                if (diff <= 1) {
                    similarity_score += 0.8;
                } else if (diff == 2) {
                    similarity_score += 0.4;
                }
                criteria_count += 1.0;
            }

            // Compare weathering grade
            if (desc1.weathering_grade != null and desc2.weathering_grade != null) {
                const w1 = @intFromEnum(desc1.weathering_grade.?);
                const w2 = @intFromEnum(desc2.weathering_grade.?);
                const diff = if (w1 > w2) w1 - w2 else w2 - w1;
                if (diff <= 1) {
                    similarity_score += 0.8;
                } else if (diff == 2) {
                    similarity_score += 0.4;
                }
                criteria_count += 1.0;
            }
        }

        // Calculate final similarity ratio
        if (criteria_count == 0) return false;

        const ratio = similarity_score / criteria_count;
        return ratio >= self.similarity_threshold;
    }

    /// Sort cluster indices by average depth
    fn sortClustersByDepth(self: *UnitIdentifier, clusters: []std.ArrayList(usize), entries: []BoreholeEntry) ![]usize {
        var cluster_depths = try self.allocator.alloc(struct { idx: usize, depth: f64 }, clusters.len);
        defer self.allocator.free(cluster_depths);

        for (clusters, 0..) |cluster, i| {
            var total_depth: f64 = 0;
            for (cluster.items) |entry_idx| {
                total_depth += entries[entry_idx].depth_top;
            }
            cluster_depths[i] = .{
                .idx = i,
                .depth = total_depth / @as(f64, @floatFromInt(cluster.items.len)),
            };
        }

        // Sort by depth
        std.sort.pdq(
            @TypeOf(cluster_depths[0]),
            cluster_depths,
            {},
            struct {
                fn lessThan(_: void, a: @TypeOf(cluster_depths[0]), b: @TypeOf(cluster_depths[0])) bool {
                    return a.depth < b.depth;
                }
            }.lessThan,
        );

        var result = try self.allocator.alloc(usize, clusters.len);
        for (cluster_depths, 0..) |cd, i| {
            result[i] = cd.idx;
        }

        return result;
    }

    /// Build a geological unit from a cluster of entries
    fn buildUnit(self: *UnitIdentifier, unit_id: usize, cluster: []const usize, entries: []BoreholeEntry) !GeologicalUnit {
        // Find most representative description (most common characteristics)
        const representative_idx = cluster[0];
        const representative = &entries[representative_idx].description;

        // Calculate depth statistics
        var min_top: f64 = std.math.inf(f64);
        var max_top: f64 = -std.math.inf(f64);
        var min_bottom: f64 = std.math.inf(f64);
        var max_bottom: f64 = -std.math.inf(f64);
        var total_thickness: f64 = 0;

        for (cluster) |idx| {
            const entry = &entries[idx];
            min_top = @min(min_top, entry.depth_top);
            max_top = @max(max_top, entry.depth_top);
            min_bottom = @min(min_bottom, entry.depth_bottom);
            max_bottom = @max(max_bottom, entry.depth_bottom);
            total_thickness += (entry.depth_bottom - entry.depth_top);
        }

        const avg_thickness = total_thickness / @as(f64, @floatFromInt(cluster.len));

        // Collect unique borehole IDs
        var borehole_set = std.StringHashMap(void).init(self.allocator);
        defer borehole_set.deinit();

        for (cluster) |idx| {
            try borehole_set.put(entries[idx].borehole_id, {});
        }

        var borehole_ids = std.ArrayList([]const u8).init(self.allocator);
        var bh_iter = borehole_set.keyIterator();
        while (bh_iter.next()) |bh_id| {
            try borehole_ids.append(try self.allocator.dupe(u8, bh_id.*));
        }

        return GeologicalUnit{
            .unit_id = unit_id,
            .typical_description = try self.allocator.dupe(u8, representative.raw_description),
            .material_type = representative.material_type,
            .primary_soil_type = representative.primary_soil_type,
            .primary_rock_type = representative.primary_rock_type,
            .consistency = representative.consistency,
            .density = representative.density,
            .rock_strength = representative.rock_strength,
            .min_depth_top = min_top,
            .max_depth_top = max_top,
            .min_depth_bottom = min_bottom,
            .max_depth_bottom = max_bottom,
            .avg_thickness = avg_thickness,
            .borehole_ids = try borehole_ids.toOwnedSlice(),
            .entry_count = cluster.len,
        };
    }
};

/// Format units as a terminal table
pub fn formatUnitsTable(allocator: std.mem.Allocator, summary: *const UnitSummary) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);
    const writer = output.writer();

    try writer.writeAll("\n");
    try writer.writeAll("═══════════════════════════════════════════════════════════════════════════════════════════════════\n");
    try writer.writeAll("                              GEOLOGICAL UNIT SUMMARY\n");
    try writer.writeAll("═══════════════════════════════════════════════════════════════════════════════════════════════════\n");
    try writer.print("Total Boreholes: {d}\n", .{summary.total_boreholes});
    try writer.print("Units Identified: {d}\n\n", .{summary.units.len});

    for (summary.units) |unit| {
        try writer.writeAll("───────────────────────────────────────────────────────────────────────────────────────────────────\n");
        try writer.print("UNIT {d}\n", .{unit.unit_id});
        try writer.writeAll("───────────────────────────────────────────────────────────────────────────────────────────────────\n");

        // Typical description (wrap if too long)
        try writer.print("Typical Description:  {s}\n", .{unit.typical_description});
        try writer.print("Material Type:        {s}\n", .{unit.material_type.toString()});

        // Material-specific properties
        if (unit.material_type == .soil) {
            if (unit.primary_soil_type) |pst| {
                try writer.print("Primary Soil Type:    {s}\n", .{pst.toString()});
            }
            if (unit.consistency) |c| {
                try writer.print("Consistency:          {s}\n", .{c.toString()});
            }
            if (unit.density) |d| {
                try writer.print("Density:              {s}\n", .{d.toString()});
            }
        } else {
            if (unit.primary_rock_type) |prt| {
                try writer.print("Primary Rock Type:    {s}\n", .{prt.toString()});
            }
            if (unit.rock_strength) |rs| {
                try writer.print("Rock Strength:        {s}\n", .{rs.toString()});
            }
        }

        try writer.writeAll("\n");
        try writer.print("Depth Range (Top):    {d:.2}m - {d:.2}m\n", .{ unit.min_depth_top, unit.max_depth_top });
        try writer.print("Depth Range (Bottom): {d:.2}m - {d:.2}m\n", .{ unit.min_depth_bottom, unit.max_depth_bottom });
        try writer.print("Average Thickness:    {d:.2}m\n", .{unit.avg_thickness});

        try writer.writeAll("\n");
        try writer.print("Found in {d}/{d} boreholes ({d} occurrences total)\n", .{
            unit.borehole_ids.len,
            summary.total_boreholes,
            unit.entry_count,
        });

        // List borehole IDs
        try writer.writeAll("Boreholes: ");
        for (unit.borehole_ids, 0..) |bh_id, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.writeAll(bh_id);
        }
        try writer.writeAll("\n\n");
    }

    try writer.writeAll("═══════════════════════════════════════════════════════════════════════════════════════════════════\n");

    return output.toOwnedSlice();
}
