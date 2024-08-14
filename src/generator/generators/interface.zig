const std = @import("std");
const Dir = std.fs.Dir;
const aro = @import("aro");
const fmt = @import("../../fmt.zig");
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
        try writer.print("    pub var {s}: ", .{fmt.IdFormatter{ .data = decl_name }});
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
                .pointer => {
                    const subtype = ty.data.sub_type;
                    if (subtype.specifier == .func) {
                        const decl_name = noGdxPrefix(tree.tokSlice(data.decl.name));
                        if (std.mem.startsWith(u8, decl_name, "Interface")) {
                            const interface_fn_name = decl_name["Interface".len..];
                            if (!std.mem.eql(u8, interface_fn_name, "GetProcAddress")) {
                                try interface_list.append(node);
                                const name_fmt = fmt.fmtId(decl_name["Interface".len..]);
                                try writer.print("pub inline fn {c}(", .{name_fmt});
                                try translateFnParams(subtype.*, tree, mapper, anon_typedef_map, .definition, writer);
                                try writer.writeAll(") ");
                                try translateType(subtype.data.func.return_type, tree, mapper, anon_typedef_map, writer);
                                try writer.writeAll(" {\n");
                                try writer.print("    return bindings.{s}.?(", .{name_fmt});
                                try translateFnParams(subtype.*, tree, mapper, anon_typedef_map, .call, writer);
                                try writer.writeAll(");\n}\n");
                                return;
                            }
                        }
                    }
                },
                else => {},
            }

            const typedef_name = tree.tokSlice(data.decl.name);
            if (std.mem.endsWith(u8, typedef_name, "_t")) {
                return;
            }
            const loc: aro.Source.Location = tree.tokens.items(.loc)[data.decl.name];
            if (loc.id == public_source) {
                try writer.writeAll("pub ");
            }

            try writer.print("const {p} = ", .{fmt.fmtId(noGdxPrefix(typedef_name))});

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
            const name_fmt = fmt.fmtId(noGdxPrefix(struct_name));
            try writer.print("const {p} = extern struct {{\n", .{name_fmt});
            for (tree.data[data.range.start..data.range.end]) |stmt| {
                try translateChildNode(tree, mapper, anon_typedef_map, stmt, writer);
            }
            try writer.writeAll("};\n");
        },
        // .struct_decl_two => {
        //     const mapped_name = mapper.lookup(ty.data.record.name);
        //     const struct_name = if (anon_typedef_map.get(mapped_name)) |n| n else mapped_name;

        //     if (ty.data.record.fields.len > 0 and
        //         tree.tokens.items(.loc)[ty.data.record.fields[0].name_tok].id == public_source)
        //     {
        //         try writer.writeAll("pub ");
        //     }
        //     try writer.print("const {p} = struct {{\n", .{fmt.fmtId(noGdxPrefix(struct_name))});
        //     // for (tree.data[data.bin.start..data.range.end]) |stmt| {
        //     //     try translateChildNode(tree, mapper, anon_typedef_map, stmt, writer);
        //     // }
        //     try writer.writeAll("};\n");
        // },
        .@"var" => {
            std.debug.panic(
                \\this case shouldn't be reached, if so likely missing a define.
                \\  decl.name: {s}
                \\  node: {any}
            , .{
                tree.tokSlice(data.decl.name),
                tree.value_map.get(node),
            });
        },
        else => std.debug.panic("unhandled: {s}", .{@tagName(tag)}),
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

    try writer.print("const {p} = enum(c_int) {{\n", .{fmt.fmtId(noGdxPrefix(enum_name))});

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

    const name_fmt = fmt.fmtId(fmt.withoutPrefix(tree.tokSlice(data.decl.name), prefix));
    try writer.print("    {s}", .{name_fmt});
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
            try writer.print("    {s},\n", .{fmt.fmtId(tree.tokSlice(data.decl.name))});
        },
        .record_field_decl => {
            try writer.print("    {s}: ", .{fmt.fmtId(tree.tokSlice(data.decl.name))});
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
    if (ty.qual.@"const") {
        try writer.writeAll("const ");
    }

    if (ty.typedef) |tok| {
        const token = tree.tokSlice(tok);
        if (std.mem.eql(u8, token, "size_t")) {
            try writer.writeAll("usize");
            return;
        }
        if (!std.mem.endsWith(u8, token, "_t")) {
            const token_no_gdx = noGdxPrefix(token);
            if (std.mem.eql(u8, token_no_gdx, "Bool")) {
                try writer.writeAll("bool");
                return;
            }
            if (!std.mem.eql(u8, token_no_gdx, "Int")) {
                try writer.print("{p}", .{fmt.fmtId(token_no_gdx)});
                return;
            }
        }
    }
    switch (ty.specifier) {
        .void, .bool => |specifier| try writer.writeAll(@tagName(specifier)),

        // int
        .char, .uchar => {
            try writer.writeAll("u8");
        },
        .schar => {
            try writer.writeAll("i8");
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
                    try writer.writeAll("?*");
                    if (sub_type.qual.@"const") {
                        try writer.writeAll("const ");
                    }
                    try writer.writeAll("anyopaque");
                },
                .func, .var_args_func, .old_style_func => {
                    try writer.writeAll("?*const ");
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
            try translateFnParams(ty, tree, mapper, anon_typedef_map, .definition, writer);
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
            try writer.print("{p}", .{fmt.fmtId(noGdxPrefix(name))});
        },
        .@"union" => {
            try writer.writeAll("####union####");
        },

        // data.enum
        .@"enum" => {
            const mapped_name = mapper.lookup(ty.data.@"enum".name);
            const name = if (anon_typedef_map.get(mapped_name)) |n| n else mapped_name;
            try writer.print("{p}", .{fmt.fmtId(noGdxPrefix(name))});
        },
        else => {
            @panic("unhandled");
        },
    }
}

fn translateFnParams(
    ty: aro.Type,
    tree: aro.Tree,
    mapper: aro.TypeMapper,
    anon_typedef_map: std.StringHashMap([]const u8),
    comptime syntax: enum { definition, call },
    writer: anytype,
) anyerror!void {
    switch (ty.specifier) {
        inline .func, .var_args_func, .old_style_func => |spec| {
            const func = ty.data.func;
            for (func.params, 0..) |param, i| {
                const param_name = mapper.lookup(param.name);
                switch (syntax) {
                    .call => {
                        if (param_name.len != 0) {
                            try writer.print("{s}", .{fmt.fmtId(param_name)});
                        } else {
                            try writer.print("@\"{d}\"", .{i});
                        }
                    },
                    .definition => {
                        if (param_name.len != 0) {
                            try writer.print("{s}: ", .{fmt.fmtId(param_name)});
                        }
                        try translateType(param.ty, tree, mapper, anon_typedef_map, writer);
                    },
                }
                if (spec == .func and i != func.params.len - 1) {
                    try writer.writeAll(", ");
                }
            }
            if (syntax == .definition and spec != .func) {
                try writer.writeAll("...");
            }
        },
        else => unreachable,
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
