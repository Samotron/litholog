const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");
const types = @import("parser/types.zig");

const HTML_CONTENT = @embedFile("web_ui.html");

pub const WebServer = struct {
    allocator: std.mem.Allocator,
    parser: bs5930.Parser,
    port: u16,

    pub fn init(allocator: std.mem.Allocator, port: u16) !WebServer {
        return WebServer{
            .allocator = allocator,
            .parser = bs5930.Parser.init(allocator),
            .port = port,
        };
    }

    pub fn deinit(self: *WebServer) void {
        _ = self;
    }

    pub fn start(self: *WebServer) !void {
        const address = try std.net.Address.parseIp("127.0.0.1", self.port);

        var tcp_server = try address.listen(.{
            .reuse_address = true,
        });
        defer tcp_server.deinit();

        std.debug.print("🚀 Litholog Web UI started at http://127.0.0.1:{d}\n", .{self.port});
        std.debug.print("📖 Open this URL in your browser to use the web interface\n", .{});
        std.debug.print("⏹️  Press Ctrl+C to stop the server\n\n", .{});

        // Try to open the browser automatically
        self.openBrowser() catch {};

        while (true) {
            const connection = try tcp_server.accept();

            // Handle the connection in a thread
            const thread = try std.Thread.spawn(.{}, handleConnection, .{ self, connection });
            thread.detach();
        }
    }

    fn handleConnection(self: *WebServer, connection: std.net.Server.Connection) void {
        defer connection.stream.close();

        var read_buffer: [4096]u8 = undefined;
        var server = std.http.Server.init(connection, &read_buffer);

        while (server.state == .ready) {
            var request = server.receiveHead() catch |err| {
                std.debug.print("Error receiving request: {}\n", .{err});
                return;
            };

            self.handleRequest(&request) catch |err| {
                std.debug.print("Error handling request: {}\n", .{err});
            };
        }
    }

    fn handleRequest(self: *WebServer, request: *std.http.Server.Request) !void {
        const target = request.head.target;
        const method = request.head.method;

        if (method == .GET and std.mem.eql(u8, target, "/")) {
            // Serve the main HTML page
            try request.respond(HTML_CONTENT, .{
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "text/html; charset=utf-8" },
                },
            });
        } else if (method == .POST and std.mem.startsWith(u8, target, "/api/parse")) {
            // Parse a description
            try self.handleParse(request);
        } else if (method == .POST and std.mem.startsWith(u8, target, "/api/parse-batch")) {
            // Parse multiple descriptions
            try self.handleParseBatch(request);
        } else if (method == .GET and std.mem.startsWith(u8, target, "/api/health")) {
            // Health check
            try request.respond("{\"status\":\"ok\"}", .{
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                },
            });
        } else {
            // 404 Not Found
            try request.respond("404 Not Found", .{
                .status = .not_found,
            });
        }
    }

    fn handleParse(self: *WebServer, request: *std.http.Server.Request) !void {
        // Read request body
        var body_buffer = std.ArrayList(u8).init(self.allocator);
        defer body_buffer.deinit();

        const reader = try request.reader();
        try reader.readAllArrayList(&body_buffer, 10 * 1024 * 1024); // 10MB max

        // Parse JSON request
        const parsed = try std.json.parseFromSlice(
            struct { description: []const u8 },
            self.allocator,
            body_buffer.items,
            .{},
        );
        defer parsed.deinit();

        // Parse the geological description
        const result = try self.parser.parse(parsed.value.description);

        // Convert to JSON
        const json = try result.toJson(self.allocator);
        defer self.allocator.free(json);

        // Send response
        try request.respond(json, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    fn handleParseBatch(self: *WebServer, request: *std.http.Server.Request) !void {
        // Read request body
        var body_buffer = std.ArrayList(u8).init(self.allocator);
        defer body_buffer.deinit();

        const reader = try request.reader();
        try reader.readAllArrayList(&body_buffer, 10 * 1024 * 1024); // 10MB max

        // Parse JSON request
        const parsed = try std.json.parseFromSlice(
            struct { descriptions: []const []const u8 },
            self.allocator,
            body_buffer.items,
            .{},
        );
        defer parsed.deinit();

        // Parse all descriptions
        var results = std.ArrayList(u8).init(self.allocator);
        defer results.deinit();

        try results.appendSlice("[");
        for (parsed.value.descriptions, 0..) |desc, i| {
            if (i > 0) try results.appendSlice(",");

            const result = try self.parser.parse(desc);
            const json = try result.toJson(self.allocator);
            defer self.allocator.free(json);

            try results.appendSlice(json);
        }
        try results.appendSlice("]");

        // Send response
        try request.respond(results.items, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    fn openBrowser(self: *WebServer) !void {
        const url = try std.fmt.allocPrint(self.allocator, "http://127.0.0.1:{d}", .{self.port});
        defer self.allocator.free(url);

        const result = if (@import("builtin").os.tag == .windows)
            std.process.Child.run(.{
                .allocator = self.allocator,
                .argv = &[_][]const u8{ "cmd", "/c", "start", url },
            })
        else if (@import("builtin").os.tag == .macos)
            std.process.Child.run(.{
                .allocator = self.allocator,
                .argv = &[_][]const u8{ "open", url },
            })
        else
            std.process.Child.run(.{
                .allocator = self.allocator,
                .argv = &[_][]const u8{ "xdg-open", url },
            });

        if (result) |r| {
            defer self.allocator.free(r.stdout);
            defer self.allocator.free(r.stderr);
        } else |_| {
            // Silently ignore browser open errors
        }
    }
};
