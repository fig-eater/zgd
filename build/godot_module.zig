const Build = @import("std").Build;
const Options = struct {
    gen_module: *Build.Module,
    root: []const u8,
};
pub fn addToBuild(b: *Build, options: Options) *Build.Module {
    const module = b.addModule("godot", .{
        .root_source_file = b.path(options.root),
        .imports = &.{
            .{ .name = "gen", .module = options.gen_module },
        },
    });
    return module;
}
