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

    pub const renameSymbols = std.StaticStringMap(void).initComptime(.{
        .{ "packed", {} }
    });

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
    
    fn formatSymbolImpl(symbolName: []const u8, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (std.mem.startsWith(u8, symbolName, "gl")) {
            try writer.writeByte(symbolName[2] + ('a' - 'A'));
            try writer.print("{}", .{ formatSymbol(symbolName[3..]) });
            return;
        }
        if (std.mem.startsWith(u8, symbolName, "GL_")) {
            try writer.print("{}", .{ formatSymbol(symbolName[3..]) });
            return;
        }
        switch (symbolName[0]) {
            '0'...'9' => {
                try writer.print("@\"{s}\"", .{ symbolName });
            },
            else => {
                if (renameSymbols.get(symbolName)) |_| {
                    try writer.print("@\"{s}\"", .{ symbolName });
                    return;
                }
                try writer.print("{s}", .{ symbolName });
            }
        }
    }

    pub fn formatSymbol(symbolName: []const u8) std.fmt.Formatter(formatSymbolImpl) {
        return .{ .data = symbolName };
    }

    pub const TypeFormatter = struct {
        typeName: []const u8,
        renameVoid: bool = false,

        pub fn format(self: TypeFormatter, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            var trimmed = std.mem.trim(u8, self.typeName, &std.ascii.whitespace);
            if (std.mem.endsWith(u8, trimmed, "const*")) {
                try writer.print("[*c]const {}", .{ TypeFormatter{ .typeName = trimmed[0..trimmed.len - 6], .renameVoid = true } });
                return;
            }
            if (std.mem.endsWith(u8, trimmed, "*")) {
                if (std.mem.startsWith(u8, trimmed, "const")) {
                    try writer.print("[*c]const {}", .{ TypeFormatter{ .typeName = trimmed[5..trimmed.len - 1], .renameVoid = true } });
                    return;
                }
                try writer.print("[*c]{}", .{ TypeFormatter{ .typeName = trimmed[0..trimmed.len - 1], .renameVoid = true } });
                return;
            }
            if (std.mem.startsWith(u8, trimmed, "struct ")) {
                try writer.print("{}", .{ TypeFormatter{ .typeName = trimmed[7..] } });
                return;
            }
            if (renameTypes.get(trimmed)) |renamed| {
                try writer.print("{}", .{ TypeFormatter{ .typeName = renamed } });
                return;
            }
            if (self.renameVoid and std.mem.eql(u8, trimmed, "void")) {
                try writer.print("u0", .{ });
                return;
            }
            try writer.print("{s}", .{ trimmed });
        }
    };

    pub const Type = struct {
        pub const XmlShape = .{
            .name = xml.disjunction(.{
                xml.singleElement("name", xml.elementContent(.trim)),
                xml.attribute("name")
            })
        };

        name: []const u8
    };

    pub const Kind = struct {
        pub const XmlShape = .{
            .name = xml.attribute("name"),
            .desc = xml.attribute("desc"),
        };

        name: []const u8,
        desc: []const u8,
    };

    pub const Group = struct {
        pub const XmlShape = .{
            .name = xml.attribute("name"),
            .items = xml.manyElements("enum", Enum)
        };

        name: []const u8,
        items: []Enum,
    };

    pub const Enum = struct {
        pub const XmlShape = .{
            .name = xml.attribute("name"),
            .value = xml.attribute("value"),
            .maybeComment = xml.maybe(xml.attribute("comment")),
            .maybeGroup = xml.maybe(xml.attribute("group")),
        };

        name: []const u8,
        value: []const u8,
        maybeComment: ?[]const u8,
        maybeGroup: ?[]const u8,

        pub fn format(self: Enum, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.print("pub const {s} = {s};", .{ formatSymbol(self.name), self.value });
        }
    };

    pub const EnumSet = struct {
        pub const XmlShape = .{
            .namespace = xml.attribute("namespace"),
            .maybeGroup = xml.maybe(xml.attribute("group")),
            .comment = xml.maybe(xml.attribute("comment")),
            .enums = xml.manyElements("enum", Enum)
        };

        namespace: []const u8,
        maybeGroup: ?[]const u8,
        comment: ?[]const u8,
        enums: []Enum,
    };

    pub const Prototype = struct {
        pub const XmlShape = .{
            .retType = xml.disjunction(.{
                xml.singleElement("ptype", xml.elementContent(.trim)),
                xml.elementContent(.trim),
            }),
            .name = xml.singleElement("name", xml.elementContent(.trim)),
        };

        retType: []const u8,
        name: []const u8,
    };

    pub const Parameter = struct {
        pub const XmlShape = .{
            .maybeGroup = xml.maybe(xml.attribute("group")),
            .maybeKind = xml.maybe(xml.attribute("kind")),
            .pType = xml.disjunction(.{
                xml.pattern(.{
                    xml.elementContent(.trim),
                    xml.singleElement("ptype", xml.elementContent(.trim)),
                    xml.elementContent(.trim),
                }),
                xml.pattern(.{
                    xml.singleElement("ptype", xml.elementContent(.trim)),
                    xml.elementContent(.trim),
                }),
                xml.pattern(.{
                    xml.elementContent(.trim),
                    xml.singleElement("ptype", xml.elementContent(.trim)),
                }),
                xml.singleElement("ptype", xml.elementContent(.trim)),
                xml.elementContent(.trim) // used for const void* parameters
            }),
            .name = xml.singleElement("name", xml.elementContent(.trim)),
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
        pType: PType,
        name: []const u8,

        pub const Formatter = struct {
            allocator: std.mem.Allocator,
            parameter: Parameter,

            pub fn format(self: Formatter, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
                try writer.print("{}: ", .{ formatSymbol(self.parameter.name) });
                switch (self.parameter.pType) {
                    .fixed => |parts| {
                        const typeName = try std.fmt.allocPrint(self.allocator, "{s} {s} {s}", .{ parts[0], parts[1], parts[2] });
                        defer self.allocator.free(typeName);
                        try writer.print("{}", .{ TypeFormatter{ .typeName = typeName } });
                    },
                    inline .prefixed, .postfixed => |parts| {
                        const typeName = try std.fmt.allocPrint(self.allocator, "{s} {s}", .{ parts[0], parts[1] });
                        defer self.allocator.free(typeName);
                        try writer.print("{}", .{ TypeFormatter{ .typeName = typeName } });
                    },
                    .pType => |pType| {
                        try writer.print("{}", .{ TypeFormatter{ .typeName = pType } });
                    },
                    .content => |content| {
                        try writer.print("{}", .{   TypeFormatter{ .typeName = content } });
                    }
                }
            }
        };
    };

    pub const Command = struct {
        pub const XmlShape = .{
        .prototype = xml.singleElement("proto", Prototype),
            .parameters = xml.manyElements("param", Parameter),
        };

        prototype: Prototype,
        parameters: []Parameter,

        pub const Formatter = struct {
            allocator: std.mem.Allocator,
            command: Command,
            static: bool,

            pub fn format(self: Formatter, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
                if (self.static) {
                    try writer.print("pub extern fn {}(", .{ formatSymbol(self.command.prototype.name) });
                } else {
                    try writer.print("pub var {}: *const fn(", .{ formatSymbol(self.command.prototype.name) });
                }
                for (0.., self.command.parameters) |i, param| {
                    if (i != 0) {
                        try writer.print(", ", .{});
                    }
                    try writer.print("{}", .{ Parameter.Formatter{ .allocator = self.allocator, .parameter = param } });
                }
                try writer.print(") callconv(.C) {}", .{ TypeFormatter{ .typeName = self.command.prototype.retType } });
                if (self.static) {
                    try writer.print(";", .{});
                } else {
                    try writer.print(" = undefined;", .{});
                }
            }
        };
    };

    pub const CommandSet = struct {
        pub const XmlShape = .{
            .namespace = xml.attribute("namespace"),
            .commands = xml.manyElements("command", Command),
        };

        namespace: []const u8,
        commands: []Command,
        
        pub const Formatter = struct {
            allocator: std.mem.Allocator,
            commandSet: CommandSet,

            pub fn format(self: Formatter, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
                for (0.., self.commandSet.commands) |i, command| {
                    if (i != 0) {
                        try writer.print("\n", .{});
                    }
                    try writer.print("{}", .{ Command.Formatter{ .allocator = self.allocator, .command = command } });
                }
            }
        };
    };

    pub const FeatureSet = struct {
        pub const XmlShape = .{
            .api = xml.attribute("api"),
            .version = xml.attribute("name"),
            .maybeNumber = xml.maybe(xml.attribute("number")),
            .enums = xml.manyElements("require", xml.manyElements("enum", xml.attribute("name"))),
            .commands = xml.manyElements("require", xml.manyElements("command", xml.attribute("name"))),
        };

        api: []const u8,
        version: []const u8,
        maybeNumber: ?[]const u8,
        enums: [][][]const u8,
        commands: [][][]const u8,
    };

    pub const RegistryFormatError = error { BadFormat, UnknownVersion };

    pub const Registry = struct {
        pub const XmlShape = .{
            .comment = xml.singleElement("comment", xml.elementContent(.verbatim)),
            .types = xml.singleElement("types", xml.manyElements("type", Type)),
            .enums = xml.manyElements("enums", EnumSet),
            .commands = xml.manyElements("commands", CommandSet),
            .features = xml.manyElements("feature", FeatureSet),
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

            pub fn format(self: Formatter, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
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

                try writer.print("{s}", .{ zigTypeDefs });
                try writer.print("\n\n", .{});

                var enums = std.ArrayList([]const u8).init(self.allocator);
                defer enums.deinit();
                
                var commands = std.ArrayList([]const u8).init(self.allocator);
                defer commands.deinit();

                // try commands.append("glGetShaderSource");

                for (self.registry.features) |featureSet| {
                    if (maximumFeature.maybeNumber) |maxNumber| {
                        if (!std.mem.eql(u8, featureSet.api, maximumFeature.api)) continue;
                        const number = featureSet.maybeNumber orelse continue;
                        if (try std.fmt.parseFloat(f32, number) > try std.fmt.parseFloat(f32, maxNumber)) continue;
                    } else {
                        if (!std.mem.eql(u8, featureSet.api, maximumFeature.api)
                            or !std.mem.eql(u8, featureSet.version, maximumFeature.version)) continue;
                    }
                    
                    for (featureSet.enums) |enumSet| {
                        try enums.appendSlice(enumSet);
                    }

                    for (featureSet.commands) |commandSet| {
                        try commands.appendSlice(commandSet);
                    }
                }
                
                for (enums.items) |enumName| {
                    const @"enum" = enumQuickSet.get(enumName) orelse unreachable;
                    try writer.print("{}\n", .{ @"enum" });
                }

                try writer.print("\n", .{});

                for (commands.items) |commandName| {
                    const command = commandQuickSet.get(commandName) orelse unreachable;
                    try writer.print("{}\n", .{ Command.Formatter{ .allocator = self.allocator, .command = command, .static = self.static } });
                }

                if (!self.static) {
                    try writer.print("\n", .{});
                    try writer.print(
\\const loadFn = (switch (@import("builtin").os.tag) {{
\\    .windows => struct {{
\\        pub const WINAPI = @import("std").os.windows.WINAPI;
\\
\\        pub extern "opengl32" fn wglGetProcAddress(
\\            param0: ?[*:0]const u8,
\\        ) callconv(WINAPI) ?*const fn () callconv(WINAPI) isize;
\\
\\        pub extern "kernel32" fn GetModuleHandleA(moduleName: ?[*:0]const u8) callconv(WINAPI) ?*anyopaque;
\\        pub extern "kernel32" fn GetProcAddress(handle: ?*anyopaque, moduleName: ?[*:0]const u8) callconv(WINAPI) ?*anyopaque;
\\
\\        pub fn load(procName: [*:0]const u8) ?*anyopaque {{
\\            if (wglGetProcAddress(@ptrCast(procName))) |ptr| {{
\\                return @ptrCast(@constCast(ptr));
\\            }}
\\            @import("std").log.info("loading: {{s}}", .{{ procName }});
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
                    for (commands.items) |commandName| {
                        try writer.print("\n", .{});
                        const command = commandQuickSet.get(commandName) orelse unreachable;
                        try writer.print(
\\    {} = @ptrCast(loadFn("{s}") orelse @panic("Cannot find proc \"{s}\""));
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

    pub const XmlShape = .{
        .registry = xml.singleElement("registry", Registry)
    };

    registry: Registry,

    pub fn format(self: GLSpec, comptime fmt: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{" ++ fmt ++ "}", .{ self.registry });
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
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--static")) isWasm = true;
    }

    var document = try xml.parseXmlFull(gpa.allocator(), @embedFile("gl.xml"));
    defer document.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    const spec = try document.doc.createValue(GLSpec, arena.allocator());
    defer arena.deinit();

    const outFile = try std.fs.cwd().createFile(outputPath, .{ });
    defer outFile.close();

    const formatter = GLSpec.Registry.Formatter{
        .allocator = gpa.allocator(),
        .registry = spec.registry,
        .api = api,
        .version = version,
        .static = isWasm
    };
    try outFile.writer().print(
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
    , .{ "2024", api, version, isWasm });
    try outFile.writer().print("\n{}", .{ formatter });
}