const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

pub fn addToBuild(b: *Build, aro_root: Build.LazyPath) *Build.Module {
    const module = b.createModule(.{
        .root_source_file = aro_root,
    });
    return module;
}
