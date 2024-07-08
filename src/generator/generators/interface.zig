const std = @import("std");
const util = @import("../util.zig");

const Dir = std.fs.Dir;

pub fn generate(output_dir: Dir) !void {
    const file = try output_dir.createFile("interface.zig", .{});
    defer file.close();
    const writer = file.writer();
    try writeVariantEnum(writer);
    try writeVariantOpEnum(writer);
    try writeCallErrorTypeEnum(writer);
    try writeCallErrorStruct(writer);

    try writeInstanceBindingCallbacks(writer);
}

fn writeVariantEnum(writer: anytype) !void {
    const T = c_int;
    const variant_enum_decls = getFieldsWithPrefix(T, "GDEXTENSION_VARIANT_TYPE_");
    try writer.writeAll("pub const VariantType = enum(" ++ @typeName(T) ++ ") {\n");
    for (variant_enum_decls) |kvp| {
        try writer.print("    {s} = {d},\n", .{ kvp[0], kvp[1] });
    }
    try writer.writeAll("};\n");
}

fn writeVariantOpEnum(writer: anytype) !void {
    const T = c_int;
    const variant_enum_decls = getFieldsWithPrefix(T, "GDEXTENSION_VARIANT_OP_");
    try writer.writeAll("pub const VariantOperator = enum(" ++ @typeName(T) ++ ") {\n");
    for (variant_enum_decls) |kvp| {
        try writer.print("    {s} = {d},\n", .{ kvp[0], kvp[1] });
    }
    try writer.writeAll("};\n");
}

// pub const GDExtensionVariantPtr = ?*anyopaque;
// pub const GDExtensionConstVariantPtr = ?*const anyopaque;
// pub const GDExtensionUninitializedVariantPtr = ?*anyopaque;
// pub const GDExtensionStringNamePtr = ?*anyopaque;
// pub const GDExtensionConstStringNamePtr = ?*const anyopaque;
// pub const GDExtensionUninitializedStringNamePtr = ?*anyopaque;
// pub const GDExtensionStringPtr = ?*anyopaque;
// pub const GDExtensionConstStringPtr = ?*const anyopaque;
// pub const GDExtensionUninitializedStringPtr = ?*anyopaque;
// pub const GDExtensionObjectPtr = ?*anyopaque;
// pub const GDExtensionConstObjectPtr = ?*const anyopaque;
// pub const GDExtensionUninitializedObjectPtr = ?*anyopaque;
// pub const GDExtensionTypePtr = ?*anyopaque;
// pub const GDExtensionConstTypePtr = ?*const anyopaque;
// pub const GDExtensionUninitializedTypePtr = ?*anyopaque;
// pub const GDExtensionMethodBindPtr = ?*const anyopaque;
// pub const GDExtensionInt = i64;
// pub const GDExtensionBool = u8;
// pub const GDObjectInstanceID = u64;
// pub const GDExtensionRefPtr = ?*anyopaque;
// pub const GDExtensionConstRefPtr = ?*const anyopaque;

fn writeCallErrorTypeEnum(writer: anytype) !void {
    const T = c_int;
    const variant_enum_decls = getFieldsWithPrefix(T, "GDEXTENSION_CALL_");
    try writer.writeAll("pub const CallErrorType = enum(" ++ @typeName(T) ++ ") {\n");
    for (variant_enum_decls) |kvp| {
        try writer.print("    {s} = {d},\n", .{ kvp[0], kvp[1] });
    }
    try writer.writeAll("};\n");
}

fn writeCallErrorStruct(writer: anytype) !void {
    try writer.writeAll(
        \\pub const CallError = extern struct {
        \\    @"error": CallErrorType,
        \\    argument: i32,
        \\    expected: i32,
        \\};
        \\
    );
}

fn writeInstanceBindingCallbacks(writer: anytype) !void {
    try writer.writeAll(
        \\pub const InstanceBindingCallbacks = extern struct {
        \\    create_callback: InstanceBindingCreateCallback,
        \\    free_callback: InstanceBindingFreeCallback,
        \\    reference_callback: InstanceBindingReferenceCallback,
        \\};
        \\
    );
}

fn writeFnPtrDefinition(comptime writer: anytype, comptime func_ptr: type) !void {
    const ptr: std.builtin.Type.Pointer = @typeInfo(@typeInfo(func_ptr).Optional.child).Pointer;
    const func: std.builtin.Type.Fn = @typeInfo(ptr.child);
    _ = writer;
    _ = func;
}

// fn writeEnum(writer: anytype, Enum: type) !void {
//     const T = c_int;
//     try writer.writeAll("pub const CallErrorType = enum(" ++ @typeName(T) ++ ") {\n");
//     for (variant_enum_decls) |kvp| {
//         try writer.print("    {s} = {d},\n", .{ kvp[0], kvp[1] });
//     }
//     try writer.writeAll("};\n");
// }

fn getAllGdextensionDeclares() InterfaceDeclares {
    const decls = comptime blk: {
        const decls = InterfaceDeclares{
            .enums = &.{},
            .fnptrs = &.{},
            .structs = &.{},
            .typedef = &.{},
        };
        const gdi = @typeInfo(@import("gdextension_interface")).Struct;
        const prefix = "gdextension";
        for (gdi.decls) |decl| {
            if (decl.name.len > prefix.len) {
                const lowercase_name = std.ascii.lowerString([prefix.len]u8{}, decl.name[0..prefix.len]);
                if (std.mem.eql(u8, prefix, lowercase_name)) {
                    const name = if (decl.name[prefix.len] == '_')
                        decl.name[prefix.len + 1 ..]
                    else
                        decl.name[prefix.len..];

                    _ = name;

                    switch (@TypeOf(@field(gdi, decl.name))) {
                        type => {
                            const T: type = @field(gdi, decl.name);
                            _ = T;
                        },
                        else => {},
                    }
                    // const part = .{ name, @TypeOf(@field(gdi, decl.name)) };
                    // gd_declares = gd_declares ++ part;
                }
            }
        }
        break :blk decls;
    };
    return decls;
}

const InterfaceDeclares = struct {
    constants: []struct { []const u8 },
    fnptrs: []struct { []const u8, type },
    structs: []struct { []const u8, type },
    typedef: []struct { []const u8, type },
};
