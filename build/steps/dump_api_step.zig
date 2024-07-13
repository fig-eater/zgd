const std = @import("std");
const GodotRunner = @import("../GodotRunner.zig");
const Build = std.Build;
const Step = Build.Step;

pub const DumpApi = struct {
    step: Step,
    api_file: Build.LazyPath,
    interface_file: Build.LazyPath,
    pub fn init(b: *Build, godot_runner: GodotRunner) *DumpApi {
        const dump_api = b.allocator.create(DumpApi) catch @panic("OOM");
        dump_api.step = Step.init(.{
            .name = "dump api",
            .id = .custom,
            .owner = b,
        });

        { // dump extension_api
            var run_godot = godot_runner.run(&.{ "--headless", "--dump-extension-api" });
            dump_api.api_file = run_godot.addOutputFileArg("extension_api.json");
            run_godot.cwd = dump_api.api_file.dirname();
            dump_api.api_file.addStepDependencies(&dump_api.step);
        }

        {
            var run_godot = godot_runner.run(&.{ "--headless", "--dump-gdextension-interface" });
            dump_api.interface_file = run_godot.addOutputFileArg("gdextension_interface.h");
            run_godot.cwd = dump_api.interface_file.dirname();
            dump_api.interface_file.addStepDependencies(&dump_api.step);
        }

        return dump_api;
    }
};

pub fn addToBuild(
    b: *Build,
    godot_runner: GodotRunner,
) *DumpApi {
    const dump_api_step = b.step("dump-api", "Dump GDExtension api");
    const dump_api = DumpApi.init(b, godot_runner);
    dump_api_step.dependOn(&dump_api.step);
    return dump_api;
}
