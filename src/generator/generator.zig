const std = @import("std");
const Api = @import("Api.zig");
const common = @import("common.zig");
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;
const zig_version_string = @import("builtin").zig_version_string;

const build_configuration = "float_32";

const type_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "int", "i64" },
    .{ "int32", "i32" },
    .{ "float", "f32" },
});

pub fn generate(allocator: Allocator, output_directory: Dir, build_config: common.BuildConfig) !void {
    try Api.dump(allocator, output_directory);
    const parsed_api = try Api.parse(allocator, output_directory);
    defer parsed_api.deinit();
    const api = parsed_api.json.value;

    // create root module file
    const file = try output_directory.createFile("godot.zig", .{});
    defer file.close();
    const godot_writer = file.writer();
    try @import("generators/header.zig").generate(output_directory, api.header);
    try @import("generators/global_enums.zig").generate(output_directory, api.global_enums);
    try @import("generators/utility_functions.zig").generate(
        output_directory,
        api.utility_functions,
    );
    try @import("generators/builtin_classes.zig").generate(
        allocator,
        output_directory,
        godot_writer,
        api,
        build_config,
    );
    try @import("generators/global_constants.zig").generate(godot_writer, api.global_constants);
    try @import("generators/classes.zig").generate(allocator, godot_writer, output_directory, api.classes);

    try generateVersionFile(allocator, output_directory);
}

pub fn generateVersionFile(allocator: Allocator, output_directory: Dir) !void {
    const version_file = try output_directory.createFile("version", .{});
    defer version_file.close();
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "godot", "--version" },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }
    const writer = version_file.writer();
    var seq = std.mem.splitSequence(u8, result.stdout, "\n");
    try writer.print("{s}\n{s}\n", .{
        seq.first(),
        zig_version_string,
    });
}
