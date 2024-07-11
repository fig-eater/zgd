const std = @import("std");
const BuildConfig = @import("../common.zig").BuildConfig;
const Build = std.Build;
const Step = Build.Step;

const generator_root = "src/generator/root.zig";

pub fn step(
    b: *Build,
    dump_api_step: *Step,
    api_file: Build.LazyPath,
    build_config: BuildConfig,
    force_regen: bool,
    bindings_directory: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    aro_module: *Build.Module,
    gdextension_interface_module: *Build.Module,
) *Step {
    const generate_bindings_step = b.step("bindings", "generate godot bindings");

    const generator = makeGeneratorExe(
        b,
        target,
        optimize,
        aro_module,
        gdextension_interface_module,
    );

    _ = force_regen;

    // TODO force rebuild if config is different than saved in version

    // generate_bindings_step.dependOn(&generator.step);

    // Command for building the bindings to the gen folder
    const build_bindings_cmd = b.addRunArtifact(generator);
    build_bindings_cmd.addArg(@tagName(build_config));
    build_bindings_cmd.addFileArg(api_file);
    build_bindings_cmd.addFileArg(bindings_directory);

    generate_bindings_step.dependOn(dump_api_step);
    generate_bindings_step.dependOn(&build_bindings_cmd.step);
    return generate_bindings_step;
}

fn makeGeneratorExe(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    aro_module: *Build.Module,
    gdextension_interface_module: *Build.Module,
) *Step.Compile {
    const generator_exe = b.addExecutable(.{
        .name = "zgd_generator",
        .root_source_file = b.path(generator_root),
        .target = target,
        .optimize = optimize,
    });
    generator_exe.root_module.addImport("aro", aro_module);
    generator_exe.root_module.addImport("gdextension_interface", gdextension_interface_module);

    const common_module = b.createModule(.{ .root_source_file = b.path("common.zig") });

    generator_exe.root_module.addImport("common", common_module);
    return generator_exe;
}
