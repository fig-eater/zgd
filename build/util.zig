const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

/// Gets a lazy path to the zig lib directory. usually this is located next to the zig executable.
/// Returns null if not set in build options or environment variables.
/// Returns error if failed to get environment variable
pub fn getZigLibDir(b: *Build) !?Build.LazyPath {
    return if (b.zig_lib_dir) |lib_dir|
        lib_dir
    else if (try std.zig.EnvVar.get(.ZIG_LIB_DIR, b.allocator)) |lib_dir_env|
        Build.LazyPath{ .cwd_relative = lib_dir_env }
    else
        null;
}

pub const GodotRunner = struct {
    build: *Build,
    godot_path: ?Build.LazyPath = null,

    /// Create a run step that runs godot with optional args.
    /// If `godot_path` is not provided it will use the godot found in the path.
    pub fn run(self: GodotRunner, args: ?[]const []const u8) *Step.Run {
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
};
