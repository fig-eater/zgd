const ApiVersion = @This();
const std = @import("std");
const Step = std.Build.Step;

pub const base_id: Step.Id = .custom;

step: Step,
godot_path: ?std.Build.LazyPath,
version_file: std.Build.GeneratedFile,

pub const Options = struct {
    godot_path: ?std.Build.LazyPath = null,
};

pub fn create(owner: *std.Build, options: Options) *ApiVersion {
    const api_version = owner.allocator.create(ApiVersion) catch @panic("OOM");
    const step = Step.init(.{
        .id = base_id,
        .name = "gdextension api version",
        .owner = owner,
        .makeFn = make,
    });
    api_version.* = ApiVersion{
        .step = step,
        .godot_path = options.godot_path,
        .version_file = .{ .step = step },
    };

    return api_version;
}

fn make(step: *Step, _: std.Progress.Node) !void {
    const b = step.owner;

    const dump_api: *ApiVersion = @fieldParentPtr("step", step);

    const file = try b.build_root.handle.createFile("api-dump/" ++ "version", .{});
    defer file.close();
    const writer = file.writer();

    var out_code: u8 = 0;
    const std_out = try b.runAllowFail(&.{ dump_api.godot_path, "--version" }, &out_code, .Ignore);
    defer b.allocator.free(std_out);
    var seq = std.mem.splitSequence(u8, std_out, "\n");
    try writer.print("{s}\n{s}\n", .{ seq.first(), @import("builtin").zig_version_string });

    dump_api.version_file.getPath();
}
