const std = @import("std");
const builtin = @import("builtin");
const GodotRunner = @import("build/GodotRunner.zig");
const Options = @import("build/Options.zig");
const steps = @import("build/steps.zig");
const local_modules = struct {
    const common = @import("build/local-modules/common_module.zig");
    const aro = @import("build/local-modules/aro_module.zig");
};
const modules = struct {
    const godot = @import("build/modules/godot_module.zig");
};
const Build = std.Build;
const Step = Build.Step;

const bindings_dir = "src/bindings/";

const zgd_module_root = bindings_dir ++ "godot.zig";

pub fn build(b: *Build) !void {
    // config
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // package options
    const opts = Options.init(b);

    // paths
    const zig_lib_dir = @import("build/GetZigLibDir.zig").init(b).getPath();
    const aro_path = Build.LazyPath.path(zig_lib_dir, b, b.pathJoin(&.{ "compiler", "aro", "aro.zig" }));
    const include_path = Build.LazyPath.path(zig_lib_dir, b, "include");

    // helper
    const godot_runner = GodotRunner{
        .build = b,
        // TODO allow for lazy path to built godot exe
        .godot_path = if (opts.godot_path) |p| b.path(p) else null,
    };
    const aro_module = local_modules.aro.addToBuild(b, aro_path);

    // local modules
    const common_module = local_modules.common.addToBuild(b);

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
        .include_path = include_path,
        .precision = opts.precision,
        .target = target,

        // options
        .force_regen = opts.force_bindings_regen,
        .bindings_directory = b.path(bindings_dir),
    });
    _ = steps.@"test".addToBuild(b, .{ .optimize = optimize, .target = target });

    // zgd module
    _ = modules.godot.addToBuild(b, .{
        .zgd_module_root = zgd_module_root,
        .generate_bindings_step = generate_bindings_step,
        .target = target,
        .optimize = optimize,
    });

    b.default_step = generate_bindings_step;
}
