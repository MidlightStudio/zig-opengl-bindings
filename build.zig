const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dishwasher = b.dependency("dishwasher", .{});
    const openglRegistry = b.dependency("OpenGL-Registry", .{});

    const exe = b.addExecutable(.{
        .name = "zig-opengl-bindings",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("gl.xml", b.addModule("gl-xml", .{ .root_source_file = openglRegistry.path("xml/gl.xml") }));
    exe.root_module.addImport("dishwasher", dishwasher.module("dishwasher"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

pub const BindingsOptions = struct {
    api: []const u8 = "gl",
    version: []const u8 = "GL_VERSION_4_6",
    static: bool = false,
};

pub fn addBindingsModule(b: *std.Build, options: BindingsOptions) *std.Build.Module {
    var zigOpenGLBindings = b.dependency("zig-opengl-bindings", .{ .optimize = @as([]const u8, "ReleaseFast") });
    const exe = zigOpenGLBindings.artifact("zig-opengl-bindings");

    const buildGLBindingsCmd = std.Build.Step.Run.create(b, b.fmt("generate opengl bindings", .{}));

    buildGLBindingsCmd.addFileArg(exe.getEmittedBin());
    buildGLBindingsCmd.addArg(options.api);
    buildGLBindingsCmd.addArg(options.version);

    const outputPath = buildGLBindingsCmd.addOutputFileArg("gl.zig");
    if (options.static) {
        buildGLBindingsCmd.addArg("--static");
    }

    return b.addModule("opengl", .{ .root_source_file = outputPath });
}
