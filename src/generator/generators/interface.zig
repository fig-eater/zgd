const std = @import("std");
const Dir = std.fs.Dir;
const aro = @import("aro");
const fmt = @import("../fmt.zig");

pub fn generate(
    allocator: std.mem.Allocator,
    interface_path: []const u8,
    include_path: []const u8,
    output_dir: Dir,
) !void {
    const file = try output_dir.createFile("interface.zig", .{});
    defer file.close();
    const writer = file.writer();

    var comp = try aro.Compilation.initDefault(allocator);
    defer comp.deinit();
    try comp.addSystemIncludeDir(include_path);

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

    var anon_typedef_map = try gatherAnonymousTypedefMap(tree, mapper);
    defer anon_typedef_map.deinit();

    for (tree.root_decls) |i| {
        try translateNode(i, tree, mapper, anon_typedef_map, public_source, writer);
    }
}

fn translateNode(
    node: aro.Tree.NodeIndex,
    tree: aro.Tree,
    mapper: aro.TypeMapper,
    anon_typedef_map: std.StringHashMap([]const u8),
    public_source: aro.Source.Id,
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
                    if (std.mem.eql(u8, data.decl.name, "size_t")) {}
                },
                .fp16,
                .float16,
                .float,
                .double,
                .long_double,
                .float128,
                => {},
                else => {},
            }

            const loc: aro.Source.Location = tree.tokens.items(.loc)[data.decl.name];
            if (loc.id == public_source) {
                try writer.writeAll("pub ");
            }
            // TODO conditionally set formatting based on the right-hand side
            try writer.print("const {p} = ", .{fmt.IdFormatter{
                .data = tree.tokSlice(data.decl.name),
            }});

            try translateType(ty, tree, mapper, anon_typedef_map, writer);
            try writer.writeAll(";\n");

            if (data.decl.node != .none) {
                std.log.err("unhandled\n", .{});
            }
        },
        .enum_decl => {
            const enum_type_name = mapper.lookup(ty.data.@"enum".name);
            const enum_name = if (anon_typedef_map.get(enum_type_name)) |n| n else enum_type_name;

            if (ty.data.@"enum".fields.len > 0 and
                tree.tokens.items(.loc)[ty.data.@"enum".fields[0].name_tok].id == public_source)
            {
                try writer.writeAll("pub ");
            }

            try writer.print("const {p} = enum {{\n", .{fmt.IdFormatter{ .data = enum_name }});
            for (tree.data[data.range.start..data.range.end]) |stmt| {
                try translateChildNode(tree, mapper, anon_typedef_map, stmt, writer);
            }
            try writer.writeAll("};\n");
        },
        .struct_decl => {
            const mapped_name = mapper.lookup(ty.data.record.name);
            const struct_name = if (anon_typedef_map.get(mapped_name)) |n| n else mapped_name;

            if (ty.data.record.fields.len > 0 and
                tree.tokens.items(.loc)[ty.data.record.fields[0].name_tok].id == public_source)
            {
                try writer.writeAll("pub ");
            }
            try writer.print("const {p} = struct {{\n", .{fmt.IdFormatter{ .data = struct_name }});
            for (tree.data[data.range.start..data.range.end]) |stmt| {
                try translateChildNode(tree, mapper, anon_typedef_map, stmt, writer);
            }
            try writer.writeAll("};\n");
        },
        .struct_decl_two => {},
        else => {
            @panic("unhandled");
        },
    }
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
            try writer.print("    {s},\n", .{fmt.IdFormatter{ .data = tree.tokSlice(data.decl.name) }});
        },
        .record_field_decl => {
            try writer.print("    {s}: ", .{fmt.IdFormatter{ .data = tree.tokSlice(data.decl.name) }});
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
    switch (ty.specifier) {
        .void, .bool => |specifier| try writer.writeAll(@tagName(specifier)),

        // int
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
                    try writer.writeAll("*anyopaque");
                },
                else => {
                    try writer.writeByte('*');
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
        .var_args_func => {
            try writer.writeAll("####varargfn####");
        },
        .old_style_func => {
            try writer.writeAll("####oldstylefn####");
        },

        // data.array
        .array, .static_array, .incomplete_array, .vector => {
            try writer.writeAll("####array####");
        },

        // data.record
        .@"struct" => {
            const mapped_name = mapper.lookup(ty.data.record.name);
            const name = if (anon_typedef_map.get(mapped_name)) |n| n else mapped_name;
            try writer.writeAll(name);
        },
        .@"union" => {
            try writer.writeAll("####union####");
        },

        // data.enum
        .@"enum" => {
            const mapped_name = mapper.lookup(ty.data.@"enum".name);
            const name = if (anon_typedef_map.get(mapped_name)) |n| n else mapped_name;
            try writer.writeAll(name);
        },
        else => {
            @panic("unhandled");
        },
    }
}

fn gatherAnonymousTypedefMap(tree: aro.Tree, mapper: aro.TypeMapper) !std.StringHashMap([]const u8) {
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
