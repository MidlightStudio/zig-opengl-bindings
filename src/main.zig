const std = @import("std");
const builtin = @import("builtin");
const xml = @import("dishwasher");

const GLSpec = @import("GLSpec.zig");

const UsageString = "zig-opengl-bindings.exe <api> <version> <Output File Path> [--static]";

const use_debug_allocator = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    .ReleaseFast, .ReleaseSmall => false,
};

pub fn main() !void {
    var gpa = if (use_debug_allocator) std.heap.DebugAllocator(.{}){} else {};
    defer if (use_debug_allocator) std.debug.assert(gpa.deinit() == .ok) else {};

    const allocator = if (use_debug_allocator) gpa.allocator() else std.heap.smp_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next();

    const api = args.next() orelse {
        std.log.err("Expected OpenGL api. Usage: " ++ UsageString, .{});
        std.process.exit(1);
    };

    const version = args.next() orelse {
        std.log.err("Expected OpenGL version identifier. Usage: " ++ UsageString, .{});
        std.process.exit(1);
    };

    const outputPath = args.next() orelse {
        std.log.err("Expected output path. Usage: " ++ UsageString, .{});
        std.process.exit(1);
    };

    var isWasm = false;
    var time = false;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--static")) isWasm = true;
        if (std.mem.eql(u8, arg, "--time")) time = true;
    }

    const start = std.time.milliTimestamp();

    const owned = try xml.Populate(GLSpec).initFromSlice(allocator, @embedFile("gl.xml"));
    defer owned.deinit();

    const outFile = try std.fs.cwd().createFile(outputPath, .{});
    defer outFile.close();

    var write_buffer: [4096]u8 = undefined;
    var writer = outFile.writer(&write_buffer);

    var formatter: GLSpec.Registry.Formatter = .{ .allocator = allocator, .registry = owned.value.registry, .api = api, .version = version, .static = isWasm };
    writer.interface.print(
        \\// GENERATED WITH https://github.com/MidlightStudio/zig-opengl-bindings
        \\//     COMMAND ./opengl-bindings {s} {s} ./output.zig{s}
        \\
        \\{f}
    , .{ api, version, if (isWasm) " --static" else "", &formatter }) catch |e| switch (e) {
        error.WriteFailed => {
            if (formatter.format_error) |err| return err;
            return e;
        },
        else => return e,
    };
    try writer.interface.flush();

    const end = std.time.milliTimestamp();
    const duration = end - start;

    if (time) std.debug.print("took {}ms", .{duration});
}
