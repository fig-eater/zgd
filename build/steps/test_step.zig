const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

const Options = struct {
    test_root: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn addToBuild(b: *Build, options: Options) *Step {
    const test_step = b.step("test", "test zgd");
    const test_compile = b.addTest(.{
        .root_source_file = options.test_root,
        .target = options.target,
        .optimize = options.optimize,
    });
    const run = b.addRunArtifact(test_compile);
    test_step.dependOn(&run.step);
    return test_step;
}
