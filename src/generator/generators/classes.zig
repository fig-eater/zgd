const std = @import("std");
const Api = @import("../Api.zig");
const common = @import("../common.zig");
const Dir = std.fs.Dir;
const Allocator = std.mem.Allocator;

pub fn generate(allocator: Allocator, godot_writer: anytype, output_directory: Dir, classes: []const Api.Class) !void {
    try common.makeDirIfMissing(output_directory, "classes");
    var classes_dir = try output_directory.openDir("classes", .{});
    defer classes_dir.close();

    for (classes) |class| {
        try generateClass(allocator, godot_writer, classes_dir, class);
    }
}

pub fn generateClass(allocator: Allocator, godot_writer: anytype, output_directory: Dir, class: Api.Class) !void {
    var id_fmt: common.IdFormatter = undefined;
    id_fmt.data = class.name;
    const class_name_id = try std.fmt.allocPrint(allocator, "{p}", .{id_fmt});
    defer allocator.free(class_name_id);

    const file_name = try std.fmt.allocPrint(allocator, "{s}.zig", .{class_name_id});
    defer allocator.free(file_name);

    try godot_writer.print("pub const {s} = @import(\"classes/{s}\");\n", .{ class_name_id, file_name });

    const file = try output_directory.createFile(file_name, .{});
    defer file.close();
    const writer = file.writer();

    try writer.print("{s}\n", .{id_fmt});
}
