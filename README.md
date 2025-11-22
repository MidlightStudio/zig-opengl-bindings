# Zig OpenGL Bindings
An OpenGL bindings generator for Zig. Includes dynamically loading.

## Usage: build.zig
In your build.zig, you can use the `createBindingsModule` method from the generator's build script:
```zig
const opengl_bindings_dependency = b.dependency("opengl_bindings", .{
    .api = "gles2",
    .version = "GL_ES_VERSION_3_0",
});
...
module.addImport("gl", opengl_bindings_dependency.module("gl"));
```

## Usage: Standalone
### Building
Building the standalone binary is as simple as:
```sh
zig build -Doptimize=ReleaseFast
```

You can then run the generator with

```sh
./zig-out/bin/opengl-bindings gles2 GL_ES_VERSION_3_0 output.zig
```

## Usage: Loading
Once the module has been imported, e.g. `const gl = @import("gl")`, you can use `gl.init()` to load all relevant functions.

- All GL functions are the same as in [the reference](https://registry.khronos.org/OpenGL-Refpages/gl4/) except that the `gl` prefix is removed. For instance: `glClear` becomes `gl.clear()`

- All enums are the same as in the reference, except that the `GL_` prefix is removed. For instance: `GL_RGBA` becomes `gl.RGBA`

## Static Interface
You can generate a static interface (for example, calling WASM functions) by using either `.static = true` in the create module config or passing `--static` to the standalone generator.