const std = @import("std");
const BuildConfig = @import("../../common.zig").BuildConfig;
const Build = std.Build;
const Step = Build.Step;

const generator_root = "src/generator/root.zig";

const Options = struct {
    build_config: BuildConfig,
    force_regen: bool,

    api_file: Build.LazyPath,
    bindings_directory: Build.LazyPath,

    dump_api_step: *Step,
    generator_exe: *Step.Compile,
};

pub fn addToBuild(b: *Build, options: Options) *Step {
    const generate_bindings_step = b.step("bindings", "generate godot bindings");

    // TODO force rebuild if config is different than saved in version
    _ = options.force_regen;
    // generate_bindings_step.dependOn(&generator.step);

    // Command for building the bindings to the gen folder
    const build_bindings_cmd = b.addRunArtifact(options.generator_exe);
    build_bindings_cmd.addArg(@tagName(options.build_config));
    build_bindings_cmd.addFileArg(options.api_file);
    build_bindings_cmd.addFileArg(options.bindings_directory);

    generate_bindings_step.dependOn(options.dump_api_step);
    generate_bindings_step.dependOn(&build_bindings_cmd.step);
    return generate_bindings_step;
}
