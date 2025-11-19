const std = @import("std");
const types = @import("types.zig");
const terminology = @import("terminology.zig");

const SoilDescription = types.SoilDescription;
const MaterialType = types.MaterialType;
const SoilType = types.SoilType;
const Consistency = types.Consistency;
const Density = types.Density;

/// Anomaly types that can be detected in soil descriptions
pub const AnomalyType = enum {
    mismatched_strength_descriptor, // e.g., "Dense CLAY" (density on cohesive soil)
    missing_strength_descriptor, // e.g., "CLAY" without consistency
    unusual_constituent_combination, // e.g., "very clayey SAND" (too much clay for sand)
    conflicting_properties, // e.g., "soft and stiff CLAY"
    out_of_range_strength, // strength parameter outside typical bounds
    invalid_transition_range, // e.g., "hard to soft" (backwards range)
    excessive_constituents, // too many secondary constituents
    duplicate_constituents, // same constituent listed multiple times
    spelling_correction, // automatic spelling correction applied

    pub fn toString(self: AnomalyType) []const u8 {
        return switch (self) {
            .mismatched_strength_descriptor => "Mismatched strength descriptor",
            .missing_strength_descriptor => "Missing strength descriptor",
            .unusual_constituent_combination => "Unusual constituent combination",
            .conflicting_properties => "Conflicting properties",
            .out_of_range_strength => "Out of range strength parameter",
            .invalid_transition_range => "Invalid transition range",
            .excessive_constituents => "Excessive secondary constituents",
            .duplicate_constituents => "Duplicate constituents",
            .spelling_correction => "Spelling correction applied",
        };
    }

    pub fn getSeverity(self: AnomalyType) Severity {
        return switch (self) {
            .mismatched_strength_descriptor => .high,
            .conflicting_properties => .high,
            .invalid_transition_range => .high,
            .missing_strength_descriptor => .medium,
            .out_of_range_strength => .medium,
            .unusual_constituent_combination => .medium,
            .excessive_constituents => .low,
            .duplicate_constituents => .low,
            .spelling_correction => .low,
        };
    }
};

/// Severity levels for anomalies
pub const Severity = enum {
    low,
    medium,
    high,

    pub fn toString(self: Severity) []const u8 {
        return switch (self) {
            .low => "low",
            .medium => "medium",
            .high => "high",
        };
    }
};

/// Represents a detected anomaly in a soil description
pub const Anomaly = struct {
    anomaly_type: AnomalyType,
    severity: Severity,
    description: []const u8,
    suggestion: ?[]const u8 = null,

    pub fn deinit(self: *Anomaly, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
        if (self.suggestion) |sug| {
            allocator.free(sug);
        }
    }
};

/// Anomaly detection result
pub const AnomalyResult = struct {
    has_anomalies: bool,
    anomalies: []Anomaly,
    overall_severity: Severity,

    pub fn deinit(self: *AnomalyResult, allocator: std.mem.Allocator) void {
        for (self.anomalies) |*anomaly| {
            anomaly.deinit(allocator);
        }
        allocator.free(self.anomalies);
    }
};

/// Anomaly detector for soil descriptions
pub const AnomalyDetector = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnomalyDetector {
        return AnomalyDetector{ .allocator = allocator };
    }

    /// Detect all anomalies in a soil description
    pub fn detect(self: *AnomalyDetector, description: *const SoilDescription) !AnomalyResult {
        var anomalies = std.ArrayList(Anomaly).init(self.allocator);
        errdefer {
            for (anomalies.items) |*anomaly| {
                anomaly.deinit(self.allocator);
            }
            anomalies.deinit();
        }

        // Check for mismatched strength descriptors
        try self.checkMismatchedStrengthDescriptor(description, &anomalies);

        // Check for missing strength descriptors
        try self.checkMissingStrengthDescriptor(description, &anomalies);

        // Check for unusual constituent combinations
        try self.checkUnusualConstituentCombination(description, &anomalies);

        // Check for conflicting properties
        try self.checkConflictingProperties(description, &anomalies);

        // Check for out-of-range strength parameters
        try self.checkOutOfRangeStrength(description, &anomalies);

        // Check for invalid transition ranges
        try self.checkInvalidTransitionRange(description, &anomalies);

        // Check for excessive constituents
        try self.checkExcessiveConstituents(description, &anomalies);

        // Check for duplicate constituents
        try self.checkDuplicateConstituents(description, &anomalies);

        // Check for spelling corrections
        try self.checkSpellingCorrections(description, &anomalies);

        const anomaly_slice = try anomalies.toOwnedSlice();

        // Calculate overall severity
        const overall_severity = self.calculateOverallSeverity(anomaly_slice);

        return AnomalyResult{
            .has_anomalies = anomaly_slice.len > 0,
            .anomalies = anomaly_slice,
            .overall_severity = overall_severity,
        };
    }

    fn checkMismatchedStrengthDescriptor(
        self: *AnomalyDetector,
        description: *const SoilDescription,
        anomalies: *std.ArrayList(Anomaly),
    ) !void {
        if (description.material_type != .soil) return;

        if (description.primary_soil_type) |soil_type| {
            const is_cohesive = soil_type.isCohesive();
            const is_granular = soil_type.isGranular();

            // Cohesive soil with density descriptor
            if (is_cohesive and description.density != null and description.consistency == null) {
                const desc = try std.fmt.allocPrint(
                    self.allocator,
                    "Cohesive soil '{s}' has density descriptor but should use consistency",
                    .{@tagName(soil_type)},
                );
                const suggestion = try std.fmt.allocPrint(
                    self.allocator,
                    "Replace density descriptor with consistency (e.g., soft, firm, stiff)",
                    .{},
                );
                try anomalies.append(Anomaly{
                    .anomaly_type = .mismatched_strength_descriptor,
                    .severity = .high,
                    .description = desc,
                    .suggestion = suggestion,
                });
            }

            // Granular soil with consistency descriptor
            if (is_granular and description.consistency != null and description.density == null) {
                const desc = try std.fmt.allocPrint(
                    self.allocator,
                    "Granular soil '{s}' has consistency descriptor but should use density",
                    .{@tagName(soil_type)},
                );
                const suggestion = try std.fmt.allocPrint(
                    self.allocator,
                    "Replace consistency descriptor with density (e.g., loose, dense, very dense)",
                    .{},
                );
                try anomalies.append(Anomaly{
                    .anomaly_type = .mismatched_strength_descriptor,
                    .severity = .high,
                    .description = desc,
                    .suggestion = suggestion,
                });
            }
        }
    }

    fn checkMissingStrengthDescriptor(
        self: *AnomalyDetector,
        description: *const SoilDescription,
        anomalies: *std.ArrayList(Anomaly),
    ) !void {
        if (description.material_type != .soil) return;

        if (description.primary_soil_type) |soil_type| {
            const is_cohesive = soil_type.isCohesive();
            const is_granular = soil_type.isGranular();

            // Cohesive soil missing consistency
            if (is_cohesive and description.consistency == null) {
                const desc = try std.fmt.allocPrint(
                    self.allocator,
                    "Cohesive soil '{s}' is missing consistency descriptor",
                    .{@tagName(soil_type)},
                );
                const suggestion = try std.fmt.allocPrint(
                    self.allocator,
                    "Add consistency descriptor (e.g., soft, firm, stiff, very stiff)",
                    .{},
                );
                try anomalies.append(Anomaly{
                    .anomaly_type = .missing_strength_descriptor,
                    .severity = .medium,
                    .description = desc,
                    .suggestion = suggestion,
                });
            }

            // Granular soil missing density
            if (is_granular and description.density == null) {
                const desc = try std.fmt.allocPrint(
                    self.allocator,
                    "Granular soil '{s}' is missing density descriptor",
                    .{@tagName(soil_type)},
                );
                const suggestion = try std.fmt.allocPrint(
                    self.allocator,
                    "Add density descriptor (e.g., loose, medium dense, dense)",
                    .{},
                );
                try anomalies.append(Anomaly{
                    .anomaly_type = .missing_strength_descriptor,
                    .severity = .medium,
                    .description = desc,
                    .suggestion = suggestion,
                });
            }
        }
    }

    fn checkUnusualConstituentCombination(
        self: *AnomalyDetector,
        description: *const SoilDescription,
        anomalies: *std.ArrayList(Anomaly),
    ) !void {
        if (description.secondary_constituents.len == 0) return;

        // Check for constituents that indicate the primary soil type might be wrong
        // e.g., "very clayey SAND" might actually be "sandy CLAY"
        if (description.primary_soil_type) |primary| {
            for (description.secondary_constituents) |constituent| {
                const is_very = std.mem.eql(u8, constituent.amount, "very");
                const is_clayey = std.mem.eql(u8, constituent.soil_type, "clayey");
                const is_sandy = std.mem.eql(u8, constituent.soil_type, "sandy");

                // Very clayey sand might be sandy clay
                if (primary == .sand and is_very and is_clayey) {
                    const desc = try std.fmt.allocPrint(
                        self.allocator,
                        "SAND with 'very clayey' constituent might be mis-classified - consider 'sandy CLAY'",
                        .{},
                    );
                    const suggestion = try std.fmt.allocPrint(
                        self.allocator,
                        "Consider reclassifying as 'sandy CLAY' instead",
                        .{},
                    );
                    try anomalies.append(Anomaly{
                        .anomaly_type = .unusual_constituent_combination,
                        .severity = .medium,
                        .description = desc,
                        .suggestion = suggestion,
                    });
                }

                // Very sandy clay might be clayey sand
                if (primary == .clay and is_very and is_sandy) {
                    const desc = try std.fmt.allocPrint(
                        self.allocator,
                        "CLAY with 'very sandy' constituent might be mis-classified - consider 'clayey SAND'",
                        .{},
                    );
                    const suggestion = try std.fmt.allocPrint(
                        self.allocator,
                        "Consider reclassifying as 'clayey SAND' instead",
                        .{},
                    );
                    try anomalies.append(Anomaly{
                        .anomaly_type = .unusual_constituent_combination,
                        .severity = .medium,
                        .description = desc,
                        .suggestion = suggestion,
                    });
                }
            }
        }
    }

    fn checkConflictingProperties(
        self: *AnomalyDetector,
        description: *const SoilDescription,
        anomalies: *std.ArrayList(Anomaly),
    ) !void {
        // Check for both consistency and density (should not both be present)
        if (description.consistency != null and description.density != null) {
            const desc = try std.fmt.allocPrint(
                self.allocator,
                "Description has both consistency and density descriptors - these are mutually exclusive",
                .{},
            );
            const suggestion = try std.fmt.allocPrint(
                self.allocator,
                "Remove either consistency (for granular soils) or density (for cohesive soils)",
                .{},
            );
            try anomalies.append(Anomaly{
                .anomaly_type = .conflicting_properties,
                .severity = .high,
                .description = desc,
                .suggestion = suggestion,
            });
        }
    }

    fn checkOutOfRangeStrength(
        self: *AnomalyDetector,
        description: *const SoilDescription,
        anomalies: *std.ArrayList(Anomaly),
    ) !void {
        if (description.strength_parameters) |params| {
            // Check if typical value is outside the range (should never happen in well-formed data)
            if (params.range.typical_value) |tv| {
                if (tv < params.range.lower_bound or tv > params.range.upper_bound) {
                    const desc = try std.fmt.allocPrint(
                        self.allocator,
                        "Typical strength value {d:.1} is outside range [{d:.1}, {d:.1}]",
                        .{ tv, params.range.lower_bound, params.range.upper_bound },
                    );
                    try anomalies.append(Anomaly{
                        .anomaly_type = .out_of_range_strength,
                        .severity = .medium,
                        .description = desc,
                        .suggestion = null,
                    });
                }
            }
        }
    }

    fn checkInvalidTransitionRange(
        self: *AnomalyDetector,
        description: *const SoilDescription,
        anomalies: *std.ArrayList(Anomaly),
    ) !void {
        _ = self;
        _ = anomalies;
        _ = description;

        // Invalid transition ranges are typically caught during lexing/parsing
        // This check is a placeholder for future enhancement where we might
        // detect illogical ranges that passed initial parsing
    }

    fn checkExcessiveConstituents(
        self: *AnomalyDetector,
        description: *const SoilDescription,
        anomalies: *std.ArrayList(Anomaly),
    ) !void {
        // More than 3 secondary constituents is unusual
        if (description.secondary_constituents.len > 3) {
            const desc = try std.fmt.allocPrint(
                self.allocator,
                "Description has {d} secondary constituents - typically no more than 2-3 expected",
                .{description.secondary_constituents.len},
            );
            const suggestion = try std.fmt.allocPrint(
                self.allocator,
                "Consider simplifying by listing only the most significant constituents",
                .{},
            );
            try anomalies.append(Anomaly{
                .anomaly_type = .excessive_constituents,
                .severity = .low,
                .description = desc,
                .suggestion = suggestion,
            });
        }
    }

    fn checkDuplicateConstituents(
        self: *AnomalyDetector,
        description: *const SoilDescription,
        anomalies: *std.ArrayList(Anomaly),
    ) !void {
        if (description.secondary_constituents.len < 2) return;

        // Check for duplicate soil types in constituents
        for (description.secondary_constituents, 0..) |constituent1, i| {
            for (description.secondary_constituents[i + 1 ..], i + 1..) |constituent2, j| {
                _ = j;
                if (std.mem.eql(u8, constituent1.soil_type, constituent2.soil_type)) {
                    const desc = try std.fmt.allocPrint(
                        self.allocator,
                        "Duplicate constituent type '{s}' found in description",
                        .{constituent1.soil_type},
                    );
                    const suggestion = try std.fmt.allocPrint(
                        self.allocator,
                        "Remove duplicate '{s}' constituent or combine them",
                        .{constituent1.soil_type},
                    );
                    try anomalies.append(Anomaly{
                        .anomaly_type = .duplicate_constituents,
                        .severity = .low,
                        .description = desc,
                        .suggestion = suggestion,
                    });
                }
            }
        }
    }

    fn checkSpellingCorrections(
        self: *AnomalyDetector,
        description: *const SoilDescription,
        anomalies: *std.ArrayList(Anomaly),
    ) !void {
        for (description.spelling_corrections) |correction| {
            const desc = try std.fmt.allocPrint(
                self.allocator,
                "Spelling corrected: '{s}' -> '{s}' (similarity: {d:.2})",
                .{ correction.original, correction.corrected, correction.similarity_score },
            );
            try anomalies.append(Anomaly{
                .anomaly_type = .spelling_correction,
                .severity = .low,
                .description = desc,
                .suggestion = null,
            });
        }
    }

    fn calculateOverallSeverity(self: *AnomalyDetector, anomalies: []Anomaly) Severity {
        _ = self;
        if (anomalies.len == 0) return .low;

        var has_high = false;
        var has_medium = false;

        for (anomalies) |anomaly| {
            switch (anomaly.severity) {
                .high => has_high = true,
                .medium => has_medium = true,
                .low => {},
            }
        }

        if (has_high) return .high;
        if (has_medium) return .medium;
        return .low;
    }
};
