const Self = @This();
const std = @import("std");
const Step = std.Build.Step;

pub const base_id: Step.Id = .custom;

pub const BuildConfig = enum {
    float_32,
    float_64,
    double_32,
    double_64,
};

pub const Options = struct {
    gdextension_api_file: std.Build.LazyPath,
    gdextension_zig_interface_file: std.Build.LazyPath,
    build_config: BuildConfig,
};

step: Step,
output_root: std.Build.GeneratedFile,
gdextension_api_file: std.Build.LazyPath,
gdextension_zig_interface_file: std.Build.LazyPath,
build_config: BuildConfig,

pub fn create(owner: *std.Build, options: Options) *Self {
    const api_version = owner.allocator.create(Self) catch @panic("OOM");
    const step = Step.init(.{
        .id = base_id,
        .name = "Generate ZGD Bindings",
        .owner = owner,
        .makeFn = make,
    });
    api_version.* = Self{
        .step = step,
        .output_root = .{ .step = step },
        .gdextension_api_file = options.gdextension_api_file,
        .gdextension_zig_interface_file = options.gdextension_zig_interface_file,
        .build_config = BuildConfig,
    };

    return api_version;
}

fn make(step: *Step, _: std.Progress.Node) !void {
    const b = step.owner;
    const self: *Self = @fieldParentPtr("step", step);

    // b.runAllowFail(argv: []const []const u8, out_code: *u8, stderr_behavior: std.process.Child.StdIo)
}
