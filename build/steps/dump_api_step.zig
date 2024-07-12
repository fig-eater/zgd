const std = @import("std");
const util = @import("../util.zig");
const Build = std.Build;
const Step = Build.Step;

pub const DumpedApi = struct {
    step: *Step,
    api_file: Build.LazyPath,
    interface_file: Build.LazyPath,
};

pub fn addToBuild(
    b: *Build,
    godot_runner: util.GodotRunner,
) DumpedApi {
    const dump_api_step = b.step("dump-api", "Dump GDExtension api");

    var dumped_api: DumpedApi = undefined;
    dumped_api.step = dump_api_step;

    const api_file = blk: { // dump extension_api
        var dump_api = godot_runner.run(&.{ "--headless", "--dump-extension-api" });
        const extension_api_file = dump_api.addOutputFileArg("extension_api.json");
        dump_api.cwd = extension_api_file.dirname();
        dump_api_step.dependOn(&dump_api.step);
        break :blk extension_api_file;
    };

    var dump_interface = godot_runner.run(&.{
        "--headless",
        "--dump-gdextension-interface",
    });
    const interface_file = dump_interface.addOutputFileArg("gdextension_interface.h");
    dump_interface.cwd = interface_file.dirname();

    return .{
        .step = dump_api_step,
        .api_file = api_file,
        .interface_file = interface_file,
    };
}
