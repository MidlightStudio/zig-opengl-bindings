# Zig OpenGL Bindings
A fully Zig OpenGL bindings generator, for dynamically loading or through a static interface.

### CURRENTLY ONLY SUPPORTS DYNAMIC LOADING ON WINDOWS

> Updated for Zig [0.13.0](https://ziglang.org/download).

> Uses [edqx/dishwasher](https://github.com/edqx/dishwasher) to parse the [OpenGL XML Spec](https://github.com/KhronosGroup/OpenGL-Registry/blob/main/xml/gl.xml).

## Usage: build.zig
In your build.zig, you can use the `generateBindingsModule` method from the generator's build script:
```zig
const openglBindings = @import("zig-opengl-bindings");
...
const opengl = openglBindings.addBindingsModule(b, .{
    .api = "gles2",
    .version = "GL_ES_VERSION_3_0",
    .static = false,
});
...
executable.root_module.addImport("opengl", opengl);
```

## Usage: Standalone
### Building
Building the standalone binary is as simple as:
```sh
zig build -Doptimize=ReleaseFast
```

### Running
You can then run the script with
```sh
./zig-out/bin/zig-opengl-bindings gles2 GL_ES_VERSION_3_0 out.zig
```
Add `--static` for a static interface
