const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");

pub const Tui = struct {
    allocator: std.mem.Allocator,
    parser: bs5930.Parser,

    pub fn init(allocator: std.mem.Allocator) !Tui {
        return Tui{
            .allocator = allocator,
            .parser = bs5930.Parser.init(allocator),
        };
    }

    pub fn deinit(self: *Tui) void {
        _ = self;
    }

    pub fn run(self: *Tui) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        // Print welcome message
        try stdout.print("\x1b[1;34m┌─────────────────────────────────────────────────────────────────────┐\x1b[0m\n", .{});
        try stdout.print("\x1b[1;34m│              litholog - Soil & Rock Description Parser             │\x1b[0m\n", .{});
        try stdout.print("\x1b[1;34m└─────────────────────────────────────────────────────────────────────┘\x1b[0m\n\n", .{});

        try stdout.print("\x1b[90mEnter soil or rock descriptions to parse. Type 'quit' or 'exit' to quit.\x1b[0m\n", .{});
        try stdout.print("\x1b[90mSoil examples: 'Firm CLAY', 'Dense sandy GRAVEL', 'Soft to firm silty CLAY'\x1b[0m\n", .{});
        try stdout.print("\x1b[90mRock examples: 'Strong LIMESTONE', 'Moderately strong weathered SANDSTONE'\x1b[0m\n\n", .{});

        var line_buffer: [256]u8 = undefined;

        while (true) {
            // Prompt
            try stdout.print("\x1b[1;32mlitholog>\x1b[0m ", .{});

            // Read line
            if (try stdin.readUntilDelimiterOrEof(line_buffer[0..], '\n')) |input| {
                const trimmed_input = std.mem.trim(u8, input, " \t\r\n");

                // Check for quit commands
                if (std.mem.eql(u8, trimmed_input, "quit") or
                    std.mem.eql(u8, trimmed_input, "exit") or
                    std.mem.eql(u8, trimmed_input, "q"))
                {
                    try stdout.print("\x1b[90mGoodbye!\x1b[0m\n", .{});
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
                try stdout.print("\n\x1b[90mGoodbye!\x1b[0m\n", .{});
                break;
            }
        }
    }

    fn parseAndDisplay(self: *Tui, input: []const u8, stdout: anytype) !void {
        const result = self.parser.parse(input) catch |err| {
            try stdout.print("\x1b[1;31mError parsing input: {}\x1b[0m\n", .{err});
            return;
        };
        defer result.deinit(self.allocator);

        // Display results with nice formatting
        try stdout.print("\n\x1b[1;33mParsed Results:\x1b[0m\n", .{});
        try stdout.print("─────────────────────────────────────────────────────────────────────\n", .{});

        try stdout.print("\x1b[1;36mDescription:\x1b[0m {s}\n", .{result.raw_description});
        try stdout.print("\x1b[1;36mMaterial Type:\x1b[0m {s}\n", .{result.material_type.toString()});

        // Soil properties
        if (result.material_type == .soil) {
            if (result.consistency) |consistency| {
                try stdout.print("\x1b[1;36mConsistency:\x1b[0m {s}\n", .{consistency.toString()});
            }

            if (result.density) |density| {
                try stdout.print("\x1b[1;36mDensity:\x1b[0m {s}\n", .{density.toString()});
            }

            if (result.primary_soil_type) |soil_type| {
                try stdout.print("\x1b[1;36mPrimary Soil:\x1b[0m {s}\n", .{soil_type.toString()});
            }
        }

        // Rock properties
        if (result.material_type == .rock) {
            if (result.rock_strength) |strength| {
                try stdout.print("\x1b[1;36mRock Strength:\x1b[0m {s}\n", .{strength.toString()});
            }

            if (result.weathering_grade) |weathering| {
                try stdout.print("\x1b[1;36mWeathering Grade:\x1b[0m {s}\n", .{weathering.toString()});
            }

            if (result.rock_structure) |structure| {
                try stdout.print("\x1b[1;36mRock Structure:\x1b[0m {s}\n", .{structure.toString()});
            }

            if (result.primary_rock_type) |rock_type| {
                try stdout.print("\x1b[1;36mPrimary Rock:\x1b[0m {s}\n", .{rock_type.toString()});
            }
        }

        if (result.secondary_constituents.len > 0) {
            try stdout.print("\x1b[1;36mSecondary Constituents:\x1b[0m\n", .{});
            for (result.secondary_constituents) |sc| {
                const sc_str = try sc.toString(self.allocator);
                defer self.allocator.free(sc_str);
                try stdout.print("  • {s}\n", .{sc_str});
            }
        }

        // Display strength parameters if available
        if (result.strength_parameters) |sp| {
            const sp_str = try sp.toString(self.allocator);
            defer self.allocator.free(sp_str);
            try stdout.print("\x1b[1;36mStrength Parameters:\x1b[0m {s}\n", .{sp_str});
        }

        try stdout.print("\x1b[1;36mConfidence:\x1b[0m {d:.2}\n", .{result.confidence});
        try stdout.print("─────────────────────────────────────────────────────────────────────\n", .{});
    }
};
