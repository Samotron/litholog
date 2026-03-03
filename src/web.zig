const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");
const types = @import("parser/types.zig");
const ags_reader = @import("ags_reader.zig");
const ags_writer = @import("ags_writer.zig");
const svg_renderer = @import("svg_renderer.zig");

const HTML_CONTENT = @embedFile("web_ui.html");

pub const WebServer = struct {
    allocator: std.mem.Allocator,
    parser: bs5930.Parser,
    port: u16,
    state_mutex: std.Thread.Mutex = .{},
    uploaded_ags: ?UploadedAgs = null,

    const UploadedAgs = struct {
        filename: []const u8,
        ags: ags_reader.AgsFile,
        svg_config: svg_renderer.SvgConfig,

        fn deinit(self: *UploadedAgs, allocator: std.mem.Allocator) void {
            allocator.free(self.filename);
            self.ags.deinit(allocator);
        }
    };

    pub fn init(allocator: std.mem.Allocator, port: u16) !WebServer {
        return WebServer{
            .allocator = allocator,
            .parser = bs5930.Parser.init(allocator),
            .port = port,
        };
    }

    pub fn deinit(self: *WebServer) void {
        self.state_mutex.lock();
        defer self.state_mutex.unlock();
        if (self.uploaded_ags) |*uploaded| uploaded.deinit(self.allocator);
        self.uploaded_ags = null;
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

        var read_buffer: [65536]u8 = undefined;
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
        } else if (method == .POST and std.mem.startsWith(u8, target, "/api/ags/upload")) {
            try self.handleAgsUpload(request);
        } else if (method == .GET and std.mem.startsWith(u8, target, "/api/ags/boreholes")) {
            try self.handleAgsBoreholes(request);
        } else if (method == .GET and std.mem.startsWith(u8, target, "/api/ags/log/")) {
            try self.handleAgsLog(request, target);
        } else if (method == .GET and std.mem.startsWith(u8, target, "/api/ags/enhanced")) {
            try self.handleAgsEnhanced(request);
        } else if (method == .GET and std.mem.startsWith(u8, target, "/api/ags/svg/")) {
            try self.handleAgsSvgDownload(request, target);
        } else if (method == .POST and std.mem.startsWith(u8, target, "/api/ags/svg/all")) {
            try self.handleAgsSvgAll(request);
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

    fn handleAgsUpload(self: *WebServer, request: *std.http.Server.Request) !void {
        const body = try self.readRequestBody(request);
        defer self.allocator.free(body);

        const UploadPayload = struct {
            content: []const u8,
            filename: ?[]const u8 = null,
            scale: ?f64 = null,
            width: ?f64 = null,
        };

        const parsed = try std.json.parseFromSlice(UploadPayload, self.allocator, body, .{});
        defer parsed.deinit();

        var local_parser = bs5930.Parser.init(self.allocator);
        var ags_file = try ags_reader.parseSlice(self.allocator, &local_parser, parsed.value.content);
        errdefer ags_file.deinit(self.allocator);

        var config = svg_renderer.SvgConfig{};
        if (parsed.value.scale) |s| config.depth_scale = @floatCast(s);
        if (parsed.value.width) |w| config.width = @floatCast(w);

        const filename = try self.allocator.dupe(u8, parsed.value.filename orelse "uploaded.ags");
        errdefer self.allocator.free(filename);

        self.state_mutex.lock();
        defer self.state_mutex.unlock();
        if (self.uploaded_ags) |*uploaded| uploaded.deinit(self.allocator);
        self.uploaded_ags = UploadedAgs{
            .filename = filename,
            .ags = ags_file,
            .svg_config = config,
        };

        var out = std.ArrayList(u8).init(self.allocator);
        defer out.deinit();
        const w = out.writer();
        try w.writeAll("{\"ok\":true,\"filename\":");
        try std.json.stringify(filename, .{}, w);
        try w.print(",\"locations\":{d},\"strata\":{d}}}", .{
            self.uploaded_ags.?.ags.locations.len,
            self.uploaded_ags.?.ags.strata.len,
        });
        try self.respondJson(request, out.items);
    }

    fn handleAgsBoreholes(self: *WebServer, request: *std.http.Server.Request) !void {
        self.state_mutex.lock();
        defer self.state_mutex.unlock();
        if (self.uploaded_ags == null) return self.respondBadRequest(request, "No AGS file uploaded");

        var out = std.ArrayList(u8).init(self.allocator);
        defer out.deinit();
        const w = out.writer();
        try w.writeAll("{\"boreholes\":[");
        for (self.uploaded_ags.?.ags.locations, 0..) |loc, i| {
            if (i > 0) try w.writeByte(',');
            try w.writeAll("{\"id\":");
            try std.json.stringify(loc.id, .{}, w);
            try w.print(",\"easting\":{d:.2},\"northing\":{d:.2},\"ground_level\":{d:.2},\"final_depth\":{d:.2}}}", .{
                loc.easting,
                loc.northing,
                loc.ground_level,
                loc.final_depth,
            });
        }
        try w.writeAll("]}");
        try self.respondJson(request, out.items);
    }

    fn handleAgsLog(self: *WebServer, request: *std.http.Server.Request, target: []const u8) !void {
        const prefix = "/api/ags/log/";
        const suffix = target[prefix.len..];
        if (suffix.len == 0) return self.respondBadRequest(request, "Missing borehole id");

        const json_suffix = "/json";
        const is_json = std.mem.endsWith(u8, suffix, json_suffix);
        const borehole_id = if (is_json) suffix[0 .. suffix.len - json_suffix.len] else suffix;

        self.state_mutex.lock();
        defer self.state_mutex.unlock();
        if (self.uploaded_ags == null) return self.respondBadRequest(request, "No AGS file uploaded");

        if (is_json) {
            var out = std.ArrayList(u8).init(self.allocator);
            defer out.deinit();
            const w = out.writer();

            try w.writeAll("{\"id\":");
            try std.json.stringify(borehole_id, .{}, w);
            try w.writeAll(",\"strata\":[");
            var wrote_one = false;
            for (self.uploaded_ags.?.ags.strata) |s| {
                if (!std.mem.eql(u8, s.location_id, borehole_id)) continue;
                if (wrote_one) try w.writeByte(',');
                wrote_one = true;
                try w.writeAll("{\"depth_top\":");
                try std.json.stringify(s.depth_top, .{}, w);
                try w.writeAll(",\"depth_base\":");
                try std.json.stringify(s.depth_base, .{}, w);
                try w.writeAll(",\"description\":");
                try std.json.stringify(s.description, .{}, w);
                try w.writeAll(",\"formation\":");
                try std.json.stringify(s.formation, .{}, w);
                if (s.parsed) |parsed| {
                    const parsed_json = try parsed.toJson(self.allocator);
                    defer self.allocator.free(parsed_json);
                    try w.writeAll(",\"parsed\":");
                    try w.writeAll(parsed_json);
                } else {
                    try w.writeAll(",\"parsed\":null");
                }
                try w.writeByte('}');
            }
            try w.writeAll("]}");
            return self.respondJson(request, out.items);
        }

        const svg = svg_renderer.renderBorehole(
            self.allocator,
            &self.uploaded_ags.?.ags,
            borehole_id,
            self.uploaded_ags.?.svg_config,
        ) catch return self.respondBadRequest(request, "Borehole not found");
        defer self.allocator.free(svg);

        try request.respond(svg, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "image/svg+xml; charset=utf-8" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    fn handleAgsEnhanced(self: *WebServer, request: *std.http.Server.Request) !void {
        self.state_mutex.lock();
        defer self.state_mutex.unlock();
        if (self.uploaded_ags == null) return self.respondBadRequest(request, "No AGS file uploaded");

        const enhanced = try ags_writer.writeEnhanced(self.allocator, &self.uploaded_ags.?.ags);
        defer self.allocator.free(enhanced);
        try request.respond(enhanced, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain; charset=utf-8" },
                .{ .name = "content-disposition", .value = "attachment; filename=\"enhanced.ags\"" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    fn handleAgsSvgDownload(self: *WebServer, request: *std.http.Server.Request, target: []const u8) !void {
        const prefix = "/api/ags/svg/";
        const borehole_id = target[prefix.len..];
        if (borehole_id.len == 0) return self.respondBadRequest(request, "Missing borehole id");

        self.state_mutex.lock();
        defer self.state_mutex.unlock();
        if (self.uploaded_ags == null) return self.respondBadRequest(request, "No AGS file uploaded");

        const svg = svg_renderer.renderBorehole(
            self.allocator,
            &self.uploaded_ags.?.ags,
            borehole_id,
            self.uploaded_ags.?.svg_config,
        ) catch return self.respondBadRequest(request, "Borehole not found");
        defer self.allocator.free(svg);

        const content_disposition = try std.fmt.allocPrint(self.allocator, "attachment; filename=\"{s}.svg\"", .{borehole_id});
        defer self.allocator.free(content_disposition);
        try request.respond(svg, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "image/svg+xml; charset=utf-8" },
                .{ .name = "content-disposition", .value = content_disposition },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    fn handleAgsSvgAll(self: *WebServer, request: *std.http.Server.Request) !void {
        self.state_mutex.lock();
        defer self.state_mutex.unlock();
        if (self.uploaded_ags == null) return self.respondBadRequest(request, "No AGS file uploaded");

        var out = std.ArrayList(u8).init(self.allocator);
        defer out.deinit();
        const w = out.writer();
        try w.writeAll("{\"files\":[");
        for (self.uploaded_ags.?.ags.locations, 0..) |loc, i| {
            if (i > 0) try w.writeByte(',');
            const svg = svg_renderer.renderBorehole(
                self.allocator,
                &self.uploaded_ags.?.ags,
                loc.id,
                self.uploaded_ags.?.svg_config,
            ) catch continue;
            defer self.allocator.free(svg);

            try w.writeAll("{\"id\":");
            try std.json.stringify(loc.id, .{}, w);
            try w.writeAll(",\"filename\":");
            const filename = try std.fmt.allocPrint(self.allocator, "{s}.svg", .{loc.id});
            defer self.allocator.free(filename);
            try std.json.stringify(filename, .{}, w);
            try w.writeAll(",\"svg\":");
            try std.json.stringify(svg, .{}, w);
            try w.writeByte('}');
        }
        try w.writeAll("]}");
        try self.respondJson(request, out.items);
    }

    fn readRequestBody(self: *WebServer, request: *std.http.Server.Request) ![]u8 {
        var body_buffer = std.ArrayList(u8).init(self.allocator);
        defer body_buffer.deinit();

        const reader = try request.reader();
        try reader.readAllArrayList(&body_buffer, 20 * 1024 * 1024);
        return body_buffer.toOwnedSlice();
    }

    fn respondJson(self: *WebServer, request: *std.http.Server.Request, json: []const u8) !void {
        _ = self;
        try request.respond(json, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    fn respondBadRequest(self: *WebServer, request: *std.http.Server.Request, message: []const u8) !void {
        var out = std.ArrayList(u8).init(self.allocator);
        defer out.deinit();
        const w = out.writer();
        try w.writeAll("{\"error\":");
        try std.json.stringify(message, .{}, w);
        try w.writeAll("}");
        try request.respond(out.items, .{
            .status = .bad_request,
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
