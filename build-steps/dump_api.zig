const std = @import("std");
const runGodot = @import("../build.zig").runGodot;
const Build = std.Build;
const Step = Build.Step;

pub const DumpedApi = struct {
    step: *Step,
    api_file: Build.LazyPath,
    gdextension_interface_module: *Build.Module,
};

pub fn step(
    b: *Build,
    target: std.Build.ResolvedTarget,
    godot_path: ?Build.LazyPath,
) DumpedApi {
    const dump_api_step = b.step("dump-api", "Dump GDExtension api");

    var dumped_api: DumpedApi = undefined;
    dumped_api.step = dump_api_step;

    const api_file = blk: { // dump extension_api
        var dump_api = runGodot(b, godot_path, &.{ "--headless", "--dump-extension-api" });
        const extension_api_file = dump_api.addOutputFileArg("extension_api.json");
        dump_api.cwd = extension_api_file.dirname();
        dump_api_step.dependOn(&dump_api.step);
        break :blk extension_api_file;
    };

    const gdextension_interface_module = blk: { // dump and translate interface
        var dump_interface = runGodot(b, godot_path, &.{
            "--headless",
            "--dump-gdextension-interface",
        });
        const c_interface_file = dump_interface.addOutputFileArg("gdextension_interface.h");
        dump_interface.cwd = c_interface_file.dirname();

        const zig_interface_file = b.addTranslateC(.{
            .root_source_file = c_interface_file,
            .optimize = .Debug,
            .target = target,
        });
        dump_api_step.dependOn(&zig_interface_file.step);

        break :blk b.createModule(.{ .root_source_file = zig_interface_file.getOutput() });
    };

    return .{
        .step = dump_api_step,
        .api_file = api_file,
        .gdextension_interface_module = gdextension_interface_module,
    };
}
