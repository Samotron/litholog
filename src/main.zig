const std = @import("std");
const builtin = @import("builtin");
const cli = @import("cli.zig");
const tui = @import("tui.zig");
const web = @import("web.zig");
const ags_cli = @import("ags_cli.zig");
const version = @import("version.zig");

const KnownCommand = struct {
    name: []const u8,
    description: []const u8,
};

const known_commands = [_]KnownCommand{
    .{ .name = "parse", .description = "Parse geological descriptions" },
    .{ .name = "csv", .description = "Process CSV/Excel files" },
    .{ .name = "ags", .description = "AGS4 file operations (inspect, enhance, validate)" },
    .{ .name = "inspect", .description = "Inspect AGS4 files and render SVG logs" },
    .{ .name = "enhance", .description = "Add parsed columns to AGS4 files" },
    .{ .name = "validate", .description = "Validate AGS4 file structure" },
    .{ .name = "generate", .description = "Generate random or varied descriptions" },
    .{ .name = "units", .description = "Identify geological units across boreholes" },
    .{ .name = "convert", .description = "Convert between JSON and text descriptions" },
    .{ .name = "web", .description = "Launch web UI" },
    .{ .name = "tui", .description = "Interactive terminal mode" },
    .{ .name = "version", .description = "Show version info" },
    .{ .name = "help", .description = "Show help for commands" },
    .{ .name = "completions", .description = "Generate shell completion scripts" },
};

const GlobalFlags = struct {
    no_color: bool = false,
    json: bool = false,
    quiet: bool = false,
    verbose: bool = false,
    help: bool = false,
    version: bool = false,
    next_arg_index: usize = 1,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const launched_via_doubleclick = args.len == 1 and !isStdinTTY();
    if (launched_via_doubleclick) {
        var server = try web.WebServer.init(allocator, 8080);
        defer server.deinit();
        try server.start();
        return;
    }

    const globals = parseGlobalFlags(args);
    if (globals.next_arg_index >= args.len) {
        if (globals.version) return if (globals.json) printVersionJson() else printShortVersion();
        return if (globals.json) printRootHelpJson() else printRootHelp();
    }

    if (globals.help and globals.next_arg_index >= args.len) {
        return if (globals.json) printRootHelpJson() else printRootHelp();
    }
    if (globals.version and globals.next_arg_index >= args.len) {
        return if (globals.json) printVersionJson() else printShortVersion();
    }

    const cmd = args[globals.next_arg_index];
    const sub_args = args[(globals.next_arg_index + 1)..];
    const normalized = try normalizeSubArgs(allocator, sub_args);
    defer allocator.free(normalized.args);
    const clean_sub_args = normalized.args;
    const json_output = globals.json or normalized.json;

    if (std.mem.startsWith(u8, cmd, "-")) {
        return runLegacyCli(allocator, args);
    }

    if (std.mem.eql(u8, cmd, "help")) {
        if (clean_sub_args.len == 0) return if (json_output) printRootHelpJson() else printRootHelp();
        return if (json_output) printCommandHelpJson(clean_sub_args[0]) else printCommandHelp(clean_sub_args[0]);
    }
    if (std.mem.eql(u8, cmd, "version")) return if (json_output) printVersionJson() else printLongVersion();
    if (std.mem.eql(u8, cmd, "completions")) {
        if (json_output) return printCompletionsJson(clean_sub_args);
        printCompletions(clean_sub_args) catch {
            try std.io.getStdErr().writer().writeAll("Error: completions requires a shell (bash|zsh|fish)\n");
            std.process.exit(2);
        };
        return;
    }

    if (std.mem.eql(u8, cmd, "web") or std.mem.eql(u8, cmd, "gui")) {
        var server = try web.WebServer.init(allocator, 8080);
        defer server.deinit();
        try server.start();
        return;
    }
    if (std.mem.eql(u8, cmd, "tui")) {
        var litholog_tui = try tui.Tui.init(allocator);
        defer litholog_tui.deinit();
        try litholog_tui.run();
        return;
    }

    if (std.mem.eql(u8, cmd, "ags")) {
        return runAgsGroup(allocator, clean_sub_args, json_output);
    }

    if (std.mem.eql(u8, cmd, "inspect") or std.mem.eql(u8, cmd, "enhance") or std.mem.eql(u8, cmd, "validate")) {
        try printLegacyAgsNotice(cmd);
        return runAgsCommand(allocator, cmd, clean_sub_args, json_output);
    }

    var effective_flags = globals;
    effective_flags.json = json_output;

    if (std.mem.eql(u8, cmd, "parse")) {
        if (hasHelpFlag(clean_sub_args)) return printParseHelp();
        return runMappedCli(allocator, try mapParseCommand(allocator, effective_flags, clean_sub_args));
    }
    if (std.mem.eql(u8, cmd, "csv")) {
        if (clean_sub_args.len == 0 or hasHelpFlag(clean_sub_args)) return printCsvHelp();
        return runMappedCli(allocator, try mapCsvCommand(allocator, effective_flags, clean_sub_args));
    }
    if (std.mem.eql(u8, cmd, "generate")) {
        if (clean_sub_args.len == 0 or hasHelpFlag(clean_sub_args)) return printGenerateHelp();
        return runMappedCli(allocator, try mapGenerateCommand(allocator, effective_flags, clean_sub_args));
    }
    if (std.mem.eql(u8, cmd, "units")) {
        if (clean_sub_args.len == 0 or hasHelpFlag(clean_sub_args)) return printCsvHelp();
        return runMappedCli(allocator, try mapUnitsCommand(allocator, effective_flags, clean_sub_args));
    }
    if (std.mem.eql(u8, cmd, "convert")) {
        if (clean_sub_args.len == 0 or hasHelpFlag(clean_sub_args)) return printConvertHelp();
        return runMappedCli(allocator, try mapConvertCommand(allocator, effective_flags, clean_sub_args));
    }

    if (clean_sub_args.len == 0) {
        const positional = [_][:0]u8{cmd};
        return runMappedCli(allocator, try mapParseCommand(allocator, effective_flags, &positional));
    }

    try printUnknownCommand(cmd);
    std.process.exit(2);
}

fn runLegacyCli(allocator: std.mem.Allocator, args: [][:0]u8) !void {
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

fn runMappedCli(allocator: std.mem.Allocator, mapped: []const []const u8) !void {
    defer allocator.free(mapped);

    var zargs = std.ArrayList([:0]u8).init(allocator);
    defer {
        for (zargs.items) |item| allocator.free(item);
        zargs.deinit();
    }

    for (mapped) |arg| {
        try zargs.append(try allocator.dupeZ(u8, arg));
    }
    try runLegacyCli(allocator, zargs.items);
}

fn runAgsCommand(allocator: std.mem.Allocator, cmd: []const u8, sub_args: []const [:0]u8, json_output: bool) !void {
    var zargs = std.ArrayList([:0]u8).init(allocator);
    defer {
        for (zargs.items) |item| allocator.free(item);
        zargs.deinit();
    }

    try zargs.append(try allocator.dupeZ(u8, "litholog"));
    try zargs.append(try allocator.dupeZ(u8, cmd));
    for (sub_args) |arg| try zargs.append(try allocator.dupeZ(u8, arg));
    if (json_output) try zargs.append(try allocator.dupeZ(u8, "--json"));

    _ = try ags_cli.handle(allocator, zargs.items);
}

fn runAgsGroup(allocator: std.mem.Allocator, sub_args: []const [:0]u8, json_output: bool) !void {
    if (sub_args.len == 0 or hasHelpFlag(sub_args)) return if (json_output) printAgsHelpJson() else printAgsHelp();

    const action = sub_args[0];
    const action_args = sub_args[1..];
    if (std.mem.eql(u8, action, "inspect") or std.mem.eql(u8, action, "enhance") or std.mem.eql(u8, action, "validate")) {
        return runAgsCommand(allocator, action, action_args, json_output);
    }

    const err = std.io.getStdErr().writer();
    try err.print("Error: unknown AGS command \"{s}\"\n\n", .{action});
    if (closestAgsAction(action)) |match| {
        try err.writeAll("Did you mean?\n");
        try err.print("  {s}\n\n", .{match});
    }
    try err.writeAll("Run 'litholog ags --help' for AGS commands.\n");
    std.process.exit(2);
}

fn closestAgsAction(input: []const u8) ?[]const u8 {
    const actions = [_][]const u8{ "inspect", "enhance", "validate" };
    var best: ?[]const u8 = null;
    var best_distance: usize = std.math.maxInt(usize);
    for (actions) |action| {
        const d = levenshteinDistance(input, action);
        if (d < best_distance) {
            best_distance = d;
            best = action;
        }
    }
    if (best_distance <= 3) return best;
    return null;
}

fn parseGlobalFlags(args: [][:0]u8) GlobalFlags {
    var flags = GlobalFlags{};
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--no-color") or std.mem.eql(u8, arg, "-C")) {
            flags.no_color = true;
        } else if (std.mem.eql(u8, arg, "--json")) {
            flags.json = true;
        } else if (std.mem.eql(u8, arg, "--quiet") or std.mem.eql(u8, arg, "-q")) {
            flags.quiet = true;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            flags.verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            flags.help = true;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-V")) {
            flags.version = true;
        } else {
            break;
        }
    }
    flags.next_arg_index = i;
    return flags;
}

fn hasHelpFlag(args: []const [:0]u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) return true;
    }
    return false;
}

const NormalizedArgs = struct {
    args: []const [:0]u8,
    json: bool,
};

fn normalizeSubArgs(allocator: std.mem.Allocator, args: []const [:0]u8) !NormalizedArgs {
    var filtered = std.ArrayList([:0]u8).init(allocator);
    defer filtered.deinit();
    var json = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            json = true;
            continue;
        }
        try filtered.append(arg);
    }
    return .{ .args = try filtered.toOwnedSlice(), .json = json };
}

fn appendGlobalMappedFlags(list: *std.ArrayList([]const u8), flags: GlobalFlags) !void {
    if (flags.no_color) try list.append("--no-color");
    if (flags.json) {
        try list.append("--mode");
        try list.append(if (isStdoutTTY()) "pretty" else "compact");
    }
}

fn mapParseCommand(allocator: std.mem.Allocator, flags: GlobalFlags, sub_args: []const [:0]u8) ![]const []const u8 {
    var mapped = std.ArrayList([]const u8).init(allocator);
    try mapped.append("litholog");
    try appendGlobalMappedFlags(&mapped, flags);
    if (sub_args.len == 0) {
        try mapped.append("--help");
    } else {
        for (sub_args) |arg| try mapped.append(arg);
    }
    return mapped.toOwnedSlice();
}

fn mapCsvLikeBase(allocator: std.mem.Allocator, flags: GlobalFlags, sub_args: []const [:0]u8) !std.ArrayList([]const u8) {
    if (sub_args.len == 0) {
        try printCsvHelp();
        return error.MissingInput;
    }

    var mapped = std.ArrayList([]const u8).init(allocator);
    try mapped.append("litholog");
    try appendGlobalMappedFlags(&mapped, flags);
    try mapped.append("--csv");
    try mapped.append(sub_args[0]);
    return mapped;
}

fn mapCsvCommand(allocator: std.mem.Allocator, flags: GlobalFlags, sub_args: []const [:0]u8) ![]const []const u8 {
    var mapped = try mapCsvLikeBase(allocator, flags, sub_args);
    var i: usize = 1;
    while (i < sub_args.len) : (i += 1) {
        const arg = sub_args[i];
        if (std.mem.eql(u8, arg, "-o")) {
            try mapped.append("--csv-output");
            if (i + 1 >= sub_args.len) return error.MissingOutputArgument;
            i += 1;
            try mapped.append(sub_args[i]);
        } else if (std.mem.eql(u8, arg, "--output")) {
            try mapped.append("--csv-output");
            if (i + 1 >= sub_args.len) return error.MissingOutputArgument;
            i += 1;
            try mapped.append(sub_args[i]);
        } else if (std.mem.eql(u8, arg, "--excel")) {
            try mapped.append("--excel-output");
        } else if (std.mem.eql(u8, arg, "--no-header")) {
            try mapped.append("--csv-no-header");
        } else {
            try mapped.append(arg);
        }
    }
    return mapped.toOwnedSlice();
}

fn mapUnitsCommand(allocator: std.mem.Allocator, flags: GlobalFlags, sub_args: []const [:0]u8) ![]const []const u8 {
    var mapped = try mapCsvLikeBase(allocator, flags, sub_args);
    try mapped.append("--identify-units");

    var i: usize = 1;
    while (i < sub_args.len) : (i += 1) {
        const arg = sub_args[i];
        if (std.mem.eql(u8, arg, "-o")) {
            try mapped.append("--csv-output");
            if (i + 1 >= sub_args.len) return error.MissingOutputArgument;
            i += 1;
            try mapped.append(sub_args[i]);
        } else {
            try mapped.append(arg);
        }
    }
    return mapped.toOwnedSlice();
}

fn mapGenerateCommand(allocator: std.mem.Allocator, flags: GlobalFlags, sub_args: []const [:0]u8) ![]const []const u8 {
    if (sub_args.len == 0) {
        try printGenerateHelp();
        return error.MissingGenerateArgument;
    }

    var mapped = std.ArrayList([]const u8).init(allocator);
    try mapped.append("litholog");
    try appendGlobalMappedFlags(&mapped, flags);
    try mapped.append("--generate");
    try mapped.append(sub_args[0]);

    if (std.mem.eql(u8, sub_args[0], "variations") and sub_args.len > 1 and !std.mem.startsWith(u8, sub_args[1], "-")) {
        try mapped.append(sub_args[1]);
        for (sub_args[2..]) |arg| try mapped.append(arg);
    } else {
        for (sub_args[1..]) |arg| try mapped.append(arg);
    }
    return mapped.toOwnedSlice();
}

fn mapConvertCommand(allocator: std.mem.Allocator, flags: GlobalFlags, sub_args: []const [:0]u8) ![]const []const u8 {
    var mapped = std.ArrayList([]const u8).init(allocator);
    try mapped.append("litholog");
    try appendGlobalMappedFlags(&mapped, flags);

    var saw_from_json = false;
    var i: usize = 0;
    while (i < sub_args.len) : (i += 1) {
        const arg = sub_args[i];
        if (std.mem.eql(u8, arg, "--format")) {
            try mapped.append("--json-format");
            if (i + 1 >= sub_args.len) return error.MissingFormatArgument;
            i += 1;
            try mapped.append(sub_args[i]);
        } else if (std.mem.eql(u8, arg, "--from-json")) {
            saw_from_json = true;
            try mapped.append(arg);
            if (i + 1 >= sub_args.len) return error.MissingJsonInputArgument;
            i += 1;
            try mapped.append(sub_args[i]);
        } else if (!std.mem.startsWith(u8, arg, "-") and !saw_from_json) {
            saw_from_json = true;
            try mapped.append("--from-json");
            try mapped.append(arg);
        } else {
            try mapped.append(arg);
        }
    }

    if (!saw_from_json) {
        try printConvertHelp();
        return error.MissingJsonInputArgument;
    }
    return mapped.toOwnedSlice();
}

fn printRootHelp() !void {
    const out = std.io.getStdOut().writer();
    try out.print(
        \\⛏  litholog v{s} — Geological description parser (BS 5930)
        \\
        \\Usage:
        \\  litholog <DESCRIPTION>              Parse a single description
        \\  litholog <command> [flags]          Run a command
        \\
        \\Commands:
        \\  parse       Parse geological descriptions from text, file, or stdin
        \\  csv         Process CSV/Excel files with geological descriptions
        \\  ags         AGS4 workflows (inspect, enhance, validate)
        \\  inspect     Inspect AGS4 files and render SVG borehole logs
        \\  enhance     Add parsed data columns to AGS4 files
        \\  validate    Validate AGS4 file structure
        \\  generate    Generate random or varied descriptions
        \\  units       Identify geological units across boreholes
        \\  convert     Convert between JSON and text descriptions
        \\  web         Launch the web-based GUI
        \\  tui         Interactive terminal mode
        \\  version     Show version details
        \\  completions Generate shell completion scripts
        \\
        \\Flags:
        \\  -C, --no-color   Disable coloured output
        \\      --json       Force JSON output
        \\  -h, --help       Show this help
        \\  -V, --version    Show version
        \\
        \\Examples:
        \\  litholog "Firm brown slightly sandy CLAY"
        \\  litholog csv input.csv -o output.csv --column Description --output-columns material_type,confidence
        \\  litholog ags inspect site_data.ags --format svg
        \\  litholog web
        \\
        \\Run 'litholog help <command>' for more information on a command.
        \\
    , .{version.VERSION_STRING});
}

fn printCommandHelp(command: []const u8) !void {
    if (std.mem.eql(u8, command, "ags")) return printAgsHelp();
    if (std.mem.eql(u8, command, "csv")) return printCsvHelp();
    if (std.mem.eql(u8, command, "parse")) return printParseHelp();
    if (std.mem.eql(u8, command, "generate")) return printGenerateHelp();
    if (std.mem.eql(u8, command, "convert")) return printConvertHelp();
    return printRootHelp();
}

fn printCommandHelpJson(command: []const u8) !void {
    if (std.mem.eql(u8, command, "ags")) return printAgsHelpJson();
    if (std.mem.eql(u8, command, "parse")) return std.io.getStdOut().writer().writeAll("{\"command\":\"parse\"}\n");
    if (std.mem.eql(u8, command, "csv")) return std.io.getStdOut().writer().writeAll("{\"command\":\"csv\"}\n");
    if (std.mem.eql(u8, command, "generate")) return std.io.getStdOut().writer().writeAll("{\"command\":\"generate\"}\n");
    if (std.mem.eql(u8, command, "convert")) return std.io.getStdOut().writer().writeAll("{\"command\":\"convert\"}\n");
    return printRootHelpJson();
}

fn printAgsHelp() !void {
    try std.io.getStdOut().writer().writeAll(
        \\AGS4 inspection, enhancement, and validation commands
        \\
        \\Usage:
        \\  litholog ags <command> [args] [flags]
        \\
        \\Commands:
        \\  inspect <FILE.ags>    Inspect AGS file and output summary/json/csv/svg
        \\  enhance <FILE.ags>    Add parsed data columns to AGS file
        \\  validate <FILE.ags>   Validate AGS file structure and report issues
        \\
        \\Examples:
        \\  litholog ags inspect site.ags --format svg --output site.svg
        \\  litholog ags enhance site.ags -o site_enhanced.ags
        \\  litholog ags validate site.ags
        \\
        \\Compatibility:
        \\  Top-level inspect/enhance/validate commands still work but are legacy aliases.
        \\
    );
}

fn printAgsHelpJson() !void {
    try std.io.getStdOut().writer().writeAll(
        "{\"command\":\"ags\",\"subcommands\":[\"inspect\",\"enhance\",\"validate\"],\"legacy_aliases\":[\"inspect\",\"enhance\",\"validate\"]}\n",
    );
}

fn printParseHelp() !void {
    try std.io.getStdOut().writer().writeAll(
        \\Parse geological descriptions from text, file, or stdin
        \\
        \\Usage:
        \\  litholog parse <DESCRIPTION> [flags]
        \\  litholog parse --file <FILE> [flags]
        \\
        \\Flags:
        \\  -f, --file <FILE>    Parse descriptions from file
        \\  -m, --mode <MODE>    compact|verbose|pretty|summary
        \\  -C, --no-color       Disable colorized output
        \\      --json           Force JSON output
        \\
    );
}

fn printCsvHelp() !void {
    try std.io.getStdOut().writer().writeAll(
        \\Process CSV or Excel files containing geological descriptions
        \\
        \\Usage:
        \\  litholog csv <INPUT_FILE> [flags]
        \\
        \\Flags:
        \\  -o, --output <FILE>           Output file path (required)
        \\      --column <NAME|INDEX>     Column containing descriptions (required)
        \\      --output-columns <COLS>   Comma-separated result columns to append
        \\      --no-header               Input has no header row
        \\      --excel                   Export as Excel (.xlsx)
        \\      --freeze-header           Freeze header row (Excel only)
        \\      --auto-filter             Enable auto-filter (Excel only)
        \\      --sheet-name <NAME>       Worksheet name (default: Sheet1)
        \\
    );
}

fn printGenerateHelp() !void {
    try std.io.getStdOut().writer().writeAll(
        \\Generate random descriptions or variations
        \\
        \\Usage:
        \\  litholog generate random [--count N] [--seed S]
        \\  litholog generate variations <DESCRIPTION>
        \\
    );
}

fn printConvertHelp() !void {
    try std.io.getStdOut().writer().writeAll(
        \\Convert between JSON and text descriptions
        \\
        \\Usage:
        \\  litholog convert --from-json <FILE> [--format standard|concise|verbose|bs5930]
        \\
    );
}

fn printShortVersion() !void {
    try std.io.getStdOut().writer().print("litholog v{s}\n", .{version.VERSION_STRING});
}

fn printLongVersion() !void {
    try std.io.getStdOut().writer().print(
        \\litholog v{s}
        \\Built with Zig {s}
        \\Platform: {s}/{s}
        \\https://github.com/samotron/litholog
        \\
    , .{
        version.VERSION_STRING,
        builtin.zig_version_string,
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
    });
}

fn printVersionJson() !void {
    try std.io.getStdOut().writer().print(
        "{{\"name\":\"litholog\",\"version\":\"{s}\",\"zig\":\"{s}\",\"platform\":\"{s}/{s}\"}}\n",
        .{ version.VERSION_STRING, builtin.zig_version_string, @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) },
    );
}

fn printRootHelpJson() !void {
    try std.io.getStdOut().writer().writeAll(
        "{\"name\":\"litholog\",\"commands\":[\"parse\",\"csv\",\"ags\",\"inspect\",\"enhance\",\"validate\",\"generate\",\"units\",\"convert\",\"web\",\"tui\",\"version\",\"help\",\"completions\"]}\n",
    );
}

fn printCompletions(args: []const [:0]u8) !void {
    if (args.len == 0) return error.MissingShellArgument;
    const shell = args[0];
    const out = std.io.getStdOut().writer();

    if (std.mem.eql(u8, shell, "bash")) {
        try out.writeAll(
            \\_litholog() {
            \\  local cur prev words cword
            \\  _init_completion || return
            \\  local commands="parse csv ags inspect enhance validate generate units convert web tui version help completions"
            \\  if [[ ${cword} -eq 1 ]]; then
            \\    COMPREPLY=( $(compgen -W "${commands}" -- "${cur}") )
            \\    return
            \\  fi
            \\  if [[ ${cword} -eq 2 && "${words[1]}" == "ags" ]]; then
            \\    COMPREPLY=( $(compgen -W "inspect enhance validate" -- "${cur}") )
            \\    return
            \\  fi
            \\}
            \\complete -F _litholog litholog
            \\
        );
        return;
    }
    if (std.mem.eql(u8, shell, "zsh")) {
        try out.writeAll(
            \\#compdef litholog
            \\_litholog() {
            \\  local -a commands
            \\  local -a ags_commands
            \\  commands=('parse:Parse descriptions' 'csv:Process CSV/Excel' 'ags:AGS workflows' 'inspect:Inspect AGS (legacy)' 'enhance:Enhance AGS (legacy)' 'validate:Validate AGS (legacy)' 'generate:Generate descriptions' 'units:Identify units' 'convert:Convert JSON/text' 'web:Launch web UI' 'tui:Interactive TUI' 'version:Show version' 'help:Show help' 'completions:Generate completions')
            \\  ags_commands=('inspect:Inspect AGS' 'enhance:Enhance AGS' 'validate:Validate AGS')
            \\  _arguments '1:command:->commands' '2:subcommand:->subcommands' && return
            \\  case $state in
            \\    commands) _describe 'command' commands ;;
            \\    subcommands) [[ "$words[2]" == "ags" ]] && _describe 'ags command' ags_commands ;;
            \\  esac
            \\}
            \\_litholog "$@"
            \\
        );
        return;
    }
    if (std.mem.eql(u8, shell, "fish")) {
        try out.writeAll(
            \\complete -c litholog -f
            \\complete -c litholog -n '__fish_use_subcommand' -a parse -d 'Parse descriptions'
            \\complete -c litholog -n '__fish_use_subcommand' -a csv -d 'Process CSV/Excel'
            \\complete -c litholog -n '__fish_use_subcommand' -a ags -d 'AGS workflows'
            \\complete -c litholog -n '__fish_use_subcommand' -a inspect -d 'Inspect AGS'
            \\complete -c litholog -n '__fish_use_subcommand' -a enhance -d 'Enhance AGS'
            \\complete -c litholog -n '__fish_use_subcommand' -a validate -d 'Validate AGS'
            \\complete -c litholog -n '__fish_seen_subcommand_from ags' -a inspect -d 'Inspect AGS'
            \\complete -c litholog -n '__fish_seen_subcommand_from ags' -a enhance -d 'Enhance AGS'
            \\complete -c litholog -n '__fish_seen_subcommand_from ags' -a validate -d 'Validate AGS'
            \\complete -c litholog -n '__fish_use_subcommand' -a generate -d 'Generate descriptions'
            \\complete -c litholog -n '__fish_use_subcommand' -a units -d 'Identify units'
            \\complete -c litholog -n '__fish_use_subcommand' -a convert -d 'Convert JSON/text'
            \\complete -c litholog -n '__fish_use_subcommand' -a web -d 'Launch web UI'
            \\complete -c litholog -n '__fish_use_subcommand' -a tui -d 'Interactive TUI'
            \\complete -c litholog -n '__fish_use_subcommand' -a version -d 'Show version'
            \\complete -c litholog -n '__fish_use_subcommand' -a help -d 'Show help'
            \\complete -c litholog -n '__fish_use_subcommand' -a completions -d 'Generate completions'
            \\
        );
        return;
    }
    return error.UnsupportedShell;
}

fn printCompletionsJson(args: []const [:0]u8) !void {
    if (args.len == 0) return error.MissingShellArgument;
    try std.io.getStdOut().writer().print("{{\"command\":\"completions\",\"shell\":\"{s}\"}}\n", .{args[0]});
}

fn printLegacyAgsNotice(cmd: []const u8) !void {
    try std.io.getStdErr().writer().print(
        "Warning: 'litholog {s}' is a legacy alias; prefer 'litholog ags {s}'.\n",
        .{ cmd, cmd },
    );
}

fn printUnknownCommand(cmd: []const u8) !void {
    const err = std.io.getStdErr().writer();
    try err.print("Error: unknown command \"{s}\"\n\n", .{cmd});
    if (closestCommand(cmd)) |match| {
        try err.writeAll("Did you mean?\n");
        try err.print("  {s}    {s}\n\n", .{ match.name, match.description });
    }
    try err.writeAll("Run 'litholog --help' for a list of commands.\n");
}

fn closestCommand(input: []const u8) ?KnownCommand {
    var best: ?KnownCommand = null;
    var best_distance: usize = std.math.maxInt(usize);
    for (known_commands) |cmd| {
        const d = levenshteinDistance(input, cmd.name);
        if (d < best_distance) {
            best_distance = d;
            best = cmd;
        }
    }
    if (best_distance <= 3) return best;
    return null;
}

fn levenshteinDistance(a: []const u8, b: []const u8) usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;

    var row_a: [64]usize = undefined;
    var row_b: [64]usize = undefined;
    if (b.len + 1 > row_a.len) return std.math.maxInt(usize);

    for (0..(b.len + 1)) |j| row_a[j] = j;
    for (a, 0..) |ca, i| {
        row_b[0] = i + 1;
        for (b, 0..) |cb, j| {
            const cost: usize = if (ca == cb) 0 else 1;
            const deletion = row_a[j + 1] + 1;
            const insertion = row_b[j] + 1;
            const substitution = row_a[j] + cost;
            row_b[j + 1] = @min(deletion, @min(insertion, substitution));
        }
        std.mem.copyForwards(usize, row_a[0 .. b.len + 1], row_b[0 .. b.len + 1]);
    }
    return row_a[b.len];
}

fn isStdinTTY() bool {
    if (builtin.os.tag == .windows) {
        const INVALID_HANDLE_VALUE = @as(std.os.windows.HANDLE, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
        const handle = std.io.getStdIn().handle;
        if (handle == INVALID_HANDLE_VALUE) return false;
        var mode: std.os.windows.DWORD = undefined;
        return std.os.windows.kernel32.GetConsoleMode(handle, &mode) != 0;
    }
    return std.posix.isatty(std.io.getStdIn().handle);
}

fn isStdoutTTY() bool {
    if (builtin.os.tag == .windows) {
        const INVALID_HANDLE_VALUE = @as(std.os.windows.HANDLE, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
        const handle = std.io.getStdOut().handle;
        if (handle == INVALID_HANDLE_VALUE) return false;
        var mode: std.os.windows.DWORD = undefined;
        return std.os.windows.kernel32.GetConsoleMode(handle, &mode) != 0;
    }
    return std.posix.isatty(std.io.getStdOut().handle);
}

test "closestAgsAction suggests inspect" {
    try std.testing.expectEqualStrings("inspect", closestAgsAction("insect").?);
}

test "closestCommand suggests ags for ag" {
    const match = closestCommand("ag").?;
    try std.testing.expectEqualStrings("ags", match.name);
}
