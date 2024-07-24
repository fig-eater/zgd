const std = @import("std");
const util = @import("../util.zig");
const aro = @import("aro");

const Dir = std.fs.Dir;

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

    try translate(tree, writer);
}

fn translate(tree: aro.Tree, writer: anytype) !void {
    var mapper = tree.comp.string_interner.getFastTypeMapper(tree.comp.gpa) catch
        tree.comp.string_interner.getSlowTypeMapper();
    defer mapper.deinit(tree.comp.gpa);

    var anon_typedef_map = try gatherAnonymousTypedefMap(tree, mapper);
    defer anon_typedef_map.deinit();

    for (tree.root_decls) |i| {
        try translateNode(tree, mapper, anon_typedef_map, i, writer);
    }
}

fn translateNode(
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
        .typedef => {
            switch (ty.specifier) {
                .@"enum" => {
                    const name = mapper.lookup(ty.data.@"enum".name);
                    if (std.mem.startsWith(u8, name, "(anonymous enum")) return;
                },
                .@"struct" => {
                    const name = mapper.lookup(ty.data.record.name);
                    if (std.mem.startsWith(u8, name, "(anonymous struct")) return;
                },
                else => {},
            }
            const name = tree.tokSlice(data.decl.name);
            try writer.print("const {s} = void;\n", .{name});
            if (data.decl.node != .none) {
                @panic("unhandled");
                // try writer.print("######## unhandled sub typedef!: {s}\n", .{tree.tokSlice(data.decl.name)});
            }
        },
        .enum_decl => {
            const enum_type_name = mapper.lookup(ty.data.@"enum".name);
            const enum_name = if (anon_typedef_map.get(enum_type_name)) |n| n else enum_type_name;
            try writer.print("const {s} = enum {{\n", .{enum_name});
            for (tree.data[data.range.start..data.range.end]) |stmt| {
                try translateNode(tree, mapper, anon_typedef_map, stmt, writer);
            }
            try writer.writeAll("};\n");
        },
        .enum_field_decl => {
            try writer.print("    {s},\n", .{tree.tokSlice(data.decl.name)});
        },
        .struct_decl => {},
        .struct_decl_two => {},
        else => {
            try writer.print("######## unhandled tag!: {s}\n", .{@tagName(tag)});
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
