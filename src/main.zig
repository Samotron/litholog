const std = @import("std");
const cli = @import("cli.zig");
const tui = @import("tui.zig");
const web = @import("web.zig");
const builtin = @import("builtin");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Check if launched via double-click (no args and stdin is not a TTY)
    const launched_via_doubleclick = args.len == 1 and !isStdinTTY();

    if (launched_via_doubleclick) {
        // Launch web UI
        var server = try web.WebServer.init(allocator, 8080);
        defer server.deinit();
        try server.start();
        return;
    }

    // Check if web mode is explicitly requested
    if (args.len > 1 and (std.mem.eql(u8, args[1], "web") or std.mem.eql(u8, args[1], "gui"))) {
        var server = try web.WebServer.init(allocator, 8080);
        defer server.deinit();
        try server.start();
        return;
    }

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

fn isStdinTTY() bool {
    if (builtin.os.tag == .windows) {
        const INVALID_HANDLE_VALUE = @as(std.os.windows.HANDLE, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
        const handle = std.io.getStdIn().handle;
        if (handle == INVALID_HANDLE_VALUE) return false;

        var mode: std.os.windows.DWORD = undefined;
        return std.os.windows.kernel32.GetConsoleMode(handle, &mode) != 0;
    } else {
        return std.posix.isatty(std.io.getStdIn().handle);
    }
}
