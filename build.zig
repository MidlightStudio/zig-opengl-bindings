const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dishwasher = b.dependency("dishwasher", .{});
    const opengl_registry = b.dependency("opengl_registry", .{});

    const generator_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const opengl_xml = b.createModule(.{
        .root_source_file = opengl_registry.path("xml/gl.xml"),
    });

    const exe = b.addExecutable(.{
        .name = "zig_opengl_bindings",
        .root_module = generator_module,
    });

    exe.root_module.addImport("gl.xml", opengl_xml);
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

pub fn createBindingsModule(dependency: *std.Build.Dependency, options: BindingsOptions) *std.Build.Module {
    const b = dependency.builder;
    const generator = dependency.artifact("zig_opengl_bindings");
    const generate_gl_bindings = b.addRunArtifact(generator);

    generate_gl_bindings.addArg(options.api);
    generate_gl_bindings.addArg(options.version);

    const outputPath = generate_gl_bindings.addOutputFileArg("gl.zig");
    if (options.static) {
        generate_gl_bindings.addArg("--static");
    }

    return b.createModule(.{ .root_source_file = outputPath });
}
