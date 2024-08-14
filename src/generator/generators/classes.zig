const std = @import("std");
const Api = @import("../Api.zig");
const util = @import("../util.zig");
const builtin_classes = @import("builtin_classes.zig");
const func_gen = @import("function_generator.zig");
const fs = @import("../fs.zig");
const fmt = @import("../../fmt.zig");
const Dir = fs.Dir;
const Allocator = std.mem.Allocator;

pub fn generate(
    allocator: Allocator,
    output_directory: Dir,
    api: Api,
) !void {
    const file = try output_directory.createFile("classes.zig", .{});
    defer file.close();
    const classes_writer = file.writer();

    try fs.makeDirIfMissing(output_directory, "classes");
    var classes_dir = try output_directory.openDir("classes", .{});
    defer classes_dir.close();

    try fs.makeDirIfMissing(classes_dir, "builtin");
    var builtin_classes_dir = try classes_dir.openDir("builtin", .{});
    defer builtin_classes_dir.close();

    try fs.makeDirIfMissing(classes_dir, "internal");
    var internal_dir = try classes_dir.openDir("internal", .{});
    defer internal_dir.close();

    for (api.classes) |class| {
        try generateClass(allocator, classes_writer, classes_dir, internal_dir, class);
    }
}

pub fn generateClass(
    allocator: Allocator,
    classes_writer: anytype,
    class_dir: Dir,
    internal_dir: Dir,
    class: Api.Class,
) !void {
    var id_fmt: fmt.IdFormatter = undefined;
    id_fmt.data = class.name;
    const class_name_id = try fmt.allocPrint(allocator, "{p}", .{id_fmt});
    defer allocator.free(class_name_id);

    const file_name = try fmt.allocPrint(allocator, "{s}.zig", .{class_name_id});
    defer allocator.free(file_name);

    try classes_writer.print("pub const {s} = @import(\"classes/{s}\");\n", .{ class_name_id, file_name });

    const file = try class_dir.createFile(file_name, .{});
    defer file.close();
    const writer = file.writer();

    // setup internal class file writer
    const internal_file_name = try fmt.allocPrint(
        allocator,
        "{s}_" ++ util.internal_name ++ ".zig",
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
