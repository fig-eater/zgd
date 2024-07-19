const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

pub fn addToBuild(b: *Build, aro_root: Build.LazyPath) *Build.Module {
    _ = aro_root;

    const module = b.createModule(.{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "aro/" } },
    });
    return module;
}
