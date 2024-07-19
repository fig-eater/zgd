> [!CAUTION]
> WORK IN PROGRESS NOT READY FOR USE.

# ZGD - Zig Language Bindings for GDExtension

GDExtension bindings generator for the Zig programming language.

> [!WARNING]
> Not intended for godot beginners as documentation may be missing.# ZGD Zig Godot Bindings


## Install

To install or update this package, within your project directory run:

`zig fetch --save https://github.com/fig-eater/zgd/archive/refs/heads/main.tar.gz`

Set the `ZIG_LIB_DIR` environment variable to be the path to the
lib directory of your zig installation.

Then in your build file add an import to "godot" onto the module that needs it.
Here is an example of how you might do this:


```zig
const zgd_dependency = b.dependency("zgd", .{
    .target = target,
    .optimize = optimize,
});

// in a default project `compile_step` might be `lib` or `exe`.
// replace the first "godot" here to avoid namespace conflicts or to
// change the name of the import for your project.
compile_step.root_module.addImport("godot", zgd_dependency.module("godot"));
```

## Usage

Bindings will only be generated if they don't exist or mismatch the godot or zig
version used.

Build Options:
- `-Dzgd-force=true` to force regeneration of bindings.
- `-Dzgd-build-config=[float_32|float_64|double_32|double_64]` Specify build
configuration for bindings. This specifies float size for certain types
(Vectors) and if building for 32-bit or 64-bit architecture. Leave empty to
generate bindings using single precision floats with the local architecture.

## Also See

[godot-zig](https://github.com/godot-zig/godot-zig) - Another zig Godot bindings
project.

[zig-function-overloading](https://github.com/fig-eater/zig-function-overloading) -
Adds explicit function overloading to zig, used within this package.