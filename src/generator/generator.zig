const std = @import("std");
const Api = @import("Api.zig");
const BuildConfig = @import("util.zig").BuildConfig;
const Allocator = std.mem.Allocator;
const fs = @import("fs.zig");
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
    output_directory: fs.Dir,
) !void {
    // create root module file
    const godot_file = try output_directory.createFile("gen_root.zig", .{});
    defer godot_file.close();
    const root_writer = godot_file.writer();

    try fs.makeDirIfMissing(output_directory, "gen");
    var gen_dir = try output_directory.openDir("gen", .{});
    defer gen_dir.close();

    try @import("generators/header.zig").generate(gen_dir, api.header);

    try root_writer.writeAll(
        \\pub const global_enums = @import("gen/global_enums.zig");
        \\pub usingnamespace global_enums;
        \\
    );
    try @import("generators/global_enums.zig").generate(gen_dir, api.global_enums);

    try root_writer.writeAll(
        \\pub const util = @import("gen/utility_functions.zig");
        \\pub usingnamespace util;
        \\
    );
    try @import("generators/utility_functions.zig").generate(
        gen_dir,
        api.utility_functions,
    );

    try @import("generators/global_constants.zig").generate(root_writer, api.global_constants);

    try root_writer.writeAll(
        \\pub const builtin_classes = @import("gen/builtin_classes.zig");
        \\pub usingnamespace builtin_classes;
        \\
    );
    try @import("generators/builtin_classes.zig").generate(
        allocator,
        gen_dir,
        api,
        build_config,
    );

    try root_writer.writeAll(
        \\pub const classes = @import("gen/classes.zig");
        \\pub usingnamespace classes;
        \\
    );
    try @import("generators/classes.zig").generate(
        allocator,
        gen_dir,
        api,
    );

    try @import("generators/native_structures.zig").generate(root_writer, api.native_structures);

    try root_writer.writeAll(
        \\pub const interface = @import("gen/interface.zig");
        \\pub usingnamespace interface;
        \\
    );
    try @import("generators/interface.zig").generate(
        allocator,
        interface_path,
        include_dir_path,
        gen_dir,
    );
}
