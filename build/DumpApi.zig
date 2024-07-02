const DumpApi = @This();
const std = @import("std");
const Step = std.Build.Step;

pub const base_id: Step.Id = .custom;

const default_godot_exe = "godot";

step: Step,
target: std.Build.ResolvedTarget,
godot_path: ?std.Build.LazyPath,
dump_path: std.Build.LazyPath,
translated_interface_file: std.Build.GeneratedFile,
extension_api_file: std.Build.GeneratedFile,

pub const Options = struct {
    godot_path: ?std.Build.LazyPath = null,
    dump_path: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
};

pub fn create(owner: *std.Build, options: Options) *DumpApi {
    const dump_api = owner.allocator.create(DumpApi) catch @panic("OOM");

    const step = Step.init(.{
        .id = base_id,
        .name = "dump gdextension api",
        .owner = owner,
        .makeFn = make,
    });
    dump_api.* = DumpApi{
        .step = step,
        .target = options.target,
        .dump_path = options.dump_path,
        .godot_path = options.godot_path,
        .translated_interface_file = .{ .step = step },
        .extension_api_file = .{ .step = step },
    };

    { // write api version
        const api_version_cmd = owner.addSystemCommand(&.{});
        addFileArgDefault(api_version_cmd, dump_api.godot_path, default_godot_exe);
        api_version_cmd.addArg("--version");
        dump_api.step.dependOn(api_version_cmd);
    }

    { // dump extension api
        const dump_api_cmd = owner.addSystemCommand(&.{});
        addFileArgDefault(dump_api_cmd, dump_api.godot_path, default_godot_exe);
        dump_api_cmd.addArgs(&.{ "--headless", "--dump-extension-api" });
        dump_api_cmd.cwd = dump_api.dump_path;
        dump_api.step.dependOn(&dump_api_cmd.step);
    }

    { // dump gdextension interface
        const dump_interface_cmd = owner.addSystemCommand(&.{});
        addFileArgDefault(dump_interface_cmd, dump_api.godot_path, default_godot_exe);
        dump_interface_cmd.addArgs(&.{ "--headless", "--dump-gdextension-interface" });
        dump_interface_cmd.cwd = dump_api.dump_path;
        dump_api.step.dependOn(&dump_interface_cmd.step);
    }

    return dump_api;
}

fn make(step: *Step, prog_node: std.Progress.Node) !void {
    const b = step.owner;

    const dump_api: *DumpApi = @fieldParentPtr("step", step);

    const file = try b.build_root.handle.createFile("api-dump/" ++ "version", .{});
    defer file.close();
    const writer = file.writer();

    var out_code: u8 = 0;
    const std_out = try b.runAllowFail(&.{ dump_api.godot_path, "--version" }, &out_code, .Ignore);
    defer b.allocator.free(std_out);
    var seq = std.mem.splitSequence(u8, std_out, "\n");
    try writer.print("{s}\n", .{seq.first()});

    var argv_list = std.ArrayList([]const u8).init(b.allocator);
    try argv_list.append(b.graph.zig_exe);
    try argv_list.append("translate-c");
    try argv_list.append("--listen=-");
    if (!dump_api.target.query.isNative()) {
        try argv_list.append("-target");
        try argv_list.append(try dump_api.target.query.zigTriple(b.allocator));
    }
    try argv_list.append("api-dump/gdextension_interface.h");
    const output_path = try step.evalZigProcess(argv_list.items, prog_node);
    dump_api.translated_interface_file.path = output_path;
}

fn addFileArgDefault(run_step: *Step.Run, path: ?std.Build.LazyPath, default: []const u8) void {
    if (path) |p| {
        run_step.addFileArg(p);
    } else {
        run_step.addArg(default);
    }
}
