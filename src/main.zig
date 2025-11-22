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

    var threaded_io: std.Io.Threaded = .init_single_threaded;
    defer threaded_io.deinit();

    const io = threaded_io.io();

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

    const start = try std.Io.Clock.now(.awake, io);

    const owned = try xml.Populate(GLSpec).initFromSlice(allocator, @embedFile("gl.xml"));
    defer owned.deinit();

    const outFile = try std.fs.cwd().createFile(outputPath, .{});
    defer outFile.close();

    var write_buffer: [4096]u8 = undefined;
    var writer = outFile.writer(&write_buffer);

    var formatter: GLSpec.Registry.Formatter = .{ .allocator = allocator, .registry = owned.value.registry, .api = api, .version = version, .static = isWasm };
    writer.interface.print(
        \\//
        \\// Copyright {s} MIDLIGHT STUDIOS
        \\// Permission is hereby granted, free of charge, to any person obtaining a copy
        \\// of this software and associated documentation files (the “Software”), to deal
        \\// in the Software without restriction, including without limitation the rights to
        \\// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
        \\// of the Software, and to permit persons to whom the Software is furnished to do so,
        \\// subject to the following conditions:
        \\//
        \\// The above copyright notice and this permission notice shall be included in all
        \\// copies or substantial portions of the Software.
        \\//
        \\// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
        \\// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
        \\// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
        \\// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
        \\// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
        \\// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        \\//
        \\// GENERATED WITH https://github.com/MidlightStudio/zig-opengl-bindings
        \\//     API: {s}
        \\//     Version: {s}
        \\//     Static: {}
        \\//
        \\
        \\{f}
    , .{ "2024", api, version, isWasm, &formatter }) catch |e| switch (e) {
        error.WriteFailed => {
            if (formatter.format_error) |err| return err;
            return e;
        },
        else => return e,
    };
    try writer.interface.flush();

    const end = try std.Io.Clock.now(.awake, io);
    const duration = start.durationTo(end);

    if (time) std.debug.print("took {}ms", .{duration.toMilliseconds()});
}
