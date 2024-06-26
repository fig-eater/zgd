> [!CAUTION]
> WORK IN PROGRESS NOT READY FOR USE.

# ZGD Zig Godot Bindings

GDExtension bindings generator for the Zig programming language.

> [!WARNING]
> Not intended for godot beginners as documentation may be missing.# ZGD Zig Godot Bindings


## Install

To install or update this package, within your project directory run:

`zig fetch --save https://github.com/fig-eater/zigodot/archive/refs/heads/main.tar.gz`

Then in your build file add an import to "godot" onto the module that needs it.
Here is an example of how you might do this:

```zig
const zgd_dependency = b.dependency("zigodot", .{
    .target = target,
    .optimize = optimize,
});

// in a default project `compile_step` might be `lib` or `exe`.
// replace the first "godot" here to avoid namespace conflicts or to
// change the name of the import for your project.
compile_step.root_module.addImport("godot", zgd_dependency.module("zigodot"));
```

## Usage

Bindings will only be generated if they don't exist or mismatch the godot or zig
version used.

Include `-Dregen-zigodot=true` to force regeneration of bindings.

## Also See

[godot-zig](https://github.com/godot-zig/godot-zig) - Another zig Godot bindings
project.

[zig-function-overloading](https://github.com/fig-eater/zig-function-overloading) -
Adds explicit function overloading to zig, used within this package.