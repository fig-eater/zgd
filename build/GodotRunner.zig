const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

build: *Build,
godot_path: ?Build.LazyPath = null,

/// Create a run step that runs godot with optional args.
/// If `godot_path` is not provided it will use the godot found in the path.
pub fn run(self: @This(), args: ?[]const []const u8) *Step.Run {
    const run_godot = Step.Run.create(self.build, "run godot");
    if (self.godot_path) |p| {
        run_godot.addFileArg(p);
    } else {
        run_godot.addArg("godot");
    }
    if (args) |a| {
        run_godot.addArgs(a);
    }
    return run_godot;
}
