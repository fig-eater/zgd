const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

pub fn step(
    b: *Build,
    godot_module: *Build.Module,
    example_root: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *Step {
    const example_extension_step = b.step("example", "Build zigodot example");

    const example_extension_lib = b.addSharedLibrary(.{
        .name = "zgd_example",
        .root_source_file = example_root,
        .target = target,
        .optimize = optimize,
    });

    example_extension_lib.root_module.addImport("godot", godot_module);

    const example_extension_install_artifact = b.addInstallArtifact(example_extension_lib, .{});

    example_extension_step.dependOn(&example_extension_install_artifact.step);
    return example_extension_step;
}
