const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const option_api = b.option([]const u8, "api", "The GL API to generate bindings for, default: 'gl'") orelse "gl";
    const option_version = b.option([]const u8, "version", "The API version to generate bindings for, default: 'GL_VERSION_4_6'") orelse "GL_VERSION_4_6";
    const option_static = b.option(bool, "static", "Whether or not to generate static bindings, default: false") orelse false;

    const dishwasher = b.dependency("dishwasher", .{});
    const opengl_registry = b.dependency("opengl_registry", .{});

    const opengl_xml = b.createModule(.{
        .root_source_file = opengl_registry.path("xml/gl.xml"),
    });

    // standalone generator
    const generator_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl.xml", .module = opengl_xml },
            .{ .name = "dishwasher", .module = dishwasher.module("dishwasher") },
        },
    });

    const generator_exe = b.addExecutable(.{
        .name = "opengl-bindings",
        .root_module = generator_module,
    });

    b.installArtifact(generator_exe);

    const generate_cmd = b.addRunArtifact(generator_exe);

    // generated bindings for using as a dependency
    generate_cmd.addArg(option_api);
    generate_cmd.addArg(option_version);

    const output_path = generate_cmd.addOutputFileArg("gl.zig");
    if (option_static) {
        generate_cmd.addArg("--static");
    }

    _ = b.addModule("gl", .{ .root_source_file = output_path });

    const run_cmd = b.addRunArtifact(generator_exe);

    // run step
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
