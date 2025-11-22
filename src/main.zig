const std = @import("std");
const xml = @import("dishwasher");

const UsageString = "zig-opengl-bindings.exe <api> <version> <Output File Path> [--static]";

const GLSpec = struct {
    pub const renameTypes = std.StaticStringMap([]const u8).initComptime(.{
        .{ "GLenum", "u32" },
        .{ "GLboolean", "u8" },
        .{ "GLbitfield", "u32" },
        .{ "GLvoid", "void" },
        .{ "GLbyte", "i8" },
        .{ "GLubyte", "u8" },
        .{ "GLshort", "i16" },
        .{ "GLushort", "u16" },
        .{ "GLint", "i32" },
        .{ "GLuint", "u32" },
        .{ "GLclampx", "i32" },
        .{ "GLsizei", "i32" },
        .{ "GLfloat", "f32" },
        .{ "GLclampf", "f32" },
        .{ "GLdouble", "f64" },
        .{ "GLclampd", "f64" },
        .{ "GLchar", "i8" },
        .{ "GLcharARB", "i8" },
        .{ "GLhalf", "u16" },
        .{ "GLhalfARB", "u16" },
        .{ "GLfixed", "i32" },
        .{ "GLintptr", "usize" },
        .{ "GLintptrARB", "usize" },
        .{ "GLsizeiptr", "isize" },
        .{ "GLsizeiptrARB", "isize" },
        .{ "GLint64", "i64" },
        .{ "GLint64EXT", "i64" },
        .{ "GLuint64", "u64" },
        .{ "GLuint64EXT", "u64" },
        // c types
        .{ "void *", "[*c]anyopaque" },
        .{ "void **", "[*c][*c]anyopaque" },
        .{ "const void *", "[*c]const anyopaque" },
        .{ "const void **", "[*c][*c]const anyopaque" },
        .{ "const void *const*", "[*c]const *const anyopaque" },
    });

    pub const renameSymbols = std.StaticStringMap(void).initComptime(.{.{ "packed", {} }});

    const zigTypeDefs =
        \\pub const GLenum = u32;
        \\pub const GLhandleARB = if (@import("builtin").os.tag == .macos) [*c]u0 else c_uint;
        \\pub const GLeglClientBufferEXT = [*c]u0;
        \\pub const GLeglImageOES = [*c]u0;
        \\pub const GLsync = [*c]u0;
        \\pub const _cl_context = opaque {};
        \\pub const _cl_event = opaque {};
        \\pub const GLDEBUGPROC = [*c]const fn (source: GLenum, _type: GLenum, id: u32, severity: GLenum, length: i32, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void;
        \\pub const GLDEBUGPROCARB = [*c]const fn (source: GLenum, _type: GLenum, id: u32, severity: GLenum, length: i32, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void;
        \\pub const GLDEBUGPROCKHR = [*c]const fn (source: GLenum, _type: GLenum, id: u32, severity: GLenum, length: i32, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void;
        \\pub const GLDEBUGPROCAMD = [*c]const fn (id: u32, category: GLenum, severity: GLenum, length: i32, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void;
        \\pub const GLhalfNV = u16;
        \\pub const GLvdpauSurfaceNV = usize;
        \\pub const GLVULKANPROCNV = [*c]const fn () callconv(.C) void;
    ;

    const SymbolFormatter = struct {
        symbolName: []const u8,

        pub fn format(self: SymbolFormatter, writer: *std.Io.Writer) !void {
            const symbolName = self.symbolName;
            if (std.mem.startsWith(u8, symbolName, "gl")) {
                try writer.writeByte(symbolName[2] + ('a' - 'A'));
                try writer.print("{f}", .{formatSymbol(symbolName[3..])});
                return;
            }
            if (std.mem.startsWith(u8, symbolName, "GL_")) {
                try writer.print("{f}", .{formatSymbol(symbolName[3..])});
                return;
            }
            switch (symbolName[0]) {
                '0'...'9' => {
                    try writer.print("@\"{s}\"", .{symbolName});
                },
                else => {
                    if (renameSymbols.get(symbolName)) |_| {
                        try writer.print("@\"{s}\"", .{symbolName});
                        return;
                    }
                    try writer.print("{s}", .{symbolName});
                },
            }
        }
    };

    pub fn formatSymbol(symbolName: []const u8) SymbolFormatter {
        return .{ .symbolName = symbolName };
    }

    pub const TypeFormatter = struct {
        typeName: []const u8,
        renameVoid: bool = false,

        pub fn format(self: TypeFormatter, writer: *std.Io.Writer) !void {
            var trimmed = std.mem.trim(u8, self.typeName, &std.ascii.whitespace);
            if (std.mem.endsWith(u8, trimmed, "const*")) {
                try writer.print("[*c]const {f}", .{TypeFormatter{ .typeName = trimmed[0 .. trimmed.len - 6], .renameVoid = true }});
                return;
            }
            if (std.mem.endsWith(u8, trimmed, "*")) {
                if (std.mem.startsWith(u8, trimmed, "const")) {
                    try writer.print("[*c]const {f}", .{TypeFormatter{ .typeName = trimmed[5 .. trimmed.len - 1], .renameVoid = true }});
                    return;
                }
                try writer.print("[*c]{f}", .{TypeFormatter{ .typeName = trimmed[0 .. trimmed.len - 1], .renameVoid = true }});
                return;
            }
            if (std.mem.startsWith(u8, trimmed, "struct ")) {
                try writer.print("{f}", .{TypeFormatter{ .typeName = trimmed[7..] }});
                return;
            }
            if (renameTypes.get(trimmed)) |renamed| {
                try writer.print("{f}", .{TypeFormatter{ .typeName = renamed }});
                return;
            }
            if (self.renameVoid and std.mem.eql(u8, trimmed, "void")) {
                try writer.print("u0", .{});
                return;
            }
            try writer.print("{s}", .{trimmed});
        }
    };

    pub const Type = struct {
        pub const xml_shape = .{
            .name = .{
                .one_of,
                .{ .element, "name", .content_trimmed },
                .{ .attribute, "name" },
            },
        };

        pub const SomeName = union(enum) {
            elem_name: []const u8,
            attr_name: []const u8,
        };

        name: SomeName,
    };

    pub const Kind = struct {
        pub const xml_shape = .{
            .name = .{ .attribute, "name" },
            .desc = .{ .attribute, "desc" },
        };

        name: []const u8,
        desc: []const u8,
    };

    pub const Group = struct {
        pub const xml_shape = .{
            .name = .{ .attribute, "name" },
            .items = .{ .elements, "enum", Enum },
        };

        name: []const u8,
        items: []Enum,
    };

    pub const Enum = struct {
        pub const xml_shape = .{
            .name = .{ .attribute, "name" },
            .value = .{ .attribute, "value" },
            .maybeComment = .{ .maybe, .{ .attribute, "comment" } },
            .maybeGroup = .{ .maybe, .{ .attribute, "group" } },
        };

        name: []const u8,
        value: []const u8,
        maybeComment: ?[]const u8,
        maybeGroup: ?[]const u8,

        pub fn format(self: Enum, writer: *std.Io.Writer) !void {
            try writer.print("pub const {f} = {s};", .{ formatSymbol(self.name), self.value });
        }
    };

    pub const EnumSet = struct {
        pub const xml_shape = .{
            .namespace = .{ .attribute, "namespace" },
            .maybeGroup = .{ .maybe, .{ .attribute, "group" } },
            .comment = .{ .maybe, .{ .attribute, "comment" } },
            .enums = .{ .elements, "enum", Enum },
        };

        namespace: []const u8,
        maybeGroup: ?[]const u8,
        comment: ?[]const u8,
        enums: []Enum,
    };

    pub const Prototype = struct {
        pub const xml_shape = .{
            .retType = .{
                .one_of,
                .{ .element, "ptype", .content_trimmed },
                .content_trimmed,
            },
            .name = .{ .element, "name", .content_trimmed },
        };

        pub const SomeRetType = union(enum) {
            elem_type: []const u8,
            content_type: []const u8,
        };

        retType: SomeRetType,
        name: []const u8,
    };

    pub const Parameter = struct {
        pub const xml_shape = .{
            .maybeGroup = .{ .maybe, .{ .attribute, "group" } },
            .maybeKind = .{ .maybe, .{ .attribute, "kind" } },
            .pType = xml.parse.Tree,
            .name = .{ .element, "name", .content_trimmed },
        };

        pub const PType = union(enum) {
            fixed: struct { []const u8, []const u8, []const u8 },
            prefixed: struct { []const u8, []const u8 },
            postfixed: struct { []const u8, []const u8 },
            pType: []const u8,
            content: []const u8,
        };

        maybeGroup: ?[]const u8,
        maybeKind: ?[]const u8,
        pType: xml.parse.Tree,
        name: []const u8,

        pub const Formatter = struct {
            allocator: std.mem.Allocator,
            parameter: Parameter,

            pub fn format(self: Formatter, writer: *std.Io.Writer) !void {
                try writer.print("{f}: ", .{formatSymbol(self.parameter.name)});

                var type_name: std.Io.Writer.Allocating = .init(self.allocator);
                defer type_name.deinit();

                for (0.., self.parameter.pType.children) |i, child| {
                    if (i != 0) try type_name.writer.print(" ", .{});
                    switch (child) {
                        .text => |text_node| {
                            const trimmed = std.mem.trim(u8, text_node.contents, &std.ascii.whitespace);
                            try type_name.writer.print("{s}", .{trimmed});
                        },
                        .elem => |elem_node| {
                            if (std.mem.eql(u8, elem_node.tag_name, "ptype")) {
                                const text = elem_node.tree.?.concatTextTrimmedAlloc(self.allocator) catch |e| switch (e) {
                                    error.OutOfMemory => return error.WriteFailed,
                                };
                                defer self.allocator.free(text);

                                try type_name.writer.print("{s}", .{text});
                            }
                        },
                        .comment => {},
                    }
                }
                try writer.print("{f}", .{TypeFormatter{ .typeName = type_name.written() }});
            }
        };
    };

    pub const Command = struct {
        pub const xml_shape = .{
            .prototype = .{ .element, "proto", Prototype },
            .parameters = .{ .elements, "param", Parameter },
        };

        prototype: Prototype,
        parameters: []Parameter,

        pub const Formatter = struct {
            allocator: std.mem.Allocator,
            command: Command,
            static: bool,

            pub fn format(self: Formatter, writer: *std.Io.Writer) !void {
                if (self.static) {
                    try writer.print("pub extern fn {f}(", .{formatSymbol(self.command.prototype.name)});
                } else {
                    try writer.print("pub var {f}: *const fn(", .{formatSymbol(self.command.prototype.name)});
                }
                for (0.., self.command.parameters) |i, param| {
                    if (i != 0) {
                        try writer.print(", ", .{});
                    }
                    try writer.print("{f}", .{Parameter.Formatter{ .allocator = self.allocator, .parameter = param }});
                }
                try writer.print(") callconv(.c) {f}", .{TypeFormatter{ .typeName = switch (self.command.prototype.retType) {
                    inline else => |r| r,
                } }});
                if (self.static) {
                    try writer.print(";", .{});
                } else {
                    try writer.print(" = undefined;", .{});
                }
            }
        };
    };

    pub const CommandSet = struct {
        pub const xml_shape = .{
            .namespace = .{ .attribute, "namespace" },
            .commands = .{ .elements, "command", Command },
        };

        namespace: []const u8,
        commands: []Command,

        pub const Formatter = struct {
            allocator: std.mem.Allocator,
            commandSet: CommandSet,

            pub fn format(self: Formatter, writer: *std.Io.Writer) !void {
                for (0.., self.commandSet.commands) |i, command| {
                    if (i != 0) {
                        try writer.print("\n", .{});
                    }
                    try writer.print("{}", .{Command.Formatter{ .allocator = self.allocator, .command = command }});
                }
            }
        };
    };

    pub const FeatureSet = struct {
        pub const xml_shape = .{
            .api = .{ .attribute, "api" },
            .version = .{ .attribute, "name" },
            .maybeNumber = .{ .maybe, .{ .attribute, "number" } },
            .enums = .{ .elements, "require", .{ .elements, "enum", .{ .attribute, "name" } } },
            .commands = .{ .elements, "require", .{ .elements, "command", .{ .attribute, "name" } } },
        };

        api: []const u8,
        version: []const u8,
        maybeNumber: ?[]const u8,
        enums: [][][]const u8,
        commands: [][][]const u8,
    };

    pub const RegistryFormatError = error{ BadFormat, UnknownVersion };

    pub const Registry = struct {
        pub const xml_shape = .{
            .comment = .{ .element, "comment", .content_trimmed },
            .types = .{ .element, "types", .{ .elements, "type", Type } },
            .enums = .{ .elements, "enums", EnumSet },
            .commands = .{ .elements, "commands", CommandSet },
            .features = .{ .elements, "feature", FeatureSet },
        };

        comment: []const u8,
        types: []Type,
        enums: []EnumSet,
        commands: []CommandSet,
        features: []FeatureSet,

        pub const Formatter = struct {
            allocator: std.mem.Allocator,
            registry: Registry,
            api: []const u8,
            version: []const u8,
            static: bool,

            format_error: ?anyerror = null,

            pub fn format(self: *Formatter, writer: *std.Io.Writer) error{WriteFailed}!void {
                self.formatImpl(writer) catch |e| switch (e) {
                    error.WriteFailed => return error.WriteFailed,
                    else => |other_err| {
                        self.format_error = other_err;
                        return error.WriteFailed;
                    },
                };
            }

            fn formatImpl(self: Formatter, writer: *std.Io.Writer) !void {
                const maximumFeature: FeatureSet = for (self.registry.features) |feature| {
                    if (std.mem.eql(u8, feature.api, self.api) and std.mem.eql(u8, feature.version, self.version))
                        break feature;
                } else return RegistryFormatError.UnknownVersion;

                var commandQuickSet = std.StringHashMap(Command).init(self.allocator);
                defer commandQuickSet.deinit();

                var enumQuickSet = std.StringHashMap(Enum).init(self.allocator);
                defer enumQuickSet.deinit();

                for (self.registry.commands) |commandSet| {
                    for (commandSet.commands) |command| {
                        try commandQuickSet.put(command.prototype.name, command);
                    }
                }

                for (self.registry.enums) |enumSet| {
                    for (enumSet.enums) |@"enum"| {
                        try enumQuickSet.put(@"enum".name, @"enum");
                    }
                }

                try writer.print("{s}", .{zigTypeDefs});
                try writer.print("\n\n", .{});

                var enumNames = std.StringHashMap(void).init(self.allocator);
                defer enumNames.deinit();

                var commandNames = std.StringHashMap(void).init(self.allocator);
                defer commandNames.deinit();

                // try commands.append("glGetShaderSource");

                for (self.registry.features) |featureSet| {
                    if (maximumFeature.maybeNumber) |maxNumber| {
                        if (!std.mem.eql(u8, featureSet.api, maximumFeature.api)) continue;
                        const number = featureSet.maybeNumber orelse continue;
                        if (try std.fmt.parseFloat(f32, number) > try std.fmt.parseFloat(f32, maxNumber)) continue;
                    } else {
                        if (!std.mem.eql(u8, featureSet.api, maximumFeature.api) or !std.mem.eql(u8, featureSet.version, maximumFeature.version)) continue;
                    }

                    for (featureSet.enums) |enumSet| {
                        for (enumSet) |enumName| {
                            try enumNames.put(enumName, {});
                        }
                    }

                    for (featureSet.commands) |commandSet| {
                        for (commandSet) |commandName| {
                            try commandNames.put(commandName, {});
                        }
                    }
                }

                var enumIter = enumNames.keyIterator();
                var commandIter = commandNames.keyIterator();

                while (enumIter.next()) |enumName| {
                    const @"enum" = enumQuickSet.get(enumName.*) orelse unreachable;
                    try writer.print("{f}\n", .{@"enum"});
                }

                try writer.print("\n", .{});

                while (commandIter.next()) |commandName| {
                    const command = commandQuickSet.get(commandName.*) orelse unreachable;
                    try writer.print("{f}\n", .{Command.Formatter{ .allocator = self.allocator, .command = command, .static = self.static }});
                }

                if (!self.static) {
                    try writer.print("\n", .{});
                    try writer.print(
                        \\const loadFn = (switch (@import("builtin").os.tag) {{
                        \\    .windows => struct {{
                        \\        pub extern "opengl32" fn wglGetProcAddress(
                        \\            param0: ?[*:0]const u8,
                        \\        ) callconv(.winapi) ?*const fn () callconv(.winapi) isize;
                        \\
                        \\        pub extern "kernel32" fn GetModuleHandleA(moduleName: ?[*:0]const u8) callconv(.winapi) ?*anyopaque;
                        \\        pub extern "kernel32" fn GetProcAddress(handle: ?*anyopaque, moduleName: ?[*:0]const u8) callconv(.winapi) ?*anyopaque;
                        \\
                        \\        pub fn load(procName: [*:0]const u8) ?*anyopaque {{
                        \\            if (wglGetProcAddress(@ptrCast(procName))) |ptr| {{
                        \\                return @ptrCast(@constCast(ptr));
                        \\            }}
                        \\            const libgl = GetModuleHandleA("opengl32");
                        \\            return GetProcAddress(libgl, @ptrCast(procName));
                        \\        }}
                        \\    }},
                        \\    else => |tag| @compileError("Unsupported OS: " ++ @tagName(tag))
                        \\}}).load;
                    , .{});
                    try writer.print("\n\n", .{});
                    try writer.print(
                        \\pub fn init() void {{
                    , .{});
                    var commandIter2 = commandNames.keyIterator();
                    while (commandIter2.next()) |commandName| {
                        try writer.print("\n", .{});
                        const command = commandQuickSet.get(commandName.*) orelse unreachable;
                        try writer.print(
                            \\    {f} = @ptrCast(loadFn("{s}") orelse @panic("Cannot find proc \"{s}\""));
                        , .{ formatSymbol(command.prototype.name), command.prototype.name, command.prototype.name });
                    }
                    try writer.print("\n", .{});
                    try writer.print(
                        \\}}
                    , .{});
                }
            }
        };
    };

    pub const xml_shape = .{
        .registry = .{ .element, "registry", Registry },
    };

    registry: Registry,

    pub fn format(self: GLSpec, writer: *std.Io.Writer) !void {
        try writer.print("{f}", .{self.registry});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(gpa.allocator());
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

    const us1 = std.time.microTimestamp();

    const owned = try xml.Populate(GLSpec).initFromSlice(gpa.allocator(), @embedFile("gl.xml"));
    defer owned.deinit();

    const outFile = try std.fs.cwd().createFile(outputPath, .{});
    defer outFile.close();

    var write_buffer: [4096]u8 = undefined;
    var writer = outFile.writer(&write_buffer);

    var formatter: GLSpec.Registry.Formatter = .{ .allocator = gpa.allocator(), .registry = owned.value.registry, .api = api, .version = version, .static = isWasm };
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
    const us2 = std.time.microTimestamp();
    const ms: usize = @intCast(@divFloor(us2 - us1, 1000));

    if (time) std.debug.print("took {}ms", .{ms});
}
