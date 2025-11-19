const std = @import("std");
const cli = @import("cli.zig");
const tui = @import("tui.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Check if TUI mode is requested
    if (args.len > 1 and std.mem.eql(u8, args[1], "tui")) {
        var litholog_tui = tui.Tui.init(allocator) catch |err| {
            std.debug.print("Error initializing TUI: {}\n", .{err});
            return;
        };
        defer litholog_tui.deinit();

        litholog_tui.run() catch |err| {
            std.debug.print("Error running TUI: {}\n", .{err});
            return;
        };
        return;
    }

    // Default to CLI mode
    var litholog_cli = cli.Cli.init(allocator);
    var cli_args = litholog_cli.parseArgs(args) catch |err| switch (err) {
        error.MissingFileArgument => {
            std.debug.print("Error: --file option requires a file path\n", .{});
            return;
        },
        error.MissingModeArgument => {
            std.debug.print("Error: --mode option requires a mode (compact, verbose, pretty, summary)\n", .{});
            return;
        },
        error.InvalidOutputMode => {
            std.debug.print("Error: Invalid output mode. Use: compact, verbose, pretty, or summary\n", .{});
            return;
        },
        error.UnknownOption => {
            std.debug.print("Error: Unknown option. Use --help for usage information\n", .{});
            return;
        },
        else => return err,
    };
    defer cli_args.deinit();

    try litholog_cli.run(cli_args);
}
