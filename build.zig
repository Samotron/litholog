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

    // Create a module for the parser that can be imported by tests
    const parser_module = b.addModule("parser", .{
        .root_source_file = b.path("src/parser/bs5930.zig"),
    });

    // Tests - individual test files
    const lexer_tests = b.addTest(.{
        .root_source_file = b.path("tests/lexer_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    lexer_tests.root_module.addImport("parser", parser_module);
    const run_lexer_tests = b.addRunArtifact(lexer_tests);
    const test_lexer_step = b.step("test-lexer", "Run lexer tests");
    test_lexer_step.dependOn(&run_lexer_tests.step);

    const parser_tests = b.addTest(.{
        .root_source_file = b.path("tests/parser_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    parser_tests.root_module.addImport("parser", parser_module);
    const run_parser_tests = b.addRunArtifact(parser_tests);
    const test_parser_step = b.step("test-parser", "Run parser tests");
    test_parser_step.dependOn(&run_parser_tests.step);

    const validation_tests = b.addTest(.{
        .root_source_file = b.path("tests/validation_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    validation_tests.root_module.addImport("parser", parser_module);
    const run_validation_tests = b.addRunArtifact(validation_tests);
    const test_validation_step = b.step("test-validation", "Run validation tests");
    test_validation_step.dependOn(&run_validation_tests.step);

    const strength_db_tests = b.addTest(.{
        .root_source_file = b.path("tests/strength_db_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    strength_db_tests.root_module.addImport("parser", parser_module);
    const run_strength_db_tests = b.addRunArtifact(strength_db_tests);
    const test_strength_db_step = b.step("test-strength-db", "Run strength database tests");
    test_strength_db_step.dependOn(&run_strength_db_tests.step);

    const constituent_db_tests = b.addTest(.{
        .root_source_file = b.path("tests/constituent_db_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    constituent_db_tests.root_module.addImport("parser", parser_module);
    const run_constituent_db_tests = b.addRunArtifact(constituent_db_tests);
    const test_constituent_db_step = b.step("test-constituent-db", "Run constituent database tests");
    test_constituent_db_step.dependOn(&run_constituent_db_tests.step);

    const generator_tests = b.addTest(.{
        .root_source_file = b.path("tests/generator_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    generator_tests.root_module.addImport("parser", parser_module);
    const run_generator_tests = b.addRunArtifact(generator_tests);
    const test_generator_step = b.step("test-generator", "Run generator tests");
    test_generator_step.dependOn(&run_generator_tests.step);

    const fuzzy_tests = b.addTest(.{
        .root_source_file = b.path("tests/fuzzy_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    fuzzy_tests.root_module.addImport("parser", parser_module);
    const run_fuzzy_tests = b.addRunArtifact(fuzzy_tests);
    const test_fuzzy_step = b.step("test-fuzzy", "Run fuzzy matching tests");
    test_fuzzy_step.dependOn(&run_fuzzy_tests.step);

    const integration_tests = b.addTest(.{
        .root_source_file = b.path("tests/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_tests.root_module.addImport("parser", parser_module);
    const run_integration_tests = b.addRunArtifact(integration_tests);
    const test_integration_step = b.step("test-integration", "Run integration tests");
    test_integration_step.dependOn(&run_integration_tests.step);

    // Original parser tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/parser/bs5930.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Anomaly detection tests
    const anomaly_tests = b.addTest(.{
        .root_source_file = b.path("tests/anomaly_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    anomaly_tests.root_module.addImport("parser", parser_module);
    const run_anomaly_tests = b.addRunArtifact(anomaly_tests);

    // Aggregate test step - runs all tests
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_lexer_tests.step);
    test_step.dependOn(&run_parser_tests.step);
    test_step.dependOn(&run_validation_tests.step);
    test_step.dependOn(&run_strength_db_tests.step);
    test_step.dependOn(&run_constituent_db_tests.step);
    test_step.dependOn(&run_generator_tests.step);
    test_step.dependOn(&run_fuzzy_tests.step);
    test_step.dependOn(&run_anomaly_tests.step);
    test_step.dependOn(&run_integration_tests.step);
    test_step.dependOn(&run_lib_unit_tests.step);

    // Demo executables
    const demo_spatial = b.addExecutable(.{
        .name = "demo_spatial",
        .root_source_file = b.path("src/demo_spatial.zig"),
        .target = target,
        .optimize = optimize,
    });
    const demo_spatial_run = b.addRunArtifact(demo_spatial);
    const demo_spatial_step = b.step("demo-spatial", "Run spatial analysis demo");
    demo_spatial_step.dependOn(&demo_spatial_run.step);

    const demo_uncertainty = b.addExecutable(.{
        .name = "demo_uncertainty",
        .root_source_file = b.path("src/demo_uncertainty.zig"),
        .target = target,
        .optimize = optimize,
    });
    const demo_uncertainty_run = b.addRunArtifact(demo_uncertainty);
    const demo_uncertainty_step = b.step("demo-uncertainty", "Run uncertainty quantification demo");
    demo_uncertainty_step.dependOn(&demo_uncertainty_run.step);

    const demo_clustering = b.addExecutable(.{
        .name = "demo_clustering_metrics",
        .root_source_file = b.path("src/demo_clustering_metrics.zig"),
        .target = target,
        .optimize = optimize,
    });
    const demo_clustering_run = b.addRunArtifact(demo_clustering);
    const demo_clustering_step = b.step("demo-clustering", "Run clustering quality metrics demo");
    demo_clustering_step.dependOn(&demo_clustering_run.step);
}
