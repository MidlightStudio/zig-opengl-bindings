const std = @import("std");
const openglBindings = @import("zig-opengl-bindings");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var zigwin32Dependency = b.dependency("win32", .{});

    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const opengl = openglBindings.addBindingsModule(b, .{
        .api = "gles2",
        .version = "GL_ES_VERSION_3_0",
        .static = false,
    });

    exe.root_module.addImport("opengl", opengl);
    exe.root_module.addImport("win32", zigwin32Dependency.module("zigwin32"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
