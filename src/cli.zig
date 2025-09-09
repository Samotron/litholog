const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");
const builtin = @import("builtin");

pub const CliArgs = struct {
    description: ?[]const u8 = null,
    file_path: ?[]const u8 = null,
    output_mode: OutputMode = .compact,
    help: bool = false,
    no_color: bool = false,

    pub const OutputMode = enum {
        compact,
        verbose,
        pretty,
        summary,
    };
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
        _ = self;
        var result = CliArgs{};
        var i: usize = 1; // Skip program name

        while (i < args.len) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                result.help = true;
            } else if (std.mem.eql(u8, arg, "--no-color") or std.mem.eql(u8, arg, "-C")) {
                result.no_color = true;
            } else if (std.mem.eql(u8, arg, "--file") or std.mem.eql(u8, arg, "-f")) {
                if (i + 1 >= args.len) {
                    return error.MissingFileArgument;
                }
                i += 1;
                result.file_path = args[i];
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

        if (args.description) |desc| {
            try self.parseAndPrint(desc, args.output_mode, args.no_color);
        } else if (args.file_path) |file_path| {
            try self.parseFile(file_path, args.output_mode, args.no_color);
        } else {
            try self.printHelp();
        }
    }

    fn parseAndPrint(self: *Cli, description: []const u8, mode: CliArgs.OutputMode, no_color: bool) !void {
        const result = try self.parser.parse(description);
        defer result.deinit(self.allocator);

        try self.printResult(result, mode, no_color);
    }

    fn parseFile(self: *Cli, file_path: []const u8, mode: CliArgs.OutputMode, no_color: bool) !void {
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

            try self.parseAndPrint(trimmed, mode, no_color);
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
            \\    litholog tui                             Interactive mode (TUI)
            \\    cat descriptions.txt | litholog [OPTIONS]   Parse from stdin
            \\
            \\OPTIONS:
            \\    -h, --help              Show this help message
            \\    -f, --file <FILE>       Parse descriptions from file (one per line)
            \\    -m, --mode <MODE>       Output format (default: compact)
            \\    -C, --no-color          Disable colorized output
            \\
            \\OUTPUT MODES:
            \\    compact                 Single-line JSON (machine-readable)
            \\    verbose                 JSON with confidence and warnings
            \\    pretty                  Colorized, indented JSON (like jq)
            \\    summary                 Human-readable key information
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
            \\
        , .{});
    }
};
