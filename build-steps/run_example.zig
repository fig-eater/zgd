const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const ResolvedTarget = Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;

pub fn step(
    b: *Build,
    zgd_module: *Build.Module,
    example_root: Build.LazyPath,
    target: ResolvedTarget,
    optimize: OptimizeMode,
) *Step {
    const run_example_step = b.step("run-example", "Run zigodot example");
    const example_exe = b.addExecutable(.{
        .name = "zgd_example",
        .root_source_file = example_root,
        .target = target,
        .optimize = optimize,
    });
    // place the exe in the install directory
    const example_exe_install_artifact = b.addInstallArtifact(example_exe, .{});
    example_exe.root_module.addImport("godot", zgd_module);
    // run the exe
    const run_artifact = b.addRunArtifact(example_exe_install_artifact.artifact);

    run_example_step.dependOn(&example_exe_install_artifact.step);
    run_example_step.dependOn(&run_artifact.step);
    return run_example_step;
}
