const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var last_result: ?[]u8 = null;
var last_error: ?[]u8 = null;

fn clearLastBuffers() void {
    if (last_result) |result| allocator.free(result);
    if (last_error) |err| allocator.free(err);
    last_result = null;
    last_error = null;
}

fn setError(comptime fmt: []const u8, args: anytype) void {
    if (last_error) |err| allocator.free(err);
    last_error = std.fmt.allocPrint(allocator, fmt, args) catch null;
}

export fn litholog_wasm_alloc(len: usize) usize {
    const mem = allocator.alloc(u8, len) catch return 0;
    return @intFromPtr(mem.ptr);
}

export fn litholog_wasm_free(ptr: usize, len: usize) void {
    if (ptr == 0 or len == 0) return;
    const mem: [*]u8 = @ptrFromInt(ptr);
    allocator.free(mem[0..len]);
}

export fn litholog_wasm_parse(input_ptr: usize, input_len: usize) i32 {
    clearLastBuffers();
    if (input_ptr == 0 or input_len == 0) {
        setError("description cannot be empty", .{});
        return -1;
    }

    const ptr: [*]const u8 = @ptrFromInt(input_ptr);
    const input = ptr[0..input_len];

    var parser = bs5930.Parser.init(allocator);
    const parsed = parser.parse(input) catch |err| {
        setError("parse failed: {s}", .{@errorName(err)});
        return -1;
    };

    const json = parsed.toJson(allocator) catch |err| {
        setError("json encode failed: {s}", .{@errorName(err)});
        return -1;
    };

    last_result = json;
    return 0;
}

export fn litholog_wasm_result_ptr() usize {
    if (last_result) |result| return @intFromPtr(result.ptr);
    return 0;
}

export fn litholog_wasm_result_len() usize {
    if (last_result) |result| return result.len;
    return 0;
}

export fn litholog_wasm_error_ptr() usize {
    if (last_error) |err| return @intFromPtr(err.ptr);
    return 0;
}

export fn litholog_wasm_error_len() usize {
    if (last_error) |err| return err.len;
    return 0;
}
