const std = @import("std");
const BuildConfig = @import("../../common.zig").BuildConfig;
const Options = @import("../Options.zig");
const Build = std.Build;
const Step = Build.Step;

const generator_root = "src/generator/root.zig";

const Args = struct {
    generator_exe: *Step.Compile,

    // to be passed into generator
    api_file: Build.LazyPath,
    interface_file: Build.LazyPath,
    include_path: Build.LazyPath,
    precision: Options.Precision,
    target: Build.ResolvedTarget,

    // options
    force_regen: bool,
    bindings_directory: Build.LazyPath, // TODO rename to output dir / remove
};

pub fn addToBuild(b: *Build, args: Args) *Step {
    const generate_bindings_step = b.step("bindings", "generate godot bindings");

    // TODO force rebuild if config is different than saved in version
    _ = args.force_regen;

    const build_config: ?BuildConfig = switch (args.target.result.ptrBitWidth()) {
        32 => switch (args.precision) {
            .single => .float_32,
            .double => .double_32,
        },
        64 => switch (args.precision) {
            .single => .float_64,
            .double => .double_64,
        },
        else => null,
    };

    const check_build_config = CheckBuildConfig.init(b, build_config);

    const build_bindings_cmd = b.addRunArtifact(args.generator_exe);
    if (build_config) |bc|
        build_bindings_cmd.addArg(@tagName(bc));
    build_bindings_cmd.addFileArg(args.api_file);
    build_bindings_cmd.addFileArg(args.interface_file);
    build_bindings_cmd.addFileArg(args.include_path);
    build_bindings_cmd.addFileArg(args.bindings_directory);
    build_bindings_cmd.step.dependOn(&check_build_config.step);

    generate_bindings_step.dependOn(&build_bindings_cmd.step);
    return generate_bindings_step;
}

const CheckBuildConfig = struct {
    step: Step,
    build_config: ?BuildConfig,

    fn init(b: *Build, build_config: ?BuildConfig) *CheckBuildConfig {
        const check_build_config = b.allocator.create(CheckBuildConfig) catch @panic("OOM");
        check_build_config.* = .{
            .step = Step.init(.{
                .name = "check build config",
                .id = .custom,
                .owner = b,
                .makeFn = &makeFn,
            }),
            .build_config = build_config,
        };
        return check_build_config;
    }

    fn makeFn(step: *Step, _: std.Progress.Node) anyerror!void {
        const pre_generate_check: *CheckBuildConfig = @fieldParentPtr("step", step);
        if (pre_generate_check.build_config == null) {
            std.log.err("Target is not supported, target must have bit width of 32 or 64", .{});
            return error.TargetNotSupported;
        }
    }
};

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
