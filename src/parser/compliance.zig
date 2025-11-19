const std = @import("std");
const types = @import("types.zig");

/// BS 5930:2015 Compliance Checker
/// Validates geological descriptions against BS 5930 standard terminology and rules
pub const ComplianceChecker = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ComplianceChecker {
        return ComplianceChecker{ .allocator = allocator };
    }

    pub fn check(self: *ComplianceChecker, description: *const types.SoilDescription) !ComplianceReport {
        var issues = std.ArrayList(ComplianceIssue).init(self.allocator);
        errdefer {
            for (issues.items) |*issue| {
                issue.deinit(self.allocator);
            }
            issues.deinit();
        }

        // Check terminology compliance
        try self.checkTerminologyCompliance(&issues, description);

        // Check descriptor order
        try self.checkDescriptorOrder(&issues, description);

        // Check proportion consistency
        try self.checkProportionConsistency(&issues, description);

        // Check geological plausibility
        try self.checkGeologicalPlausibility(&issues, description);

        // Check for deprecated or non-standard terms
        try self.checkDeprecatedTerms(&issues, description);

        const is_compliant = issues.items.len == 0;

        return ComplianceReport{
            .is_compliant = is_compliant,
            .issues = try issues.toOwnedSlice(),
            .standard_version = "BS 5930:2015",
        };
    }

    fn checkTerminologyCompliance(
        self: *ComplianceChecker,
        issues: *std.ArrayList(ComplianceIssue),
        description: *const types.SoilDescription,
    ) !void {
        _ = self;
        _ = issues;
        _ = description;

        // Check for non-standard consistency terms
        // BS 5930 requires: very soft, soft, firm, stiff, very stiff, hard
        // Common non-compliant: "medium firm", "moderately stiff"

        // This is handled by the parser's terminology database
        // Additional checks can be added here for specific edge cases
    }

    fn checkDescriptorOrder(
        self: *ComplianceChecker,
        issues: *std.ArrayList(ComplianceIssue),
        description: *const types.SoilDescription,
    ) !void {
        // BS 5930 §6.3 specifies order:
        // [Consistency/Density] [Color] [Secondary constituents] [Primary constituent]
        // Example: "Firm brown slightly sandy CLAY"

        const raw = description.raw_description;

        // Check if primary constituent comes before secondary
        // This is a simplified check - full implementation would parse token positions
        if (description.material_type == .soil) {
            if (description.primary_soil_type != null and description.secondary_constituents.len > 0) {
                // Check if description structure is plausible
                // For now, just validate that we have the expected components
                _ = raw;

                // Future enhancement: Track token positions during parsing
                // and validate order here
            }
        }

        _ = self;
        _ = issues;
    }

    fn checkProportionConsistency(
        self: *ComplianceChecker,
        issues: *std.ArrayList(ComplianceIssue),
        description: *const types.SoilDescription,
    ) !void {
        // Check proportion descriptors match BS 5930 guidelines
        // - "slightly" = 5-20%
        // - "moderately" = 20-35%
        // - "very" = 35-65%
        // - Primary constituent > 65%

        for (description.secondary_constituents) |constituent| {
            const amount_str = constituent.amount;

            // Check for invalid proportion terms
            if (std.mem.indexOf(u8, description.raw_description, "some") != null or
                std.mem.indexOf(u8, description.raw_description, "little") != null or
                std.mem.indexOf(u8, description.raw_description, "bit of") != null)
            {
                const issue = try ComplianceIssue.init(
                    self.allocator,
                    .invalid_proportion_term,
                    .high,
                    "Non-standard proportion term detected",
                    "Use BS 5930 proportion descriptors: 'slightly' (5-20%), 'moderately' (20-35%), 'very' (35-65%)",
                    "BS 5930:2015 §6.3.2.4",
                );
                try issues.append(issue);
                return;
            }

            _ = amount_str;
        }
    }

    fn checkGeologicalPlausibility(
        self: *ComplianceChecker,
        issues: *std.ArrayList(ComplianceIssue),
        description: *const types.SoilDescription,
    ) !void {
        // Check for geologically implausible combinations

        // Example: Very soft gravel is physically implausible
        if (description.material_type == .soil) {
            if (description.primary_soil_type) |soil_type| {
                if (soil_type == .gravel or soil_type == .sand) {
                    if (description.consistency) |consistency| {
                        if (consistency == .very_soft or consistency == .soft) {
                            const issue = try ComplianceIssue.init(
                                self.allocator,
                                .implausible_combination,
                                .high,
                                "Granular soils (sand/gravel) cannot have 'soft' or 'very soft' consistency",
                                "Use density descriptors: 'loose', 'medium dense', 'dense', 'very dense'",
                                "BS 5930:2015 §6.3.2.2",
                            );
                            try issues.append(issue);
                        }
                    }
                }

                // Check for cohesive soils with density
                if (soil_type == .clay or soil_type == .silt) {
                    if (description.density) |density| {
                        _ = density;
                        const issue = try ComplianceIssue.init(
                            self.allocator,
                            .implausible_combination,
                            .high,
                            "Cohesive soils (clay/silt) should use consistency descriptors, not density",
                            "Use consistency descriptors: 'very soft', 'soft', 'firm', 'stiff', 'very stiff', 'hard'",
                            "BS 5930:2015 §6.3.2.2",
                        );
                        try issues.append(issue);
                    }
                }
            }
        }

        // Check for excessively wide consistency ranges
        if (description.consistency) |consistency| {
            if (consistency == .soft_to_firm or consistency == .firm_to_stiff or consistency == .stiff_to_very_stiff) {
                // Range descriptors are acceptable
            } else {
                // Check raw description for unusual ranges like "soft to very stiff"
                if (std.mem.indexOf(u8, description.raw_description, "to") != null) {
                    var lower_buf: [256]u8 = undefined;
                    const lower = std.ascii.lowerString(&lower_buf, description.raw_description[0..@min(description.raw_description.len, 256)]);
                    if (std.mem.indexOf(u8, lower, "soft to stiff") != null or
                        std.mem.indexOf(u8, lower, "firm to very stiff") != null)
                    {
                        const issue = try ComplianceIssue.init(
                            self.allocator,
                            .excessive_range,
                            .medium,
                            "Consistency range spans more than one step",
                            "Use single-step ranges (e.g., 'firm to stiff') or single values",
                            "BS 5930:2015 §6.3.2.2",
                        );
                        try issues.append(issue);
                    }
                }
            }
        }
    }

    fn checkDeprecatedTerms(
        self: *ComplianceChecker,
        issues: *std.ArrayList(ComplianceIssue),
        description: *const types.SoilDescription,
    ) !void {
        const raw_lower_buf = try self.allocator.alloc(u8, description.raw_description.len);
        defer self.allocator.free(raw_lower_buf);
        const raw_lower = std.ascii.lowerString(raw_lower_buf, description.raw_description);

        // Check for deprecated or non-standard terms
        const deprecated_terms = [_]struct {
            term: []const u8,
            suggestion: []const u8,
            reference: []const u8,
        }{
            .{ .term = "medium firm", .suggestion = "Use 'firm' or 'firm to stiff'", .reference = "BS 5930:2015 §6.3.2.2" },
            .{ .term = "moderately stiff", .suggestion = "Use 'stiff' or 'firm to stiff'", .reference = "BS 5930:2015 §6.3.2.2" },
            .{ .term = "quite", .suggestion = "Use standard BS 5930 descriptors", .reference = "BS 5930:2015 §6.3" },
            .{ .term = "somewhat", .suggestion = "Use standard BS 5930 descriptors", .reference = "BS 5930:2015 §6.3" },
            .{ .term = "fairly", .suggestion = "Use standard BS 5930 descriptors", .reference = "BS 5930:2015 §6.3" },
            .{ .term = "with sand", .suggestion = "Use 'slightly sandy', 'moderately sandy', or 'very sandy'", .reference = "BS 5930:2015 §6.3.2.4" },
            .{ .term = "with gravel", .suggestion = "Use 'slightly gravelly', 'moderately gravelly', or 'very gravelly'", .reference = "BS 5930:2015 §6.3.2.4" },
            .{ .term = "containing", .suggestion = "Use BS 5930 proportion descriptors", .reference = "BS 5930:2015 §6.3.2.4" },
            .{ .term = "traces of", .suggestion = "Use 'slightly' for 5-20%", .reference = "BS 5930:2015 §6.3.2.4" },
        };

        for (deprecated_terms) |deprecated| {
            if (std.mem.indexOf(u8, raw_lower, deprecated.term)) |_| {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "Deprecated term '{s}' detected",
                    .{deprecated.term},
                );
                const issue = ComplianceIssue{
                    .issue_type = .deprecated_terminology,
                    .severity = .medium,
                    .description = msg,
                    .suggestion = try self.allocator.dupe(u8, deprecated.suggestion),
                    .bs5930_reference = try self.allocator.dupe(u8, deprecated.reference),
                };
                try issues.append(issue);
            }
        }
    }
};

pub const ComplianceReport = struct {
    is_compliant: bool,
    issues: []ComplianceIssue,
    standard_version: []const u8,

    pub fn deinit(self: *ComplianceReport, allocator: std.mem.Allocator) void {
        for (self.issues) |*issue| {
            issue.deinit(allocator);
        }
        allocator.free(self.issues);
    }

    pub fn format(self: *const ComplianceReport, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();

        const writer = buf.writer();

        if (self.is_compliant) {
            try writer.print("✓ Compliant with {s}\n", .{self.standard_version});
        } else {
            try writer.print("✗ Non-compliant with {s}\n\n", .{self.standard_version});
            try writer.print("Issues ({d}):\n", .{self.issues.len});

            for (self.issues, 1..) |issue, idx| {
                try writer.print("\n{d}. [{s}] {s}\n", .{ idx, issue.severity.toString(), issue.description });
                try writer.print("   Suggestion: {s}\n", .{issue.suggestion});
                try writer.print("   Reference: {s}\n", .{issue.bs5930_reference});
            }
        }

        return buf.toOwnedSlice();
    }
};

pub const ComplianceIssue = struct {
    issue_type: IssueType,
    severity: Severity,
    description: []const u8,
    suggestion: []const u8,
    bs5930_reference: []const u8,

    pub const IssueType = enum {
        invalid_proportion_term,
        implausible_combination,
        excessive_range,
        deprecated_terminology,
        invalid_descriptor_order,
        non_standard_term,

        pub fn toString(self: IssueType) []const u8 {
            return switch (self) {
                .invalid_proportion_term => "Invalid Proportion Term",
                .implausible_combination => "Implausible Combination",
                .excessive_range => "Excessive Range",
                .deprecated_terminology => "Deprecated Terminology",
                .invalid_descriptor_order => "Invalid Descriptor Order",
                .non_standard_term => "Non-Standard Term",
            };
        }
    };

    pub const Severity = enum {
        low,
        medium,
        high,

        pub fn toString(self: Severity) []const u8 {
            return switch (self) {
                .low => "LOW",
                .medium => "MEDIUM",
                .high => "HIGH",
            };
        }
    };

    pub fn init(
        allocator: std.mem.Allocator,
        issue_type: IssueType,
        severity: Severity,
        description: []const u8,
        suggestion: []const u8,
        reference: []const u8,
    ) !ComplianceIssue {
        return ComplianceIssue{
            .issue_type = issue_type,
            .severity = severity,
            .description = try allocator.dupe(u8, description),
            .suggestion = try allocator.dupe(u8, suggestion),
            .bs5930_reference = try allocator.dupe(u8, reference),
        };
    }

    pub fn deinit(self: *ComplianceIssue, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
        allocator.free(self.suggestion);
        allocator.free(self.bs5930_reference);
    }
};
