const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

pub fn addToBuild(b: *Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) struct { *Build.Module, Build.LazyPath } {
    const aro_dep = b.dependency("aro", .{
        .target = target,
        .optimize = optimize,
    });
    const aro_module = aro_dep.module("aro");
    return .{ aro_module, aro_dep.builder.path("include") };
}
