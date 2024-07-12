const std = @import("std");
const builtin = @import("builtin");
const util = @import("build/util.zig");
const steps = struct {
    const build_generator = @import("build/steps/build_generator_step.zig");
    const dump_api = @import("build/steps/dump_api_step.zig");
    const generate_bindings = @import("build/steps/generate_bindings_step.zig");
    const @"test" = @import("build/steps/test_step.zig");
};
const modules = struct {
    const zgd = @import("build/modules/zgd_module.zig");
};
const local_modules = struct {
    const common = @import("build/local-modules/common_module.zig");
    const aro = @import("build/local-modules/aro_module.zig");
};
const Build = std.Build;
const Step = Build.Step;

const BuildConfig = @import("common.zig").BuildConfig;

const Precision = enum { single, double };

const zgd_precision_default = Precision.single;

const bindings_dir = "src/bindings/";

const zgd_module_root = bindings_dir ++ "godot.zig";
const generator_root = "src/generator/root.zig";
const test_root = "src/generator/test.zig";

pub fn build(b: *Build) !void {

    // Config
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zig_lib_dir = try util.getZigLibDir(b) orelse {
        // TODO: get these errors to only run when actually trying to build something.
        //       they currently get triggered if `zig build --help` is ran
        std.log.err("Failed to get ZIG_LIB_DIR environment variable " ++
            "needed for finding the arocc path. " ++
            "Please define it or provide the --zig-lib-dir option when running zig build", .{});
        std.process.exit(1);
    };

    const zgd_godot = b.option(
        []const u8,
        "zgd-godot",
        "Path to godot to use for binding generation. Default uses godot in path",
    );

    const force_bindings_regen = b.option(
        bool,
        "zgd-force",
        "Force regeneration of godot bindings. Default: false",
    ) orelse false;

    const zgd_precision = b.option(
        Precision,
        "zgd-precision",
        "Float precision for bindings. Default: " ++ @tagName(zgd_precision_default),
    ) orelse zgd_precision_default;

    const build_config: BuildConfig = switch (target.result.ptrBitWidth()) {
        32 => switch (zgd_precision) {
            .single => .float_32,
            .double => .double_32,
        },
        64 => switch (zgd_precision) {
            .single => .float_64,
            .double => .double_64,
        },
        else => {
            std.log.err("Target is not supported, target must have bit width of 32 or 64", .{});
            std.process.exit(1);
        },
    };

    const godot_runner = util.GodotRunner{
        .build = b,
        .godot_path = if (zgd_godot) |p| b.path(p) else null,
    };

    const aro_path_root = Build.LazyPath.path(zig_lib_dir, b, b.dupePath("compiler/aro/aro.zig"));

    const common_module = local_modules.common.addToBuild(b);
    const aro_module = local_modules.aro.addToBuild(b, aro_path_root);

    const generator_exe = steps.build_generator.addToBuild(b, .{
        .aro_module = aro_module,
        .common_module = common_module,
        .optimize = optimize,
        .target = target,
    });

    const dumped_api = steps.dump_api.addToBuild(b, target, godot_runner);
    const generate_bindings_step = steps.generate_bindings.addToBuild(b, .{
        .api_file = dumped_api.api_file,
        .bindings_directory = b.path(bindings_dir),
        .build_config = build_config,
        .dump_api_step = dumped_api.step,
        .force_regen = force_bindings_regen,
        .generator_exe = generator_exe,
    });
    _ = steps.@"test".addToBuild(b, .{
        .optimize = optimize,
        .target = target,
        .test_root = b.path(test_root),
    });

    _ = modules.zgd.addToBuild(b, .{
        .zgd_module_root = zgd_module_root,
        .generate_bindings_step = generate_bindings_step,
        .target = target,
        .optimize = optimize,
    });

    b.default_step = generate_bindings_step;
}

// pub fn areBindingsUpToDate(b: *Build, godot_path: []const u8) bool {
//     const version_file = b.build_root.handle.openFile("src/bindings/version", .{}) catch
//         return false;
//     defer version_file.close();

//     const godot_version_cached = version_file.reader().readUntilDelimiterAlloc(
//         b.allocator,
//         '\n',
//         1024,
//     ) catch return false;
//     defer b.allocator.free(godot_version_cached);

//     const zig_version_cached = version_file.reader().readUntilDelimiterAlloc(
//         b.allocator,
//         '\n',
//         1024,
//     ) catch return false;
//     defer b.allocator.free(zig_version_cached);

//     const result = std.process.Child.run(.{
//         .allocator = b.allocator,
//         .argv = &.{ godot_path, "--version" },
//     }) catch return false;
//     defer {
//         b.allocator.free(result.stderr);
//         b.allocator.free(result.stdout);
//     }
//     var seq = std.mem.splitSequence(u8, result.stdout, "\n");
//     return (std.mem.eql(u8, godot_version_cached, seq.first()) and
//         std.mem.eql(u8, zig_version_cached, builtin.zig_version_string));
// }
