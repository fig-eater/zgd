const std = @import("std");
const util = @import("../util.zig");
const aro = @import("aro");

const Dir = std.fs.Dir;

pub fn generate(
    allocator: std.mem.Allocator,
    interface_path: []const u8,
    include_dir_path: []const u8,
    output_dir: Dir,
) !void {
    const file = try output_dir.createFile("interface.zig", .{});
    defer file.close();
    // const writer = file.writer();

    var comp = aro.Compilation.init(allocator);
    defer comp.deinit();

    { // set langopts
        try comp.addDefaultPragmaHandlers();
        comp.langopts.setEmulatedCompiler(aro.target_util.systemCompiler(comp.target));
        comp.langopts.preserve_comments = true;
        // comp.enu
    }
    try comp.addSystemIncludeDir(include_dir_path);
    const source = try comp.addSourceFromPath(interface_path);

    const builtin_macros = try comp.generateBuiltinMacros(.include_system_defines);
    var preprocessor = try aro.Preprocessor.initDefault(&comp);
    defer preprocessor.deinit();
    // preprocessor.verbose = true;

    try preprocessor.preprocessSources(&.{ source, builtin_macros });
    var tree = try preprocessor.parse();
    defer tree.deinit();
    // try tree.dump(.no_color, writer);

    // var preprocessor = try aro.Preprocessor.initDefault(&comp);
    // defer preprocessor.deinit();
    // const toks = try preprocessor.preprocess(source);
    // defer aro.Tree.TokenWithExpansionLocs.free(toks.expansion_locs, allocator);

    {

        // const tree = try preprocessor.parse();
        // try tree.dump(.no_color, file.writer());

        // const parsed_tree = try preprocessor.parse();
        // _ = parsed_tree;

        // const writer = file.writer();
        // try writeVariantEnum(writer);
        // try writeVariantOpEnum(writer);
        // try writeCallErrorTypeEnum(writer);
        // try writeCallErrorStruct(writer);

        // try writeInstanceBindingCallbacks(writer);

        // try writeUtilityFns(writer);
    }
}

// fn writeVariantEnum(writer: anytype) !void {
//     const T = c_int;
//     const variant_enum_decls = getFieldsWithPrefix(T, "GDEXTENSION_VARIANT_TYPE_");
//     try writer.writeAll("pub const VariantType = enum(" ++ @typeName(T) ++ ") {\n");
//     for (variant_enum_decls) |kvp| {
//         try writer.print("    {s} = {d},\n", .{ kvp[0], kvp[1] });
//     }
//     try writer.writeAll("};\n");
// }

// fn writeVariantOpEnum(writer: anytype) !void {
//     const T = c_int;
//     const variant_enum_decls = getFieldsWithPrefix(T, "GDEXTENSION_VARIANT_OP_");
//     try writer.writeAll("pub const VariantOperator = enum(" ++ @typeName(T) ++ ") {\n");
//     for (variant_enum_decls) |kvp| {
//         try writer.print("    {s} = {d},\n", .{ kvp[0], kvp[1] });
//     }
//     try writer.writeAll("};\n");
// }

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

// fn writeCallErrorTypeEnum(writer: anytype) !void {
//     const T = c_int;
//     const variant_enum_decls = getFieldsWithPrefix(T, "GDEXTENSION_CALL_");
//     try writer.writeAll("pub const CallErrorType = enum(" ++ @typeName(T) ++ ") {\n");
//     for (variant_enum_decls) |kvp| {
//         try writer.print("    {s} = {d},\n", .{ kvp[0], kvp[1] });
//     }
//     try writer.writeAll("};\n");
// }

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

fn writeUtilityFns() !void {}

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
