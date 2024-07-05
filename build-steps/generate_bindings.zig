const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

const generator_root = "src/generator/root.zig";

pub const BuildConfig = enum {
    float_32,
    float_64,
    double_32,
    double_64,
};

pub fn step(
    b: *Build,
    dump_api_step: *Step,
    build_config: BuildConfig,
    force_regen: bool,
    bindings_directory: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    gdextension_interface_module: *Build.Module,
) *Step {
    const generator = makeGeneratorExe(b, target, optimize, gdextension_interface_module);

    const generate_bindings_step = b.step("bindings", "Build godot bindings");

    _ = force_regen;

    // TODO force rebuild if config is different than saved in version

    generate_bindings_step.dependOn(&generator.step);

    // Command for building the bindings to the gen folder
    const build_bindings_cmd = b.addRunArtifact(generator);
    build_bindings_cmd.addFileArg(bindings_directory);
    build_bindings_cmd.addArg(@tagName(build_config));

    generate_bindings_step.dependOn(dump_api_step);
    generate_bindings_step.dependOn(&build_bindings_cmd.step);
    return generate_bindings_step;
}

fn makeGeneratorExe(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    gdextension_interface_module: *Build.Module,
) *Step.Compile {
    const generator_exe = b.addExecutable(.{
        .name = "zgd_generator",
        .root_source_file = b.path(generator_root),
        .target = target,
        .optimize = optimize,
    });
    generator_exe.root_module.addImport("gd", gdextension_interface_module);
    return generator_exe;
}
