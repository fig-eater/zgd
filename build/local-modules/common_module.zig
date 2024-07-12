const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

pub fn addToBuild(b: *Build) *Build.Module {
    return b.createModule(.{ .root_source_file = b.path("common.zig") });
}
