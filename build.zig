const std = @import("std");
const version = @import("src/version.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "litholog",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Shared library for bindings
    const lib = b.addSharedLibrary(.{
        .name = "litholog",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
        .version = version.VERSION,
    });

    // Install the library and header
    b.installArtifact(lib);
    b.installFile("include/litholog.h", "include/litholog.h");

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Library build step
    const lib_step = b.step("lib", "Build the shared library");
    lib_step.dependOn(&lib.step);

    // Create a symlink/copy for easier access by bindings
    const lib_copy_step = b.step("lib-copy", "Copy library for bindings");
    const install_step = b.getInstallStep();
    lib_copy_step.dependOn(install_step);

    // Add run step to create symlink after build
    const symlink_cmd = b.addSystemCommand(&[_][]const u8{ "sh", "-c", "cd zig-out/lib && ln -sf liblitholog.so.* liblitholog.so 2>/dev/null || cp liblitholog.so.* liblitholog.so 2>/dev/null || true" });
    symlink_cmd.step.dependOn(install_step);
    lib_step.dependOn(&symlink_cmd.step);

    // Version extraction step for bindings
    const version_step = b.step("version", "Extract version for bindings");
    const version_cmd = b.addWriteFile("VERSION", version.VERSION_STRING);
    version_step.dependOn(&version_cmd.step);

    // Tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/parser/bs5930.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
