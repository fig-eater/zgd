const std = @import("std");
const Api = @import("../Api.zig");
const fmt = @import("../fmt.zig");
const Dir = std.fs.Dir;

const PrefixMap = std.StaticStringMap([]const u8);

pub fn generateGlobalEnums(
    output_directory: Dir,
    global_enums: []const Api.Enum,
    prefix_map: PrefixMap,
) !void {
    const file = try output_directory.createFile("global_enums.zig", .{});
    defer file.close();
    const writer = file.writer();

    for (global_enums) |global_enum| {
        if (global_enum.is_bitfield) {
            try writeBitfield(writer, global_enum, prefix_map);
        } else {
            try writeEnum(writer, global_enum, prefix_map);
        }
    }
}

pub fn writeBitfield(writer: anytype, global_enum: Api.Enum, prefix_map: PrefixMap) !void {
    var id_fmt: fmt.IdFormatter = undefined;
    id_fmt.data = global_enum.name;
    try writer.print("pub const {p} = enum(i64) {{\n", .{id_fmt});
    const @"prefix?" = prefix_map.get(global_enum.name);
    for (global_enum.values) |value| {
        id_fmt.data = if (@"prefix?") |p| fmt.withoutPrefix(value.name, p) else value.name;
        try writer.print("    {s} = {d},\n", .{ id_fmt, value.value });
    }
    try writer.writeAll("};\n");
}

pub fn writeEnum(writer: anytype, global_enum: Api.Enum, prefix_map: PrefixMap) !void {
    var id_fmt: fmt.IdFormatter = undefined;
    id_fmt.data = global_enum.name;
    try writer.print("pub const {p} = enum(i64) {{\n", .{id_fmt});

    const @"prefix?" = prefix_map.get(global_enum.name);
    for (global_enum.values) |value| {
        id_fmt.data = if (@"prefix?") |p| fmt.withoutPrefix(value.name, p) else value.name;
        try writer.print("    {s} = {d},\n", .{ id_fmt, value.value });
    }

    try writer.writeAll("};\n");
}
