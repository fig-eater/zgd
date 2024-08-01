const std = @import("std");
const Dir = std.fs.Dir;
const aro = @import("aro");
const fmt = @import("../fmt.zig");
const NodeList = std.ArrayList(aro.Tree.NodeIndex);

pub fn generate(
    allocator: std.mem.Allocator,
    interface_path: []const u8,
    include_path: []const u8,
    output_dir: Dir,
) !void {
    _ = include_path; // autofix
    const file = try output_dir.createFile("interface.zig", .{});
    defer file.close();
    const writer = file.writer();

    try writer.writeAll(
        \\//! Functions and types for initializing bindings to GDExtension interface.
        \\//!
        \\//! Generated from gdextension_interface.h
        \\
        \\/// Initialize function bindings for GDExtension interface
        \\///
        \\/// `getProcAddress` - function pointer to GDExtensionInterfaceGetProcAddress function
        \\/// provided by extension entry point.
        \\pub fn initBindings(getProcAddress: InterfaceGetProcAddress) void {
        \\    inline for (@typeInfo(bindings).Struct.decls) |decl| {
        \\        @field(bindings, decl.name) = @ptrCast(getProcAddress(decl.name));
        \\    }
        \\}
        \\
    );

    var comp = try aro.Compilation.initDefault(allocator);
    defer comp.deinit();
    try comp.addSystemIncludeDir("/home/frog/dev/zgd/zig-out/inc");

    const builtin = try comp.generateBuiltinMacros(.include_system_defines);

    const source = try comp.addSourceFromPath(interface_path);

    var pp = try aro.Preprocessor.initDefault(&comp);
    defer pp.deinit();
    try pp.preprocessSources(&.{ source, builtin });

    var tree = try pp.parse();
    defer tree.deinit();

    try translate(tree, source.id, writer);
}

fn translate(tree: aro.Tree, public_source: aro.Source.Id, writer: anytype) !void {
    var mapper = tree.comp.string_interner.getFastTypeMapper(tree.comp.gpa) catch
        tree.comp.string_interner.getSlowTypeMapper();
    defer mapper.deinit(tree.comp.gpa);

    var interface_list = NodeList.init(tree.comp.gpa);
    defer interface_list.deinit();

    var anon_typedef_map = try gatherAnonymousTypedefMap(tree, mapper);
    defer anon_typedef_map.deinit();

    for (tree.root_decls) |i| {
        try translateRootNode(i, tree, mapper, anon_typedef_map, public_source, &interface_list, writer);
    }

    try writer.writeAll("pub const bindings = struct {\n");
    for (interface_list.items) |node| {
        const data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(node)];
        const ty: aro.Type = tree.nodes.items(.ty)[@intFromEnum(node)];
        const decl_name = noGdxPrefix(tree.tokSlice(data.decl.name))["Interface".len..];
        try writer.print("    var {s}: ", .{fmt.IdFormatter{ .data = decl_name }});
        try translateType(ty, tree, mapper, anon_typedef_map, writer);
        try writer.writeAll(" = undefined;\n");
    }
    try writer.writeAll("};\n");
}

fn translateRootNode(
    node: aro.Tree.NodeIndex,
    tree: aro.Tree,
    mapper: aro.TypeMapper,
    anon_typedef_map: std.StringHashMap([]const u8),
    public_source: aro.Source.Id,
    interface_list: *NodeList,
    writer: anytype,
) !void {
    const tag: aro.Tree.Tag = tree.nodes.items(.tag)[@intFromEnum(node)];
    const data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(node)];
    const ty: aro.Type = tree.nodes.items(.ty)[@intFromEnum(node)];

    switch (tag) {
        .typedef => {
            switch (ty.specifier) {
                .@"enum" => {
                    const name = mapper.lookup(ty.data.@"enum".name);
                    if (std.mem.startsWith(u8, name, "(")) {
                        // this should be handled by the anon_typedef_map
                        std.debug.assert(anon_typedef_map.get(name) != null);
                        return;
                    }
                },
                .@"struct" => {
                    const name = mapper.lookup(ty.data.record.name);
                    if (std.mem.startsWith(u8, name, "(")) {
                        // this should be handled by the anon_typedef_map
                        std.debug.assert(anon_typedef_map.get(name) != null);
                        return;
                    }
                },
                .char,
                .uchar,
                .schar,
                .short,
                .ushort,
                .int,
                .uint,
                .long,
                .ulong,
                .long_long,
                .ulong_long,
                .int128,
                .uint128,
                .bit_int,
                => {

                    // const decl_name = tree.tokSlice(data.decl.name);
                    // std.debug.print("{s}\n", .{decl_name});
                    // if (std.mem.endsWith(u8, decl_name, "_t")) {
                    //     try writer.writeAll("const size_t = usize;\n");
                    //     return;
                    // }
                },
                .fp16,
                .float16,
                .float,
                .double,
                .long_double,
                .float128,
                => {},
                .pointer => {
                    const subtype = ty.data.sub_type;
                    if (subtype.specifier == .func) {
                        const decl_name = noGdxPrefix(tree.tokSlice(data.decl.name));
                        if (std.mem.startsWith(u8, decl_name, "Interface")) {
                            const interface_fn_name = decl_name["Interface".len..];
                            if (!std.mem.eql(u8, interface_fn_name, "GetProcAddress")) {
                                try interface_list.append(node);
                                try writer.print(
                                    \\pub inline fn {c}() void {{
                                    \\    return bindings.{s}();
                                    \\}}
                                    \\
                                , .{
                                    fmt.IdFormatter{ .data = decl_name["Interface".len..] },
                                    fmt.IdFormatter{ .data = decl_name["Interface".len..] },
                                });
                                return;
                            }
                        }
                    }
                },
                else => {},
            }

            const loc: aro.Source.Location = tree.tokens.items(.loc)[data.decl.name];
            if (loc.id == public_source) {
                try writer.writeAll("pub ");
            }
            // TODO conditionally set formatting based on the right-hand side
            try writer.print("const {p} = ", .{fmt.IdFormatter{
                .data = noGdxPrefix(tree.tokSlice(data.decl.name)),
            }});

            try translateType(ty, tree, mapper, anon_typedef_map, writer);
            try writer.writeAll(";\n");

            if (data.decl.node != .none) {
                std.log.err("unhandled\n", .{});
            }
        },
        .enum_decl => try translateEnum(
            data,
            ty,
            tree,
            mapper,
            anon_typedef_map,
            public_source,
            writer,
        ),
        .struct_decl => {
            const mapped_name = mapper.lookup(ty.data.record.name);
            const struct_name = if (anon_typedef_map.get(mapped_name)) |n| n else mapped_name;

            if (ty.data.record.fields.len > 0 and
                tree.tokens.items(.loc)[ty.data.record.fields[0].name_tok].id == public_source)
            {
                try writer.writeAll("pub ");
            }
            try writer.print("const {p} = struct {{\n", .{fmt.IdFormatter{ .data = noGdxPrefix(struct_name) }});
            for (tree.data[data.range.start..data.range.end]) |stmt| {
                try translateChildNode(tree, mapper, anon_typedef_map, stmt, writer);
            }
            try writer.writeAll("};\n");
        },
        .struct_decl_two => {
            const mapped_name = mapper.lookup(ty.data.record.name);
            const struct_name = if (anon_typedef_map.get(mapped_name)) |n| n else mapped_name;

            if (ty.data.record.fields.len > 0 and
                tree.tokens.items(.loc)[ty.data.record.fields[0].name_tok].id == public_source)
            {
                try writer.writeAll("pub ");
            }
            try writer.print("const {p} = struct {{\n", .{fmt.IdFormatter{ .data = noGdxPrefix(struct_name) }});
            // for (tree.data[data.bin.start..data.range.end]) |stmt| {
            //     try translateChildNode(tree, mapper, anon_typedef_map, stmt, writer);
            // }
            try writer.writeAll("};\n");
        },
        .@"var" => {
            try writer.print("// const {s} = {any} {any}\n", .{
                tree.tokSlice(data.decl.name),
                tree.value_map.get(node),
                tree.value_map.get(data.decl.node),
                // tree.value_map.get(ty.data.int),
            });

            // if (tree.value_map.get(data.decl.node)) |val| {
            //     try writer.print("// var {}\n", .{fmt.AroValFormatter{ .data = .{
            //         val,
            //         ty,
            //         tree.comp,
            //     } }});
            // } else {
            //     try writer.print("// var {s} UNKNOWN\n", .{@tagName(ty.specifier)});
            // }
        },
        else => {
            std.debug.panic("unhandled: {s}", .{@tagName(tag)});
        },
    }
}

fn translateEnum(
    data: aro.Tree.Node.Data,
    ty: aro.Type,
    tree: aro.Tree,
    mapper: aro.TypeMapper,
    anon_typedef_map: std.StringHashMap([]const u8),
    public_source: aro.Source.Id,
    writer: anytype,
) !void {
    const enum_type_name = mapper.lookup(ty.data.@"enum".name);
    const enum_name = if (anon_typedef_map.get(enum_type_name)) |n| n else enum_type_name;

    if (ty.data.@"enum".fields.len > 0 and
        tree.tokens.items(.loc)[ty.data.@"enum".fields[0].name_tok].id == public_source)
    {
        try writer.writeAll("pub ");
    }

    try writer.print("const {p} = enum(c_int) {{\n", .{fmt.IdFormatter{ .data = noGdxPrefix(enum_name) }});

    // remove prefix
    var prefix: []const u8 = &.{};
    if (tree.data.len >= 2) {
        const first = tree.data[data.range.start];
        const second = tree.data[data.range.start + 1];

        const first_tag: aro.Tree.Tag = tree.nodes.items(.tag)[@intFromEnum(first)];
        const first_data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(first)];
        const second_tag: aro.Tree.Tag = tree.nodes.items(.tag)[@intFromEnum(second)];
        const second_data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(second)];

        std.debug.assert(first_tag == .enum_field_decl);
        std.debug.assert(second_tag == .enum_field_decl);

        const first_name = tree.tokSlice(first_data.decl.name);
        const second_name = tree.tokSlice(second_data.decl.name);
        const min_len = std.mem.min(usize, &.{ first_name.len, second_name.len });

        for (first_name[0..min_len], second_name[0..min_len], 0..) |a, b, i| {
            if (a != b) {
                prefix = first_name[0..i];
                break;
            }
        }
    }

    for (tree.data[data.range.start..data.range.end]) |stmt| {
        try translateEnumField(tree, stmt, prefix, writer);
    }
    try writer.writeAll("};\n");
}

fn translateEnumField(
    tree: aro.Tree,
    node: aro.Tree.NodeIndex,
    prefix: []const u8,
    writer: anytype,
) !void {
    const tag: aro.Tree.Tag = tree.nodes.items(.tag)[@intFromEnum(node)];
    const data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(node)];
    const ty: aro.Type = tree.nodes.items(.ty)[@intFromEnum(node)];

    std.debug.assert(tag == .enum_field_decl);

    try writer.print("    {s}", .{fmt.IdFormatter{
        .data = fmt.withoutPrefix(tree.tokSlice(data.decl.name), prefix),
    }});
    if (tree.value_map.get(node)) |val| {
        try writer.print(" = {}", .{fmt.AroValFormatter{ .data = .{
            val,
            ty,
            tree.comp,
        } }});
    }
    try writer.writeAll(",\n");
}

fn translateChildNode(
    tree: aro.Tree,
    mapper: aro.TypeMapper,
    anon_typedef_map: std.StringHashMap([]const u8),
    node: aro.Tree.NodeIndex,
    writer: anytype,
) !void {
    const tag: aro.Tree.Tag = tree.nodes.items(.tag)[@intFromEnum(node)];
    const data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(node)];
    const ty: aro.Type = tree.nodes.items(.ty)[@intFromEnum(node)];

    switch (tag) {
        .enum_field_decl => {
            try writer.print("    {s},\n", .{fmt.IdFormatter{
                .data = tree.tokSlice(data.decl.name),
            }});
        },
        .record_field_decl => {
            try writer.print("    {s}: ", .{fmt.IdFormatter{
                .data = tree.tokSlice(data.decl.name),
            }});
            try translateType(ty, tree, mapper, anon_typedef_map, writer);
            try writer.writeAll(",\n");
        },
        else => unreachable,
    }
}

fn translateType(
    ty: aro.Type,
    tree: aro.Tree,
    mapper: aro.TypeMapper,
    anon_typedef_map: std.StringHashMap([]const u8),
    writer: anytype,
) !void {
    if (ty.typedef) |tok| {
        const token = tree.tokSlice(tok);
        if (std.mem.eql(u8, token, "GDExtensionBool")) {
            try writer.writeAll("bool");
            return;
        }
        if (!std.mem.endsWith(u8, token, "_t") and !std.mem.eql(u8, token, "GDExtensionInt")) {
            try writer.writeAll(noGdxPrefix(token));
            return;
        }
    }
    switch (ty.specifier) {
        .void, .bool => |specifier| try writer.writeAll(@tagName(specifier)),

        // int
        .char, .uchar, .schar => {
            try writer.writeAll("c_char");
        },
        inline .short,
        .ushort,
        .int,
        .uint,
        .long,
        .ulong,
        => |specifier_tag| {
            try writer.writeAll("c_" ++ @tagName(specifier_tag));
        },
        .long_long => try writer.writeAll("c_longlong"),
        .ulong_long => try writer.writeAll("c_ulonglong"),
        .int128, .uint128, .bit_int => {
            const signed_char: u8 = if (ty.signedness(tree.comp) == .signed) 'i' else 'u';
            try writer.print("{c}{d}", .{ signed_char, ty.bitSizeof(tree.comp).? });
        },

        // float
        .fp16,
        .float16,
        .float,
        .double,
        .long_double,
        .float128,
        => try writer.print("f{d}", .{ty.bitSizeof(tree.comp).?}),

        .pointer => {
            const sub_type = ty.data.sub_type;
            switch (sub_type.specifier) {
                .void => {
                    try writer.writeAll("?*anyopaque");
                },
                .func, .var_args_func, .old_style_func => {
                    try writer.writeAll("*const ");
                    try translateType(sub_type.*, tree, mapper, anon_typedef_map, writer);
                },
                else => {
                    try writer.writeAll("[*c]");
                    try translateType(sub_type.*, tree, mapper, anon_typedef_map, writer);
                },
            }
        },

        .func => {
            const func = ty.data.func;
            try writer.writeAll("fn (");
            for (func.params, 0..) |param, i| {
                const param_name = mapper.lookup(param.name);
                if (param_name.len != 0) {
                    try writer.print("{s}: ", .{param_name});
                }

                try translateType(param.ty, tree, mapper, anon_typedef_map, writer);
                if (i != func.params.len - 1) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeAll(") callconv(.C) ");
            try translateType(func.return_type, tree, mapper, anon_typedef_map, writer);
        },
        .var_args_func, .old_style_func => {
            const func = ty.data.func;
            try writer.writeAll("fn (");
            for (func.params) |param| {
                const param_name = mapper.lookup(param.name);
                if (param_name.len != 0) {
                    try writer.print("{s}: ", .{param_name});
                }

                try translateType(param.ty, tree, mapper, anon_typedef_map, writer);
                try writer.writeAll(", ");
            }
            try writer.writeAll("...) callconv(.C) ");
            try translateType(func.return_type, tree, mapper, anon_typedef_map, writer);
        },

        // data.array
        .array, .static_array, .incomplete_array, .vector => {
            try writer.writeAll("####array####");
        },

        // data.record
        .@"struct" => {
            const mapped_name = mapper.lookup(ty.data.record.name);
            const name = if (anon_typedef_map.get(mapped_name)) |n| n else mapped_name;
            try writer.writeAll(noGdxPrefix(name));
        },
        .@"union" => {
            try writer.writeAll("####union####");
        },

        // data.enum
        .@"enum" => {
            const mapped_name = mapper.lookup(ty.data.@"enum".name);
            const name = if (anon_typedef_map.get(mapped_name)) |n| n else mapped_name;
            try writer.writeAll(noGdxPrefix(name));
        },
        else => {
            @panic("unhandled");
        },
    }
}

fn gatherAnonymousTypedefMap(
    tree: aro.Tree,
    mapper: aro.TypeMapper,
) !std.StringHashMap([]const u8) {
    const allocator = tree.comp.gpa;
    var map = std.StringHashMap([]const u8).init(allocator);

    for (tree.root_decls) |node| {
        const tag: aro.Tree.Tag = tree.nodes.items(.tag)[@intFromEnum(node)];
        const data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(node)];
        const ty: aro.Type = tree.nodes.items(.ty)[@intFromEnum(node)];

        switch (tag) {
            .typedef => {
                switch (ty.specifier) {
                    .@"enum" => {
                        const anon_name = mapper.lookup(ty.data.@"enum".name);
                        if (std.mem.startsWith(u8, anon_name, "(anonymous enum")) {
                            try map.put(anon_name, tree.tokSlice(data.decl.name));
                        }
                    },
                    .@"struct" => {
                        const anon_name = mapper.lookup(ty.data.record.name);
                        if (std.mem.startsWith(u8, anon_name, "(anonymous struct")) {
                            try map.put(anon_name, tree.tokSlice(data.decl.name));
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }
    }

    return map;
}

fn noGdxPrefix(bytes: []const u8) []const u8 {
    const gdextension_prefix = "GDExtension";
    if (bytes.len > gdextension_prefix.len and std.mem.startsWith(u8, bytes, gdextension_prefix)) {
        return bytes[(gdextension_prefix.len + @intFromBool(bytes[gdextension_prefix.len] == 's'))..];
    }
    return bytes;
}
