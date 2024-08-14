const std = @import("std");
const builtin = @import("builtin");
const GodotRunner = @import("build/GodotRunner.zig");
const Options = @import("build/Options.zig");
const steps = @import("build/steps.zig");
const local_modules = struct {
    const common = @import("build/local-modules/common_module.zig");
    const aro = @import("build/local-modules/aro_module.zig");
    const gen = @import("build/local-modules/gen_module.zig");
};
const godot_module = @import("build/godot_module.zig");
const Build = std.Build;
const Step = Build.Step;

const gen_dir = "src/";
const gen_root = gen_dir ++ "gen_root.zig";

pub fn build(b: *Build) !void {
    // config
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // package options
    const opts = Options.init(b);

    // helper
    const godot_runner = GodotRunner{
        .build = b,
        // TODO allow for lazy path to built godot exe
        .godot_path = if (opts.godot_path) |p| b.path(p) else null,
    };

    const common_module = local_modules.common.addToBuild(b);
    const aro_module, const aro_include_path = local_modules.aro.addToBuild(b, target, optimize);

    // steps
    const generator_exe = steps.build_generator.addToBuild(b, .{
        .aro_module = aro_module,
        .common_module = common_module,
        .optimize = optimize,
        .target = target,
    });

    const dump_api = steps.dump_api.addToBuild(b, godot_runner, opts.dump_path);
    const generate_bindings_step = steps.generate_bindings.addToBuild(b, .{
        .generator_exe = generator_exe,

        // to be passed into generator
        .api_file = dump_api.api_file,
        .interface_file = dump_api.interface_file,
        .include_path = aro_include_path,
        .precision = opts.precision,
        .target = target,

        // options
        .force_regen = opts.force_bindings_regen,
        .bindings_directory = b.path(gen_dir),
    });

    // gen module
    const gen = local_modules.gen.addToBuild(b, .{
        .generate_bindings_step = generate_bindings_step,
        .root = gen_root,
        .target = target,
        .optimize = optimize,
    });

    // godot module
    _ = godot_module.addToBuild(b, .{
        .gen_module = gen,
        .root = "src/godot_root.zig",
    });

    b.default_step = generate_bindings_step;
}
