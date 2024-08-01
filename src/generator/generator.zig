const std = @import("std");
const Api = @import("Api.zig");
const BuildConfig = @import("util.zig").BuildConfig;
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;
const zig_version_string = @import("builtin").zig_version_string;

const build_configuration = "float_32";

const type_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "int", "i64" },
    .{ "int32", "i32" },
    .{ "float", "f32" },
});

pub fn generate(
    allocator: Allocator,
    api: Api,
    interface_path: []const u8,
    include_dir_path: []const u8,
    build_config: BuildConfig,
    output_directory: Dir,
) !void {
    // create root module file
    const godot_file = try output_directory.createFile("godot.zig", .{});
    defer godot_file.close();
    const godot_writer = godot_file.writer();

    try godot_writer.writeAll("pub const interface = @import(\"interface.zig\");\n");

    try @import("generators/header.zig").generate(output_directory, api.header);
    try @import("generators/global_enums.zig").generate(output_directory, api.global_enums);
    try @import("generators/utility_functions.zig").generate(
        output_directory,
        api.utility_functions,
    );
    try @import("generators/global_constants.zig").generate(godot_writer, api.global_constants);
    try @import("generators/classes.zig").generate(
        allocator,
        godot_writer,
        output_directory,
        api,
        build_config,
    );
    try @import("generators/native_structures.zig").generate(godot_writer, api.native_structures);
    try @import("generators/interface.zig").generate(
        allocator,
        interface_path,
        include_dir_path,
        output_directory,
    );
}
