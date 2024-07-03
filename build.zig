const std = @import("std");
const builtin = @import("builtin");

const Build = std.Build;
const Step = Build.Step;
const Target = Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;

const BuildConfig = @import("build/GenerateBindings.zig");

const Precision = enum { single, double };

pub const zigodot_module_name = "godot";

const zgd_godot_name = "zgd-godot";
const zgd_godot_default = "godot";

const bindings_dir = "src/bindings/";
const api_dump_dir = "api-dump/";

const zigodot_module_root = bindings_dir ++ "godot.zig";
const bindings_header = bindings_dir ++ "header.zig";
const generator_root = "src/generator/root.zig";
const example_root = "src/example/example_extension.zig";

pub fn build(b: *Build) !void {

    // Config
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zgd_godot = b.option(
        []const u8,
        zgd_godot_name,
        "Path to godot to use for binding generation. Default: " ++ zgd_godot_default,
    ) orelse zgd_godot_default;

    const zgd_force = b.option(
        bool,
        "zgd-force",
        "Force regeneration of godot bindings. Default: false",
    ) orelse false;

    const zgd_precision = b.option(
        Precision,
        "zgd-precision",
        "Float precision for bindings. Default: single",
    ) orelse .single;

    const build_config: BuildConfig = switch (target.result.ptrBitWidth()) {
        32 => switch (zgd_precision) {
            .single => .float_32,
            .double => .double_32,
        },
        64 => switch (zgd_precision) {
            .single => .float_64,
            .double => .double_64,
        },
        else => @panic("Target is not supported, must have bit width of 32 or 64"),
    };

    const generator_exe_artifact = createGeneratorExeArtifact(b, target, optimize);
    _ = buildRunGeneratorStep(b, generator_exe_artifact);
    const dump_api = dumpApiStep(b, target, zgd_godot);
    const bindings_step = buildBindingsStep(
        b,
        generator_exe_artifact,
        dump_api.step,
        zgd_force,
        build_config,
        zgd_godot,
    );

    _ = addModule(b, bindings_step, target, optimize);
    _ = buildExampleExtensionStep(b, target, optimize);
    _ = runExampleStep(b, target, optimize);
}

pub fn createGeneratorExeArtifact(
    b: *Build,
    target: Target,
    optimize: OptimizeMode,
) *Step.InstallArtifact {
    // generator executable compile step
    const generator_exe = b.addExecutable(.{
        .name = "zigodot_generator",
        .root_source_file = b.path(generator_root),
        .target = target,
        .optimize = optimize,
    });
    const generator_exe_artifact = b.addInstallArtifact(generator_exe, .{});
    return generator_exe_artifact;
}

pub fn buildRunGeneratorStep(b: *Build, generator_exe_artifact: *Step.InstallArtifact) *Step {
    const run_generator_step = b.step("run", "Run the generator");

    // User runs generator from zig build run
    const run_cmd = b.addRunArtifact(generator_exe_artifact.artifact);
    run_cmd.step.dependOn(&generator_exe_artifact.step);

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    run_generator_step.dependOn(&run_cmd.step);

    return run_generator_step;
}

pub fn buildBindingsStep(
    b: *Build,
    options: struct {
        dump_api_step: *Step,
        generator_exe_artifact: *Step.InstallArtifact,
        build_config: BuildConfig,
        force_regen: bool,
    },
) *Step {
    const this_step = b.step("bindings", "Build godot bindings");

    // TODO force rebuild if config is different than saved in version

    this_step.dependOn(&options.generator_exe_artifact.step);

    // Command for building the bindings to the gen folder
    const build_bindings_cmd = b.addRunArtifact(options.generator_exe_artifact.artifact);
    build_bindings_cmd.addArgs(&.{ b.dupePath(bindings_dir), @tagName(options.build_config) });

    this_step.dependOn(options.dump_api_step);
    this_step.dependOn(&build_bindings_cmd.step);
    return this_step;
}

pub fn addModule(
    b: *Build,
    build_bindings_step: *Step,
    target: Target,
    optimize: OptimizeMode,
) *Build.Module {
    // define root file of zigodot generated by bindings step
    // this being a generated file will make it so when the zigodot_module is requested
    // it will run the bindings_step to generate the root file
    const generated_file = b.allocator.create(Build.GeneratedFile) catch @panic("OOM");
    generated_file.* = .{
        .step = build_bindings_step,
        .path = b.dupePath(zigodot_module_root),
    };

    const overloading_dependency = b.dependency("overloading", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.addModule(zigodot_module_name, .{
        .root_source_file = .{ .generated = .{ .file = generated_file } },
        .imports = &.{
            .{ .name = "overloading", .module = overloading_dependency.module("overloading") },
        },
        .link_libc = true,
    });
    module.addIncludePath(b.path("src/bindings/api/"));
    return module;
}

pub fn buildExampleExtensionStep(
    b: *Build,
    target: Target,
    optimize: OptimizeMode,
) *Step {
    const example_extension_step = b.step("example", "Build zigodot example");

    const example_extension_lib = b.addSharedLibrary(.{
        .name = "zigodot_example",
        .root_source_file = b.path(example_root),
        .target = target,
        .optimize = optimize,
    });

    example_extension_lib.root_module.addImport(
        zigodot_module_name,
        b.modules.get(zigodot_module_name).?,
    );

    const example_extension_install_artifact = b.addInstallArtifact(example_extension_lib, .{});

    example_extension_step.dependOn(&example_extension_install_artifact.step);
    return example_extension_step;
}

pub fn runExampleStep(b: *Build, target: Target, optimize: OptimizeMode) *Step {
    const run_example_step = b.step("run-example", "Run zigodot example");
    const example_exe = b.addExecutable(.{
        .name = "zgd_example",
        .root_source_file = b.path(example_root),
        .target = target,
        .optimize = optimize,
    });
    // place the exe in the install directory
    const example_exe_install_artifact = b.addInstallArtifact(example_exe, .{});
    example_exe.root_module.addImport(zigodot_module_name, b.modules.get(zigodot_module_name).?);
    // run the exe
    const run_artifact = b.addRunArtifact(example_exe_install_artifact.artifact);

    run_example_step.dependOn(&example_exe_install_artifact.step);
    run_example_step.dependOn(&run_artifact.step);
    return run_example_step;
}

pub fn areBindingsUpToDate(b: *Build, godot_path: []const u8) bool {
    const version_file = b.build_root.handle.openFile("src/bindings/version", .{}) catch
        return false;
    defer version_file.close();

    const godot_version_cached = version_file.reader().readUntilDelimiterAlloc(
        b.allocator,
        '\n',
        1024,
    ) catch return false;
    defer b.allocator.free(godot_version_cached);

    const zig_version_cached = version_file.reader().readUntilDelimiterAlloc(
        b.allocator,
        '\n',
        1024,
    ) catch return false;
    defer b.allocator.free(zig_version_cached);

    const result = std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = &.{ godot_path, "--version" },
    }) catch return false;
    defer {
        b.allocator.free(result.stderr);
        b.allocator.free(result.stdout);
    }
    var seq = std.mem.splitSequence(u8, result.stdout, "\n");
    return (std.mem.eql(u8, godot_version_cached, seq.first()) and
        std.mem.eql(u8, zig_version_cached, builtin.zig_version_string));
}

const DumpedApi = struct {
    step: *Step,
    api_file: Build.LazyPath,
    interface_file: Build.LazyPath,
};

pub fn dumpApiStep(b: *Build, target: Target, godot_path: ?Build.LazyPath) DumpedApi {
    const dump_api_step = b.step("dump-api", "Dump GDExtension api");

    var dumped_api: DumpedApi = undefined;
    dumped_api.step = dump_api_step;

    { // dump extension_api
        const extension_api_cmd = b.addSystemCommand(&.{});
        if (godot_path) |p| {
            extension_api_cmd.addFileArg(p);
        } else {
            extension_api_cmd.addArg("godot");
        }
        extension_api_cmd.addArgs(&.{ "--headless", "--dump-extension-api" });

        const extension_api_file = extension_api_cmd.addOutputFileArg("extension_api.json");

        extension_api_cmd.cwd = extension_api_file.dirname();
        dump_api_step.dependOn(&extension_api_cmd.step);
        dumped_api.api_file = extension_api_file;
    }

    { // dump and translate interface
        const interface_cmd = b.addSystemCommand(&.{});
        if (godot_path) |p| {
            interface_cmd.addFileArg(p);
        } else {
            interface_cmd.addArg("godot");
        }
        interface_cmd.addArgs(&.{ "--headless", "--dump-gdextension-interface" });

        const gdextension_interface_file = interface_cmd.addOutputFileArg("gdextension_interface.h");
        interface_cmd.cwd = gdextension_interface_file.dirname();

        const translate_interface_file = b.addTranslateC(.{
            .root_source_file = gdextension_interface_file,
            .optimize = .Debug,
            .target = target,
        });
        dump_api_step.dependOn(&translate_interface_file.step);
        dumped_api.interface_file = translate_interface_file.getOutput();
    }

    return dumped_api;
}

pub fn dumpApiMakeFn(step: *Step, prog_node: std.Progress.Node) anyerror!void {
    const b = step.owner;

    const file = try b.build_root.handle.createFile(api_dump_dir ++ "version", .{});
    defer file.close();
    const writer = file.writer();

    const godot_path_input_option = b.user_input_options.get(zgd_godot_name);
    const godot_path = if (godot_path_input_option) |opt| opt.value.scalar else zgd_godot_default;
    var out_code: u8 = 0;
    const std_out = try b.runAllowFail(&.{ godot_path, "--version" }, &out_code, .Ignore);
    defer b.allocator.free(std_out);
    var seq = std.mem.splitSequence(u8, std_out, "\n");
    try writer.print("{s}\n", .{seq.first()});

    step.evalZigProcess(&.{
        b.graph.zig_exe,
        "translate-c",
        "--listen=-",
    }, prog_node);
}
