const std = @import("std");
const util = @import("../util.zig");
const gdi = @import("gdextension_interface");
const Dir = std.fs.Dir;

pub fn generate(output_dir: Dir) !void {
    const file = try output_dir.createFile("interface.zig", .{});
    defer file.close();
    const writer = file.writer();
    try writeVariantEnum(writer);
    try writeVariantOp(writer);
}

pub fn writeVariantEnum(writer: anytype) !void {
    const variant_enum_decls = getFieldsWithPrefix(c_int, "GDEXTENSION_VARIANT_TYPE_");
    try writer.writeAll("pub const VariantType = enum(c_int) {\n");
    for (variant_enum_decls) |kvp| {
        try writer.print("    {s} = {d},\n", .{ kvp[0], kvp[1] });
    }
    try writer.writeAll("};\n");
}

pub fn writeVariantOp(writer: anytype) !void {
    const variant_enum_decls = getFieldsWithPrefix(c_int, "GDEXTENSION_VARIANT_OP_");
    try writer.writeAll("pub const VariantOperator = enum(c_int) {\n");
    for (variant_enum_decls) |kvp| {
        try writer.print("    {s} = {d},\n", .{ kvp[0], kvp[1] });
    }
    try writer.writeAll("};\n");
}

fn getFieldsWithPrefix(
    comptime ValueType: type,
    comptime prefix: []const u8,
) []const struct { []const u8, ValueType } {
    const field_kvps = comptime blk: {
        const TupleType = struct { []const u8, ValueType };
        @setEvalBranchQuota(10000); // needed for checking prefixes
        const info: std.builtin.Type.Struct = @typeInfo(gdi).Struct;
        var field_kvps: []const TupleType = &.{};
        field_kvps = field_kvps;
        for (info.decls) |decl| {
            if (std.mem.startsWith(u8, decl.name, prefix)) {
                const part: []const TupleType = &.{
                    .{ decl.name[prefix.len..], @field(gdi, decl.name) },
                };
                field_kvps = field_kvps ++ part;
            }
        }
        break :blk field_kvps;
    };
    return field_kvps;
}
