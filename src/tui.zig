const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");
const builtin = @import("builtin");

pub const Tui = struct {
    allocator: std.mem.Allocator,
    parser: bs5930.Parser,
    use_colors: bool,

    pub fn init(allocator: std.mem.Allocator) !Tui {
        return Tui{
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

    fn printColored(self: *Tui, writer: anytype, comptime color_code: []const u8, comptime fmt: []const u8, args: anytype) !void {
        if (self.use_colors) {
            try writer.print(color_code ++ fmt ++ "\x1b[0m", args);
        } else {
            try writer.print(fmt, args);
        }
    }

    pub fn deinit(self: *Tui) void {
        _ = self;
    }

    pub fn run(self: *Tui) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        // Print welcome message
        try self.printColored(stdout, "\x1b[1;34m", "+---------------------------------------------------------------------+\n", .{});
        try self.printColored(stdout, "\x1b[1;34m", "|              litholog - Soil & Rock Description Parser             |\n", .{});
        try self.printColored(stdout, "\x1b[1;34m", "+---------------------------------------------------------------------+\n\n", .{});

        try self.printColored(stdout, "\x1b[90m", "Enter soil or rock descriptions to parse. Type 'quit' or 'exit' to quit.\n", .{});
        try self.printColored(stdout, "\x1b[90m", "Soil examples: 'Firm CLAY', 'Dense sandy GRAVEL', 'Soft to firm silty CLAY'\n", .{});
        try self.printColored(stdout, "\x1b[90m", "Rock examples: 'Strong LIMESTONE', 'Moderately strong weathered SANDSTONE'\n\n", .{});

        var line_buffer: [256]u8 = undefined;

        while (true) {
            // Prompt
            try self.printColored(stdout, "\x1b[1;32m", "litholog> ", .{});

            // Read line
            if (try stdin.readUntilDelimiterOrEof(line_buffer[0..], '\n')) |input| {
                const trimmed_input = std.mem.trim(u8, input, " \t\r\n");

                // Check for quit commands
                if (std.mem.eql(u8, trimmed_input, "quit") or
                    std.mem.eql(u8, trimmed_input, "exit") or
                    std.mem.eql(u8, trimmed_input, "q"))
                {
                    try self.printColored(stdout, "\x1b[90m", "Goodbye!\n", .{});
                    break;
                }

                // Skip empty input
                if (trimmed_input.len == 0) {
                    continue;
                }

                // Parse the input
                try self.parseAndDisplay(trimmed_input, stdout);
                try stdout.print("\n", .{});
            } else {
                // EOF reached (Ctrl+D)
                try self.printColored(stdout, "\x1b[90m", "\nGoodbye!\n", .{});
                break;
            }
        }
    }

    fn parseAndDisplay(self: *Tui, input: []const u8, stdout: anytype) !void {
        const result = self.parser.parse(input) catch |err| {
            try self.printColored(stdout, "\x1b[1;31m", "Error parsing input: {}\n", .{err});
            return;
        };
        defer result.deinit(self.allocator);

        // Display results with nice formatting
        try self.printColored(stdout, "\x1b[1;33m", "\nParsed Results:\n", .{});
        try stdout.print("---------------------------------------------------------------------\n", .{});

        try self.printColored(stdout, "\x1b[1;36m", "Description: ", .{});
        try stdout.print("{s}\n", .{result.raw_description});

        try self.printColored(stdout, "\x1b[1;36m", "Material Type: ", .{});
        try stdout.print("{s}\n", .{result.material_type.toString()});

        // Soil properties
        if (result.material_type == .soil) {
            if (result.consistency) |consistency| {
                try self.printColored(stdout, "\x1b[1;36m", "Consistency: ", .{});
                try stdout.print("{s}\n", .{consistency.toString()});
            }

            if (result.density) |density| {
                try self.printColored(stdout, "\x1b[1;36m", "Density: ", .{});
                try stdout.print("{s}\n", .{density.toString()});
            }

            if (result.primary_soil_type) |soil_type| {
                try self.printColored(stdout, "\x1b[1;36m", "Primary Soil: ", .{});
                try stdout.print("{s}\n", .{soil_type.toString()});
            }
        }

        // Rock properties
        if (result.material_type == .rock) {
            if (result.rock_strength) |strength| {
                try self.printColored(stdout, "\x1b[1;36m", "Rock Strength: ", .{});
                try stdout.print("{s}\n", .{strength.toString()});
            }

            if (result.weathering_grade) |weathering| {
                try self.printColored(stdout, "\x1b[1;36m", "Weathering Grade: ", .{});
                try stdout.print("{s}\n", .{weathering.toString()});
            }

            if (result.rock_structure) |structure| {
                try self.printColored(stdout, "\x1b[1;36m", "Rock Structure: ", .{});
                try stdout.print("{s}\n", .{structure.toString()});
            }

            if (result.primary_rock_type) |rock_type| {
                try self.printColored(stdout, "\x1b[1;36m", "Primary Rock: ", .{});
                try stdout.print("{s}\n", .{rock_type.toString()});
            }
        }

        if (result.secondary_constituents.len > 0) {
            try self.printColored(stdout, "\x1b[1;36m", "Secondary Constituents:\n", .{});
            for (result.secondary_constituents) |sc| {
                const sc_str = try sc.toString(self.allocator);
                defer self.allocator.free(sc_str);
                try stdout.print("  - {s}\n", .{sc_str});
            }
        }

        // Display strength parameters if available
        if (result.strength_parameters) |sp| {
            const sp_str = try sp.toString(self.allocator);
            defer self.allocator.free(sp_str);
            try self.printColored(stdout, "\x1b[1;36m", "Strength Parameters: ", .{});
            try stdout.print("{s}\n", .{sp_str});
        }

        // Display enhanced geological features
        if (result.color) |color| {
            try self.printColored(stdout, "\x1b[1;36m", "Color: ", .{});
            try stdout.print("{s}\n", .{color.toString()});
        }

        if (result.moisture_content) |moisture| {
            try self.printColored(stdout, "\x1b[1;36m", "Moisture Content: ", .{});
            try stdout.print("{s}\n", .{moisture.toString()});
        }

        if (result.plasticity_index) |plasticity| {
            try self.printColored(stdout, "\x1b[1;36m", "Plasticity Index: ", .{});
            try stdout.print("{s}\n", .{plasticity.toString()});
        }

        if (result.particle_size) |particle_size| {
            try self.printColored(stdout, "\x1b[1;36m", "Particle Size: ", .{});
            try stdout.print("{s}\n", .{particle_size.toString()});
        }

        try self.printColored(stdout, "\x1b[1;36m", "Confidence: ", .{});
        try stdout.print("{d:.2}\n", .{result.confidence});

        // Display validity status with color coding
        try self.printColored(stdout, "\x1b[1;36m", "Valid: ", .{});
        if (result.is_valid) {
            try self.printColored(stdout, "\x1b[1;32m", "Yes\n", .{});
        } else {
            try self.printColored(stdout, "\x1b[1;31m", "No\n", .{});

            // Show validation issues if invalid
            if (result.warnings.len > 0) {
                try self.printColored(stdout, "\x1b[1;36m", "Issues:\n", .{});
                for (result.warnings) |warning| {
                    try self.printColored(stdout, "\x1b[31m", "  - ", .{});
                    try stdout.print("{s}\n", .{warning});
                }
            }
        }

        try stdout.print("---------------------------------------------------------------------\n", .{});
    }
};
