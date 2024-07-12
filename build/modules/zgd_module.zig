const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Options = struct {
    zgd_module_root: []const u8,
    generate_bindings_step: *Step,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};
pub fn addToBuild(b: *Build, options: Options) *Build.Module {
    // define root file of zgd generated by bindings step
    // this being a generated file will make it so when the `godot` module is requested
    // it will run the bindings_step to generate the root file
    const generated_file = b.allocator.create(Build.GeneratedFile) catch @panic("OOM");
    generated_file.* = .{
        .step = options.generate_bindings_step,
        .path = options.zgd_module_root,
    };

    const overloading_dependency = b.dependency("overloading", .{
        .target = options.target,
        .optimize = options.optimize,
    });

    const module = b.addModule("godot", .{
        .root_source_file = .{ .generated = .{ .file = generated_file } },
        .imports = &.{
            .{ .name = "overloading", .module = overloading_dependency.module("overloading") },
        },
    });

    return module;
}
