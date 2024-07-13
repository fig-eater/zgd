// step for getting ZIG_LIB_DIR
// having this be a step will make it only error when this step is needed.
const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

const GetZigLibDir = @This();

step: Step,
zig_lib_dir: Build.GeneratedFile,

pub fn init(b: *Build) *GetZigLibDir {
    const get_zig_dir = b.allocator.create(GetZigLibDir) catch @panic("OOM");
    get_zig_dir.* = .{
        .step = Step.init(.{
            .name = "get ZIG_LIB_DIR",
            .id = .custom,
            .owner = b,
            .makeFn = &makeFn,
        }),
        .zig_lib_dir = .{ .step = undefined },
    };

    get_zig_dir.zig_lib_dir.step = &get_zig_dir.step;
    std.debug.print("init: {*} {*} {*}\n", .{ get_zig_dir, &get_zig_dir.step, get_zig_dir.zig_lib_dir.step });

    return get_zig_dir;
}

/// Get a lazy path to ZIG_LIB_DIR
pub fn getPath(self: *GetZigLibDir) Build.LazyPath {
    return Build.LazyPath{ .generated = .{ .file = &self.zig_lib_dir } };
}

fn makeFn(step: *Step, _: std.Progress.Node) anyerror!void {
    const get_zig_lib_dir: *GetZigLibDir = @fieldParentPtr("step", step);
    const path: Build.LazyPath = try getZigLibDir(get_zig_lib_dir.step.owner) orelse {
        std.log.err("Failed to get ZIG_LIB_DIR environment variable " ++
            "Please define it or provide the --zig-lib-dir option when running zig build", .{});
        return error.ZigLibDirNotDefined;
    };
    get_zig_lib_dir.zig_lib_dir.path = path.getPath(step.owner);
}

/// Gets a lazy path to the zig lib directory. usually this is located next to the zig executable.
/// Returns null if not set in build options or environment variables.
/// Returns error if failed to get environment variable
fn getZigLibDir(b: *Build) !?Build.LazyPath {
    return if (b.zig_lib_dir) |lib_dir|
        lib_dir
    else if (try std.zig.EnvVar.get(.ZIG_LIB_DIR, b.allocator)) |lib_dir_env|
        Build.LazyPath{ .cwd_relative = lib_dir_env }
    else
        null;
}
