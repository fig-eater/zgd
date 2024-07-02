const std = @import("std");
const Api = @import("../Api.zig");
const common = @import("../common.zig");
const builtin_classes = @import("builtin_classes.zig");
const func_gen = @import("function_generator.zig");
const Dir = std.fs.Dir;
const Allocator = std.mem.Allocator;

pub fn generate(
    allocator: Allocator,
    godot_writer: anytype,
    output_directory: Dir,
    api: Api,
    build_config: common.BuildConfig,
) !void {
    try common.makeDirIfMissing(output_directory, "classes");
    var classes_dir = try output_directory.openDir("classes", .{});
    defer classes_dir.close();

    try common.makeDirIfMissing(classes_dir, "internal");
    var internal_dir = try classes_dir.openDir("internal", .{});
    defer internal_dir.close();

    try builtin_classes.generate(
        allocator,
        classes_dir,
        internal_dir,
        godot_writer,
        api,
        build_config,
    );

    for (api.classes) |class| {
        try generateClass(allocator, godot_writer, classes_dir, internal_dir, class);
    }
}

pub fn generateClass(
    allocator: Allocator,
    godot_writer: anytype,
    class_dir: Dir,
    internal_dir: Dir,
    class: Api.Class,
) !void {
    var id_fmt: common.IdFormatter = undefined;
    id_fmt.data = class.name;
    const class_name_id = try std.fmt.allocPrint(allocator, "{p}", .{id_fmt});
    defer allocator.free(class_name_id);

    const file_name = try std.fmt.allocPrint(allocator, "{s}.zig", .{class_name_id});
    defer allocator.free(file_name);

    try godot_writer.print("pub const {s} = @import(\"classes/{s}\");\n", .{ class_name_id, file_name });

    const file = try class_dir.createFile(file_name, .{});
    defer file.close();
    const writer = file.writer();

    // setup internal class file writer
    const internal_file_name = try std.fmt.allocPrint(
        allocator,
        "{s}_" ++ common.internal_name ++ ".zig",
        .{class.name},
    );
    defer allocator.free(internal_file_name);
    const internal_file = try internal_dir.createFile(internal_file_name, .{});
    defer internal_file.close();

    if (class.methods) |methods| {
        const internal_file_writer = internal_file.writer();

        try internal_file_writer.writeAll("pub const bindings: struct {\n");
        for (methods) |method| {
            try func_gen.writeMethod(writer, method);
        }
        try internal_file_writer.writeAll("} = undefined;\n");
    }

    // internal_file_writer

    // try writer.print("{s}\n", .{id_fmt});
}
