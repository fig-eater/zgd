const std = @import("std");
const Api = @import("Api.zig");
const util = @import("util.zig");
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
    build_config: util.BuildConfig,
    output_directory: Dir,
) !void {
    // create root module file
    const godot_file = try output_directory.createFile("godot.zig", .{});
    defer godot_file.close();
    const godot_writer = godot_file.writer();

    try godot_writer.writeAll("pub const interface = @import(\"gdextension_interface\");\n");

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

    // try @import("generators/interface.zig").generate(output_directory);

    // try generateVersionFile(allocator, output_directory);
}

// pub fn generateVersionFile(allocator: Allocator, output_directory: Dir) !void {
//     const version_file = try output_directory.createFile("version", .{});
//     defer version_file.close();
//     const result = try std.process.Child.run(.{
//         .allocator = allocator,
//         .argv = &.{ "godot", "--version" },
//     });
//     defer {
//         allocator.free(result.stdout);
//         allocator.free(result.stderr);
//     }
//     const writer = version_file.writer();
//     var seq = std.mem.splitSequence(u8, result.stdout, "\n");
//     try writer.print("{s}\n{s}\n", .{
//         seq.first(),
//         zig_version_string,
//     });
// }
