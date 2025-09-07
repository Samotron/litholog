const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");

pub const CliArgs = struct {
    description: ?[]const u8 = null,
    file_path: ?[]const u8 = null,
    output_mode: OutputMode = .compact,
    help: bool = false,

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

    pub fn init(allocator: std.mem.Allocator) Cli {
        return Cli{
            .allocator = allocator,
            .parser = bs5930.Parser.init(allocator),
        };
    }

    pub fn parseArgs(self: *Cli, args: [][:0]u8) !CliArgs {
        _ = self;
        var result = CliArgs{};
        var i: usize = 1; // Skip program name

        while (i < args.len) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                result.help = true;
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
            try self.parseAndPrint(desc, args.output_mode);
        } else if (args.file_path) |file_path| {
            try self.parseFile(file_path, args.output_mode);
        } else {
            try self.printHelp();
        }
    }

    fn parseAndPrint(self: *Cli, description: []const u8, mode: CliArgs.OutputMode) !void {
        const result = try self.parser.parse(description);
        defer result.deinit(self.allocator);

        try self.printResult(result, mode);
    }

    fn parseFile(self: *Cli, file_path: []const u8, mode: CliArgs.OutputMode) !void {
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

            try self.parseAndPrint(trimmed, mode);
        }
    }

    fn parseStdin(self: *Cli, mode: CliArgs.OutputMode) !void {
        const stdin = std.io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;

        while (try stdin.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) continue;

            try self.parseAndPrint(trimmed, mode);
        }
    }

    fn printResult(self: *Cli, result: bs5930.SoilDescription, mode: CliArgs.OutputMode) !void {
        const stdout = std.io.getStdOut().writer();

        switch (mode) {
            .compact => {
                const json = try result.toJson(self.allocator);
                defer self.allocator.free(json);
                try stdout.print("{s}\n", .{json});
            },
            .pretty => {
                const json = try result.toJson(self.allocator);
                defer self.allocator.free(json);
                // TODO: Implement pretty printing with indentation
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
                if (result.secondary_constituents.len > 0) {
                    try stdout.print("Secondary Constituents:\n", .{});
                    for (result.secondary_constituents) |sc| {
                        const sc_str = try sc.toString(self.allocator);
                        defer self.allocator.free(sc_str);
                        try stdout.print("  - {s}\n", .{sc_str});
                    }
                }
                try stdout.print("Confidence: {d:.2}\n\n", .{result.confidence});
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
            \\    litholog [OPTIONS] [DESCRIPTION]
            \\    litholog --file <FILE> [OPTIONS]
            \\    cat descriptions.txt | litholog [OPTIONS]
            \\
            \\OPTIONS:
            \\    -h, --help              Show this help message
            \\    -f, --file <FILE>       Parse descriptions from file
            \\    -m, --mode <MODE>       Output mode: compact, verbose, pretty, summary
            \\
            \\EXAMPLES:
            \\    litholog "Firm to stiff slightly sandy gravelly CLAY"
            \\    litholog --file descriptions.txt --mode summary
            \\    echo "Dense SAND" | litholog --mode pretty
            \\
        , .{});
    }
};
