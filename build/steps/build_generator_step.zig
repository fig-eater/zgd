const std = @import("std");
const BuildConfig = @import("../../common.zig").BuildConfig;
const Build = std.Build;
const Step = Build.Step;

const generator_root = "src/generator_root.zig";

const Args = struct {
    aro_module: *Build.Module,
    common_module: *Build.Module,

    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn addToBuild(b: *Build, args: Args) *Step.Compile {
    const generator_step = b.step(
        "generator",
        "Build and install generator artifact to prefix path",
    );
    const generator_exe = b.addExecutable(.{
        .name = "zgd_generator",
        .root_source_file = b.path(generator_root),
        .target = args.target,
        .optimize = args.optimize,
    });

    generator_exe.root_module.addImport("aro", args.aro_module);
    generator_exe.root_module.addImport("common", args.common_module);

    const install_generator = b.addInstallArtifact(generator_exe, .{});
    generator_step.dependOn(&install_generator.step);
    return generator_exe;
}
