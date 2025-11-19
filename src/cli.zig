const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");
const builtin = @import("builtin");

pub const CliArgs = struct {
    description: ?[]const u8 = null,
    file_path: ?[]const u8 = null,
    csv_path: ?[]const u8 = null,
    csv_output_path: ?[]const u8 = null,
    csv_column: ?[]const u8 = null,
    csv_output_columns: ?[]const []const u8 = null,
    csv_no_header: bool = false,
    output_mode: OutputMode = .compact,
    help: bool = false,
    no_color: bool = false,
    check_anomalies: bool = false,
    check_compliance: bool = false,
    generate_mode: ?GenerateMode = null,
    generate_count: u32 = 1,
    generate_seed: u64 = 0,
    // Unit identification options
    identify_units: bool = false,
    borehole_id_column: ?[]const u8 = null,
    depth_top_column: ?[]const u8 = null,
    depth_bottom_column: ?[]const u8 = null,
    // Spatial analysis options
    spatial_analysis: bool = false,
    x_column: ?[]const u8 = null,
    y_column: ?[]const u8 = null,
    z_column: ?[]const u8 = null,
    spatial_cluster: bool = false,
    cluster_epsilon: f64 = 10.0,
    cluster_min_points: usize = 3,
    // Excel options
    excel_output: bool = false,
    freeze_header: bool = false,
    auto_filter: bool = false,
    sheet_name: ?[]const u8 = null,
    allocator: ?std.mem.Allocator = null,

    pub const OutputMode = enum {
        compact,
        verbose,
        pretty,
        summary,
    };

    pub const GenerateMode = enum {
        random,
        variations,
    };

    pub fn deinit(self: *CliArgs) void {
        if (self.csv_output_columns) |cols| {
            if (self.allocator) |allocator| {
                allocator.free(cols);
            }
        }
    }
};

pub const Cli = struct {
    allocator: std.mem.Allocator,
    parser: bs5930.Parser,
    use_colors: bool,

    pub fn init(allocator: std.mem.Allocator) Cli {
        return Cli{
            .allocator = allocator,
            .parser = bs5930.Parser.init(allocator),
            .use_colors = detectColorSupport(),
        };
    }

    fn detectColorSupport() bool {
        // Force disable if NO_COLOR environment variable is set (universal standard)
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "NO_COLOR")) |no_color| {
            defer std.heap.page_allocator.free(no_color);
            if (no_color.len > 0) return false;
        } else |_| {}

        // Force enable if FORCE_COLOR is set
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "FORCE_COLOR")) |force_color| {
            defer std.heap.page_allocator.free(force_color);
            if (force_color.len > 0 and !std.mem.eql(u8, force_color, "0")) return true;
        } else |_| {}

        // Check if output is redirected (not a TTY)
        if (!isatty(std.io.getStdOut().handle)) {
            return false;
        }

        if (builtin.os.tag == .windows) {
            return detectWindowsColorSupport();
        } else {
            return detectUnixColorSupport();
        }
    }

    fn isatty(handle: std.fs.File.Handle) bool {
        if (builtin.os.tag == .windows) {
            // On Windows, check if handle is a console
            const INVALID_HANDLE_VALUE = @as(std.os.windows.HANDLE, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
            if (handle == INVALID_HANDLE_VALUE) return false;

            var mode: std.os.windows.DWORD = undefined;
            return std.os.windows.kernel32.GetConsoleMode(handle, &mode) != 0;
        } else {
            // On Unix-like systems, use posix isatty
            return std.posix.isatty(handle);
        }
    }

    fn detectWindowsColorSupport() bool {
        // Windows Terminal
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "WT_SESSION")) |wt| {
            defer std.heap.page_allocator.free(wt);
            return true;
        } else |_| {}

        // Windows Terminal Preview
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "WT_PROFILE_ID")) |wt| {
            defer std.heap.page_allocator.free(wt);
            return true;
        } else |_| {}

        // ConEmu
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "ConEmuANSI")) |ansi| {
            defer std.heap.page_allocator.free(ansi);
            return std.mem.eql(u8, ansi, "ON");
        } else |_| {}

        // ANSICON (ANSI support for older Windows consoles)
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "ANSICON")) |ansicon| {
            defer std.heap.page_allocator.free(ansicon);
            return ansicon.len > 0;
        } else |_| {}

        // Check Windows version and console capabilities
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "TERM")) |term| {
            defer std.heap.page_allocator.free(term);
            // Modern terminals that support ANSI
            return std.mem.indexOf(u8, term, "xterm") != null or
                std.mem.indexOf(u8, term, "color") != null or
                std.mem.indexOf(u8, term, "ansi") != null or
                std.mem.indexOf(u8, term, "cygwin") != null;
        } else |_| {}

        // Check for Windows 10+ with VT100 support
        if (detectWindows10VTSupport()) {
            return true;
        }

        // Default to false for older Windows consoles
        return false;
    }

    fn detectWindows10VTSupport() bool {
        if (builtin.os.tag != .windows) return false;

        // Try to enable VT100 processing to test support
        const stdout_handle = std.io.getStdOut().handle;
        var mode: std.os.windows.DWORD = undefined;

        if (std.os.windows.kernel32.GetConsoleMode(stdout_handle, &mode) == 0) {
            return false;
        }

        // ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
        const ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
        const new_mode = mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING;

        // Try to set VT100 mode - if successful, the console supports it
        if (std.os.windows.kernel32.SetConsoleMode(stdout_handle, new_mode) != 0) {
            // Restore original mode
            _ = std.os.windows.kernel32.SetConsoleMode(stdout_handle, mode);
            return true;
        }

        return false;
    }

    fn detectUnixColorSupport() bool {
        // Check TERM environment variable
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "TERM")) |term| {
            defer std.heap.page_allocator.free(term);

            // Terminals that definitely don't support color
            if (std.mem.eql(u8, term, "dumb") or
                std.mem.eql(u8, term, "unknown") or
                std.mem.eql(u8, term, ""))
            {
                return false;
            }

            // Terminals that definitely support color
            if (std.mem.indexOf(u8, term, "color") != null or
                std.mem.indexOf(u8, term, "xterm") != null or
                std.mem.indexOf(u8, term, "screen") != null or
                std.mem.indexOf(u8, term, "tmux") != null or
                std.mem.indexOf(u8, term, "rxvt") != null or
                std.mem.indexOf(u8, term, "konsole") != null or
                std.mem.indexOf(u8, term, "gnome") != null or
                std.mem.indexOf(u8, term, "kitty") != null or
                std.mem.indexOf(u8, term, "alacritty") != null or
                std.mem.indexOf(u8, term, "iterm") != null or
                std.mem.eql(u8, term, "ansi"))
            {
                return true;
            }
        } else |_| {}

        // Check COLORTERM environment variable
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "COLORTERM")) |colorterm| {
            defer std.heap.page_allocator.free(colorterm);
            return colorterm.len > 0;
        } else |_| {}

        // Check if we're in a known CI environment that supports colors
        if (detectCIColorSupport()) {
            return true;
        }

        // Check terminal capabilities via terminfo/termcap
        if (hasTerminalColorCapability()) {
            return true;
        }

        // Default to true for Unix-like systems if no clear indication otherwise
        return true;
    }

    fn detectCIColorSupport() bool {
        // GitHub Actions
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "GITHUB_ACTIONS")) |_| {
            return true;
        } else |_| {}

        // GitLab CI
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "GITLAB_CI")) |_| {
            return true;
        } else |_| {}

        // Travis CI
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "TRAVIS")) |_| {
            return true;
        } else |_| {}

        // CircleCI
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "CIRCLECI")) |_| {
            return true;
        } else |_| {}

        // Jenkins
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "JENKINS_URL")) |_| {
            return true;
        } else |_| {}

        // Azure DevOps
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "TF_BUILD")) |_| {
            return true;
        } else |_| {}

        // Buildkite
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "BUILDKITE")) |_| {
            return true;
        } else |_| {}

        return false;
    }

    fn hasTerminalColorCapability() bool {
        // This is a simplified check - in a full implementation you might
        // want to use terminfo/termcap libraries to query specific capabilities

        // Check for common color capability indicators
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "TERM_PROGRAM")) |term_program| {
            defer std.heap.page_allocator.free(term_program);

            // Known terminal programs that support color
            return std.mem.indexOf(u8, term_program, "iTerm") != null or
                std.mem.indexOf(u8, term_program, "Terminal") != null or
                std.mem.indexOf(u8, term_program, "Hyper") != null or
                std.mem.indexOf(u8, term_program, "vscode") != null;
        } else |_| {}

        return false;
    }

    pub fn parseArgs(self: *Cli, args: [][:0]u8) !CliArgs {
        var result = CliArgs{ .allocator = self.allocator };
        var i: usize = 1; // Skip program name

        while (i < args.len) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                result.help = true;
            } else if (std.mem.eql(u8, arg, "--no-color") or std.mem.eql(u8, arg, "-C")) {
                result.no_color = true;
            } else if (std.mem.eql(u8, arg, "--check-anomalies") or std.mem.eql(u8, arg, "-a")) {
                result.check_anomalies = true;
            } else if (std.mem.eql(u8, arg, "--check-compliance") or std.mem.eql(u8, arg, "--compliance")) {
                result.check_compliance = true;
            } else if (std.mem.eql(u8, arg, "--generate") or std.mem.eql(u8, arg, "-g")) {
                if (i + 1 >= args.len) {
                    return error.MissingGenerateArgument;
                }
                i += 1;
                const gen_str = args[i];
                if (std.mem.eql(u8, gen_str, "random")) {
                    result.generate_mode = .random;
                } else if (std.mem.eql(u8, gen_str, "variations")) {
                    result.generate_mode = .variations;
                } else {
                    return error.InvalidGenerateMode;
                }
            } else if (std.mem.eql(u8, arg, "--count") or std.mem.eql(u8, arg, "-n")) {
                if (i + 1 >= args.len) {
                    return error.MissingCountArgument;
                }
                i += 1;
                result.generate_count = try std.fmt.parseInt(u32, args[i], 10);
            } else if (std.mem.eql(u8, arg, "--seed") or std.mem.eql(u8, arg, "-s")) {
                if (i + 1 >= args.len) {
                    return error.MissingSeedArgument;
                }
                i += 1;
                result.generate_seed = try std.fmt.parseInt(u64, args[i], 10);
            } else if (std.mem.eql(u8, arg, "--file") or std.mem.eql(u8, arg, "-f")) {
                if (i + 1 >= args.len) {
                    return error.MissingFileArgument;
                }
                i += 1;
                result.file_path = args[i];
            } else if (std.mem.eql(u8, arg, "--csv")) {
                if (i + 1 >= args.len) {
                    return error.MissingCsvArgument;
                }
                i += 1;
                result.csv_path = args[i];
            } else if (std.mem.eql(u8, arg, "--csv-output")) {
                if (i + 1 >= args.len) {
                    return error.MissingCsvOutputArgument;
                }
                i += 1;
                result.csv_output_path = args[i];
            } else if (std.mem.eql(u8, arg, "--column")) {
                if (i + 1 >= args.len) {
                    return error.MissingColumnArgument;
                }
                i += 1;
                result.csv_column = args[i];
            } else if (std.mem.eql(u8, arg, "--output-columns")) {
                if (i + 1 >= args.len) {
                    return error.MissingOutputColumnsArgument;
                }
                i += 1;
                // Parse comma-separated list of output columns
                const cols_str = args[i];
                var cols = std.ArrayList([]const u8).init(self.allocator);
                var col_iter = std.mem.splitScalar(u8, cols_str, ',');
                while (col_iter.next()) |col| {
                    const trimmed = std.mem.trim(u8, col, " \t");
                    try cols.append(trimmed);
                }
                result.csv_output_columns = try cols.toOwnedSlice();
            } else if (std.mem.eql(u8, arg, "--csv-no-header")) {
                result.csv_no_header = true;
            } else if (std.mem.eql(u8, arg, "--identify-units")) {
                result.identify_units = true;
            } else if (std.mem.eql(u8, arg, "--borehole-id")) {
                if (i + 1 >= args.len) {
                    return error.MissingBoreholeIdArgument;
                }
                i += 1;
                result.borehole_id_column = args[i];
            } else if (std.mem.eql(u8, arg, "--depth-top")) {
                if (i + 1 >= args.len) {
                    return error.MissingDepthTopArgument;
                }
                i += 1;
                result.depth_top_column = args[i];
            } else if (std.mem.eql(u8, arg, "--depth-bottom")) {
                if (i + 1 >= args.len) {
                    return error.MissingDepthBottomArgument;
                }
                i += 1;
                result.depth_bottom_column = args[i];
            } else if (std.mem.eql(u8, arg, "--spatial-analysis")) {
                result.spatial_analysis = true;
            } else if (std.mem.eql(u8, arg, "--x-column")) {
                if (i + 1 >= args.len) {
                    return error.MissingXColumnArgument;
                }
                i += 1;
                result.x_column = args[i];
            } else if (std.mem.eql(u8, arg, "--y-column")) {
                if (i + 1 >= args.len) {
                    return error.MissingYColumnArgument;
                }
                i += 1;
                result.y_column = args[i];
            } else if (std.mem.eql(u8, arg, "--z-column")) {
                if (i + 1 >= args.len) {
                    return error.MissingZColumnArgument;
                }
                i += 1;
                result.z_column = args[i];
            } else if (std.mem.eql(u8, arg, "--spatial-cluster")) {
                result.spatial_cluster = true;
            } else if (std.mem.eql(u8, arg, "--cluster-epsilon")) {
                if (i + 1 >= args.len) {
                    return error.MissingClusterEpsilonArgument;
                }
                i += 1;
                result.cluster_epsilon = try std.fmt.parseFloat(f64, args[i]);
            } else if (std.mem.eql(u8, arg, "--cluster-min-points")) {
                if (i + 1 >= args.len) {
                    return error.MissingClusterMinPointsArgument;
                }
                i += 1;
                result.cluster_min_points = try std.fmt.parseInt(usize, args[i], 10);
            } else if (std.mem.eql(u8, arg, "--excel-output")) {
                result.excel_output = true;
            } else if (std.mem.eql(u8, arg, "--freeze-header")) {
                result.freeze_header = true;
            } else if (std.mem.eql(u8, arg, "--auto-filter")) {
                result.auto_filter = true;
            } else if (std.mem.eql(u8, arg, "--sheet-name")) {
                if (i + 1 >= args.len) {
                    return error.MissingSheetNameArgument;
                }
                i += 1;
                result.sheet_name = args[i];
            } else if (std.mem.eql(u8, arg, "--mode") or std.mem.eql(u8, arg, "-m")) {
                if (i + 1 >= args.len) {
                    return error.MissingModeArgument;
                }
                i += 1;
                const mode_str = args[i];
                if (std.mem.eql(u8, mode_str, "compact")) {
                    result.output_mode = .compact;
                } else if (std.mem.eql(u8, mode_str, "verbose")) {
                    result.output_mode = .verbose;
                } else if (std.mem.eql(u8, mode_str, "pretty")) {
                    result.output_mode = .pretty;
                } else if (std.mem.eql(u8, mode_str, "summary")) {
                    result.output_mode = .summary;
                } else {
                    return error.InvalidOutputMode;
                }
            } else if (std.mem.startsWith(u8, arg, "-")) {
                return error.UnknownOption;
            } else {
                // Treat as description
                result.description = arg;
            }

            i += 1;
        }

        return result;
    }

    pub fn run(self: *Cli, args: CliArgs) !void {
        if (args.help) {
            try self.printHelp();
            return;
        }

        // Handle CSV processing mode
        if (args.csv_path) |csv_path| {
            try self.processCsv(csv_path, args);
            return;
        }

        // Handle generation mode
        if (args.generate_mode) |gen_mode| {
            try self.handleGenerate(gen_mode, args);
            return;
        }

        if (args.description) |desc| {
            try self.parseAndPrint(desc, args.output_mode, args.no_color, args.check_anomalies);
            if (args.check_compliance) {
                try self.checkCompliance(desc);
            }
        } else if (args.file_path) |file_path| {
            try self.parseFile(file_path, args.output_mode, args.no_color, args.check_anomalies);
        } else {
            try self.printHelp();
        }
    }

    fn processCsv(self: *Cli, csv_path: []const u8, args: CliArgs) !void {
        const csv_processor = @import("csv_processor.zig");

        // Validate required arguments
        if (args.csv_column == null) {
            std.debug.print("Error: --column is required when using --csv\n", .{});
            return error.MissingCsvColumn;
        }

        const output_path = args.csv_output_path orelse {
            std.debug.print("Error: --csv-output is required when using --csv\n", .{});
            return error.MissingCsvOutput;
        };

        // For unit identification, validate additional columns
        if (args.identify_units) {
            if (args.borehole_id_column == null) {
                std.debug.print("Error: --borehole-id is required when using --identify-units\n", .{});
                return error.MissingBoreholeIdColumn;
            }
            if (args.depth_top_column == null) {
                std.debug.print("Error: --depth-top is required when using --identify-units\n", .{});
                return error.MissingDepthTopColumn;
            }
            if (args.depth_bottom_column == null) {
                std.debug.print("Error: --depth-bottom is required when using --identify-units\n", .{});
                return error.MissingDepthBottomColumn;
            }
        }

        // For spatial analysis, validate additional columns
        if (args.spatial_analysis) {
            if (args.x_column == null or args.y_column == null or args.z_column == null) {
                std.debug.print("Error: --x-column, --y-column, and --z-column are required when using --spatial-analysis\n", .{});
                return error.MissingSpatialColumns;
            }
        }

        const output_columns = if (args.identify_units)
            &[_][]const u8{} // Empty for unit identification - we'll handle differently
        else
            args.csv_output_columns orelse {
                std.debug.print("Error: --output-columns is required when using --csv\n", .{});
                return error.MissingOutputColumns;
            };

        // Process CSV file
        var processor = csv_processor.CsvProcessor.init(self.allocator);
        const options = csv_processor.CsvOptions{
            .input_column = args.csv_column.?,
            .output_columns = output_columns,
            .has_header = !args.csv_no_header,
            .delimiter = ',',
            .identify_units = args.identify_units,
            .borehole_id_column = args.borehole_id_column,
            .depth_top_column = args.depth_top_column,
            .depth_bottom_column = args.depth_bottom_column,
            .spatial_analysis = args.spatial_analysis,
            .x_column = args.x_column,
            .y_column = args.y_column,
            .z_column = args.z_column,
            .spatial_cluster = args.spatial_cluster,
            .cluster_epsilon = args.cluster_epsilon,
            .cluster_min_points = args.cluster_min_points,
            .excel_format = args.excel_output,
            .freeze_header = args.freeze_header,
            .auto_filter = args.auto_filter,
            .sheet_name = args.sheet_name,
        };

        try processor.processFile(csv_path, output_path, options);

        const stdout = std.io.getStdOut().writer();
        try stdout.print("Successfully processed CSV: {s} -> {s}\n", .{ csv_path, output_path });
    }

    fn parseAndPrint(self: *Cli, description: []const u8, mode: CliArgs.OutputMode, no_color: bool, check_anomalies: bool) !void {
        const result = try self.parser.parse(description);
        defer result.deinit(self.allocator);

        try self.printResult(result, mode, no_color);

        // Check for anomalies if requested
        if (check_anomalies) {
            try self.checkAndPrintAnomalies(&result);
        }
    }

    fn checkAndPrintAnomalies(self: *Cli, description: *const bs5930.SoilDescription) !void {
        var detector = bs5930.AnomalyDetector.init(self.allocator);
        var anomaly_result = try detector.detect(description);
        defer anomaly_result.deinit(self.allocator);

        const stdout = std.io.getStdOut().writer();

        if (anomaly_result.has_anomalies) {
            try stdout.print("\nAnomalies Detected (Severity: {s}):\n", .{anomaly_result.overall_severity.toString()});
            for (anomaly_result.anomalies) |anomaly| {
                try stdout.print("  [{s}] {s}: {s}\n", .{
                    anomaly.severity.toString(),
                    anomaly.anomaly_type.toString(),
                    anomaly.description,
                });
                if (anomaly.suggestion) |suggestion| {
                    try stdout.print("    Suggestion: {s}\n", .{suggestion});
                }
            }
        } else {
            try stdout.print("\nNo anomalies detected.\n", .{});
        }
    }

    fn checkCompliance(self: *Cli, description_text: []const u8) !void {
        // Parse the description first
        const result = try self.parser.parse(description_text);
        defer result.deinit(self.allocator);

        var checker = bs5930.ComplianceChecker.init(self.allocator);
        var report = try checker.check(&result);
        defer report.deinit(self.allocator);

        const stdout = std.io.getStdOut().writer();
        try stdout.writeAll("\n");

        const formatted = try report.format(self.allocator);
        defer self.allocator.free(formatted);

        try stdout.writeAll(formatted);
    }

    fn handleGenerate(self: *Cli, gen_mode: CliArgs.GenerateMode, args: CliArgs) !void {
        const stdout = std.io.getStdOut().writer();

        switch (gen_mode) {
            .random => {
                // Generate random descriptions
                var i: u32 = 0;
                while (i < args.generate_count) : (i += 1) {
                    const seed = if (args.generate_seed == 0)
                        @as(u64, @intCast(std.time.timestamp())) + i
                    else
                        args.generate_seed + i;

                    const generated = try bs5930.generateRandom(self.allocator, seed);
                    defer self.allocator.free(generated);
                    try stdout.print("{s}\n", .{generated});
                }
            },
            .variations => {
                // Generate variations of a description
                if (args.description) |desc| {
                    const result = try self.parser.parse(desc);
                    defer result.deinit(self.allocator);

                    const variations = try bs5930.generateVariations(result, self.allocator);
                    defer {
                        for (variations) |v| self.allocator.free(v);
                        self.allocator.free(variations);
                    }

                    for (variations) |variation| {
                        try stdout.print("{s}\n", .{variation});
                    }
                } else {
                    try stdout.print("Error: --generate variations requires a description argument\n", .{});
                    return error.MissingDescription;
                }
            },
        }
    }

    fn parseFile(self: *Cli, file_path: []const u8, mode: CliArgs.OutputMode, no_color: bool, check_anomalies: bool) !void {
        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("Error: File not found: {s}\n", .{file_path});
                return;
            },
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(content);

        var lines = std.mem.splitAny(u8, content, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) continue;

            try self.parseAndPrint(trimmed, mode, no_color, check_anomalies);
        }
    }

    fn parseStdin(self: *Cli, mode: CliArgs.OutputMode, no_color: bool) !void {
        const stdin = std.io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;

        while (try stdin.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) continue;

            try self.parseAndPrint(trimmed, mode, no_color);
        }
    }

    fn printResult(self: *Cli, result: bs5930.SoilDescription, mode: CliArgs.OutputMode, no_color: bool) !void {
        const stdout = std.io.getStdOut().writer();

        switch (mode) {
            .compact => {
                const json = try result.toJson(self.allocator);
                defer self.allocator.free(json);
                try stdout.print("{s}\n", .{json});
            },
            .pretty => {
                const use_colors = self.use_colors and !no_color;
                const json = try result.toColorizedJson(self.allocator, use_colors);
                defer self.allocator.free(json);
                try stdout.print("{s}\n", .{json});
            },
            .summary => {
                try stdout.print("Description: {s}\n", .{result.raw_description});
                if (result.consistency) |c| {
                    try stdout.print("Consistency: {s}\n", .{c.toString()});
                }
                if (result.density) |d| {
                    try stdout.print("Density: {s}\n", .{d.toString()});
                }
                if (result.primary_soil_type) |pst| {
                    try stdout.print("Primary Soil: {s}\n", .{pst.toString()});
                }
                if (result.color) |color| {
                    try stdout.print("Color: {s}\n", .{color.toString()});
                }
                if (result.moisture_content) |moisture| {
                    try stdout.print("Moisture Content: {s}\n", .{moisture.toString()});
                }
                if (result.plasticity_index) |plasticity| {
                    try stdout.print("Plasticity Index: {s}\n", .{plasticity.toString()});
                }
                if (result.particle_size) |particle_size| {
                    try stdout.print("Particle Size: {s}\n", .{particle_size.toString()});
                }
                if (result.strength_parameters) |sp| {
                    const sp_str = try sp.toString(self.allocator);
                    defer self.allocator.free(sp_str);
                    try stdout.print("Strength: {s}\n", .{sp_str});
                }

                if (result.constituent_guidance) |cg| {
                    try stdout.print("Constituent Proportions:\n", .{});
                    for (cg.constituents) |constituent| {
                        const constituent_str = try constituent.toString(self.allocator);
                        defer self.allocator.free(constituent_str);
                        try stdout.print("  - {s}\n", .{constituent_str});
                    }
                }
                try stdout.print("Confidence: {d:.2}\n", .{result.confidence});
                try stdout.print("Valid: {s}\n", .{if (result.is_valid) "Yes" else "No"});

                // Show validation warnings if invalid
                if (!result.is_valid and result.warnings.len > 0) {
                    try stdout.print("Issues:\n", .{});
                    for (result.warnings) |warning| {
                        try stdout.print("  - {s}\n", .{warning});
                    }
                }

                try stdout.print("\n", .{});
            },
            .verbose => {
                const json = try result.toJson(self.allocator);
                defer self.allocator.free(json);
                try stdout.print("{s}\n", .{json});
                try stdout.print("Confidence: {d:.2}\n", .{result.confidence});
                if (result.warnings.len > 0) {
                    try stdout.print("Warnings:\n", .{});
                    for (result.warnings) |warning| {
                        try stdout.print("  - {s}\n", .{warning});
                    }
                }
            },
        }
    }

    fn printHelp(self: *Cli) !void {
        _ = self;
        const stdout = std.io.getStdOut().writer();
        try stdout.print(
            \\litholog - Soil and rock description parser for UK practice (BS 5930)
            \\
            \\USAGE:
            \\    litholog [OPTIONS] [DESCRIPTION]        Parse a single description
            \\    litholog --file <FILE> [OPTIONS]        Parse descriptions from file
            \\    litholog --csv <FILE> [CSV OPTIONS]     Process CSV/Excel file
            \\    litholog tui                             Interactive mode (TUI)
            \\    cat descriptions.txt | litholog [OPTIONS]   Parse from stdin
            \\
            \\OPTIONS:
            \\    -h, --help              Show this help message
            \\    -f, --file <FILE>       Parse descriptions from file (one per line)
            \\    -m, --mode <MODE>       Output format (default: compact)
            \\    -C, --no-color          Disable colorized output
            \\    -a, --check-anomalies   Check for anomalies in descriptions
            \\    --check-compliance      Check BS 5930:2015 compliance
            \\    -g, --generate <MODE>   Generate descriptions (random|variations)
            \\    -n, --count <N>         Number of descriptions to generate (default: 1)
            \\    -s, --seed <SEED>       Seed for random generation (default: timestamp)
            \\
            \\CSV OPTIONS:
            \\    --csv <FILE>            Input CSV file to process
            \\    --csv-output <FILE>     Output CSV file with results
            \\    --column <NAME|INDEX>   Column name (or 0-based index) containing descriptions
            \\    --output-columns <COLS> Comma-separated list of result columns to add
            \\    --csv-no-header         Treat file as having no header row
            \\
            \\EXCEL OPTIONS:
            \\    --excel-output          Export to Excel format (.xlsx)
            \\    --freeze-header         Freeze header row in Excel
            \\    --auto-filter           Enable auto-filter in Excel
            \\    --sheet-name <NAME>     Set worksheet name (default: Sheet1)
            \\
            \\UNIT IDENTIFICATION OPTIONS:
            \\    --identify-units        Identify geological units across boreholes
            \\    --borehole-id <COL>     Column name (or index) for borehole ID
            \\    --depth-top <COL>       Column name (or index) for depth top (m)
            \\    --depth-bottom <COL>    Column name (or index) for depth bottom (m)
            \\
            \\SPATIAL ANALYSIS OPTIONS:
            \\    --spatial-analysis      Enable spatial analysis with X,Y,Z coordinates
            \\    --x-column <COL>        Column name for X coordinate (easting, m)
            \\    --y-column <COL>        Column name for Y coordinate (northing, m)
            \\    --z-column <COL>        Column name for Z coordinate (elevation, m)
            \\    --spatial-cluster       Perform spatial clustering (DBSCAN)
            \\    --cluster-epsilon <D>   Maximum distance for clustering (default: 10.0 m)
            \\    --cluster-min-points <N> Min points for cluster core (default: 3)
            \\
            \\OUTPUT MODES:
            \\    compact                 Single-line JSON (machine-readable)
            \\    verbose                 JSON with confidence and warnings
            \\    pretty                  Colorized, indented JSON (like jq)
            \\    summary                 Human-readable key information
            \\
            \\GENERATE MODES:
            \\    random                  Generate random valid descriptions
            \\    variations              Generate variations of input description
            \\
            \\CSV OUTPUT COLUMNS:
            \\    material_type           Soil or rock classification
            \\    consistency             Consistency (very soft to hard)
            \\    density                 Density (very loose to very dense)
            \\    primary_soil_type       Primary soil type (clay, silt, sand, gravel)
            \\    primary_rock_type       Primary rock type (limestone, sandstone, etc.)
            \\    rock_strength           Rock strength (very weak to extremely strong)
            \\    weathering_grade        Weathering grade (fresh to completely weathered)
            \\    color                   Color description
            \\    moisture_content        Moisture content description
            \\    confidence              Confidence score (0-1)
            \\    is_valid                Validation status (true/false)
            \\    strength_lower          Lower bound of strength parameter
            \\    strength_upper          Upper bound of strength parameter
            \\    strength_typical        Typical strength value
            \\    strength_unit           Unit of strength measurement
            \\    x_coord                 X coordinate (easting)
            \\    y_coord                 Y coordinate (northing)
            \\    z_coord                 Z coordinate (elevation)
            \\    thickness               Unit thickness (m)
            \\    mid_depth               Unit midpoint depth (m)
            \\    elevation               Elevation at unit midpoint (m)
            \\    json                    Full JSON output
            \\
            \\ENVIRONMENT VARIABLES:
            \\    NO_COLOR                Disable colors (universal standard)
            \\    FORCE_COLOR             Force colors even when not detected
            \\    TERM                    Terminal type (affects color detection)
            \\
            \\EXAMPLES:
            \\    # Basic usage
            \\    litholog "Firm to stiff slightly sandy gravelly CLAY"
            \\    
            \\    # Different output formats
            \\    litholog "Dense SAND" --mode summary
            \\    litholog "Strong LIMESTONE" --mode pretty
            \\    litholog "Soft CLAY" --mode compact > data.json
            \\    
            \\    # CSV processing
            \\    litholog --csv input.csv --csv-output output.csv \
            \\             --column "Description" \
            \\             --output-columns "material_type,consistency,primary_soil_type,confidence"
            \\    
            \\    # CSV with index-based column (0-based)
            \\    litholog --csv data.csv --csv-output results.csv \
            \\             --column 2 \
            \\             --output-columns "material_type,json"
            \\    
            \\    # CSV without header row
            \\    litholog --csv input.csv --csv-output output.csv \
            \\             --column 0 --csv-no-header \
            \\             --output-columns "primary_soil_type,density"
            \\    
            \\    # Excel export
            \\    litholog --csv input.csv --csv-output output.xlsx \
            \\             --column "Description" \
            \\             --output-columns "material_type,consistency,confidence" \
            \\             --excel-output --freeze-header --auto-filter
            \\    
            \\    # Excel with custom sheet name
            \\    litholog --csv input.csv --csv-output output.xlsx \
            \\             --column "Description" \
            \\             --output-columns "material_type,primary_soil_type" \
            \\             --excel-output --sheet-name "Parsed_Results"
            \\    
            \\    # Geological unit identification
            \\    litholog --csv boreholes.csv --csv-output results.csv \
            \\             --column "Description" \
            \\             --identify-units \
            \\             --borehole-id "BH_ID" \
            \\             --depth-top "Depth_Top" \
            \\             --depth-bottom "Depth_Bottom"
            \\    
            \\    # Anomaly detection
            \\    litholog "Dense CLAY" --check-anomalies
            \\    litholog --file descriptions.txt --check-anomalies --mode summary
            \\    
            \\    # Compliance checking
            \\    litholog "Firm CLAY" --check-compliance
            \\    litholog "Medium firm brown CLAY" --check-compliance
            \\    litholog "Soft GRAVEL" --check-compliance
            \\    
            \\    # Generate random descriptions
            \\    litholog --generate random --count 5
            \\    litholog --generate random --count 10 --seed 12345
            \\    
            \\    # Generate variations
            \\    litholog "Firm CLAY" --generate variations
            \\    litholog "Dense SAND" --generate variations --mode pretty
            \\    
            \\    # File processing
            \\    litholog --file descriptions.txt --mode summary
            \\    litholog --file data.txt --mode pretty --no-color
            \\    
            \\    # Interactive mode
            \\    litholog tui
            \\    
            \\    # Piping and redirection
            \\    echo "Medium dense SAND" | litholog --mode pretty
            \\    litholog "Firm CLAY" > output.json
            \\    
            \\    # Color control
            \\    NO_COLOR=1 litholog "Dense GRAVEL" --mode pretty
            \\    FORCE_COLOR=1 litholog "Soft CLAY" --mode pretty > colored.json
            \\
            \\SUPPORTED MATERIALS:
            \\    Soils: CLAY, SILT, SAND, GRAVEL and combinations
            \\    Rocks: LIMESTONE, SANDSTONE, MUDSTONE, GRANITE, etc.
            \\    
            \\FEATURES:
            \\    • Automatic color detection (TTY, terminal type, OS)
            \\    • Cross-platform compatibility (Windows, Linux, macOS)
            \\    • BS 5930 compliant parsing and terminology
            \\    • Strength parameter estimation with confidence
            \\    • Constituent proportion analysis
            \\    • Validation and warning system
            \\    • Anomaly detection with severity levels
            \\    • Random description generation
            \\    • Description variation generation
            \\    • CSV/Excel file processing with configurable output columns
            \\
        , .{});
    }
};
