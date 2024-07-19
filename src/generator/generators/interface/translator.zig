// This is specialized to only work for the gdextension_interface.h
const std = @import("std");
const aro = @import("aro");

const Tree = aro.Tree;
const NodeIndex = Tree.NodeIndex;

pub fn translate(tree: Tree) !void {
    _ = tree;
    // const mapper = try tree.comp.string_interner.getFastTypeMapper(tree.comp.gpa) catch tree.comp.string_interner.getSlowTypeMapper();
    // defer mapper.deinit(tree.comp.gpa);
    // for (tree.root_decls) |node| {
    //     try translateNode(tree, node);
    // }
}

pub fn translateNode(tree: *const Tree, node: NodeIndex) !void {
    const tag: aro.Tree.Tag = tree.nodes.items(.tag)[@intFromEnum(node)];
    const @"type": aro.Type = tree.nodes.items(.ty)[@intFromEnum(node)];
    const data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(node)];
    _ = @"type";
    _ = data;

    switch (tag) {
        .typedef => {},
        .enum_decl => {},
        .enum_field_decl => {},
        .struct_decl => {},
        .record_field_decl => {},
        else => std.debug.panic("Unexpected {s} in gdextension_interface.h", .{@tagName(tag)}),
    }
}

// pub fn translateEnum(tree: *const Tree, node: NodeIndex) !void {
//     const tag: aro.Tree.Tag = tree.nodes.items(.tag)[@intFromEnum(node)];
//     const @"type": aro.Type = tree.nodes.items(.ty)[@intFromEnum(node)];
//     const data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(node)];
//     switch (tag) {
//         .enum_decl => {},
//         else => unreachable,
//     }

//     \\pub const NAME = enum {
//     \\
//     \\};
//     \\
//     ;

//     const maybe_field_attributes = if (@"type".getRecord()) |record| record.field_attributes else null;
//     for (tree.data[data.range.start..data.range.end], 0..) |stmt, i| {
//         // if (i != 0) try w.writeByte('\n');
//         // try tree.dumpNode(stmt, level + delta, mapper, config, w);
//     }
// }

// pub fn dumpNode(
//     tree: *const Tree,
//     node: NodeIndex,
//     level: u32,
//     mapper: @TypeOf(tree.comp.string_interner),
//     config: std.io.tty.Config,
//     w: anytype,
// ) !void {
//     const delta = 2;
//     const half = delta / 2;
//     const TYPE = std.io.tty.Color.bright_magenta;
//     const TAG = std.io.tty.Color.bright_cyan;
//     const IMPLICIT = std.io.tty.Color.bright_blue;
//     const NAME = std.io.tty.Color.bright_red;
//     const LITERAL = std.io.tty.Color.bright_green;
//     const ATTRIBUTE = std.io.tty.Color.bright_yellow;
//     std.debug.assert(node != .none);

//     const tag = tree.nodes.items(.tag)[@intFromEnum(node)];
//     const data = tree.nodes.items(.data)[@intFromEnum(node)];
//     const ty = tree.nodes.items(.ty)[@intFromEnum(node)];
//     try w.writeByteNTimes(' ', level);

//     try config.setColor(w, if (tag.isImplicit()) IMPLICIT else TAG);
//     try w.print("{s}: ", .{@tagName(tag)});
//     if (tag == .implicit_cast or tag == .explicit_cast) {
//         try config.setColor(w, .white);
//         try w.print("({s}) ", .{@tagName(data.cast.kind)});
//     }
//     try config.setColor(w, TYPE);
//     try w.writeByte('\'');
//     try ty.dump(mapper, tree.comp.langopts, w);
//     try w.writeByte('\'');

//     if (tree.isLval(node)) {
//         try config.setColor(w, ATTRIBUTE);
//         try w.writeAll(" lvalue");
//     }
//     if (tree.isBitfield(node)) {
//         try config.setColor(w, ATTRIBUTE);
//         try w.writeAll(" bitfield");
//     }
//     if (tree.value_map.get(node)) |val| {
//         try config.setColor(w, LITERAL);
//         try w.writeAll(" (value: ");
//         try val.print(ty, tree.comp, w);
//         try w.writeByte(')');
//     }
//     if (tag == .implicit_return and data.return_zero) {
//         try config.setColor(w, IMPLICIT);
//         try w.writeAll(" (value: 0)");
//         try config.setColor(w, .reset);
//     }

//     try w.writeAll("\n");
//     try config.setColor(w, .reset);

//     if (ty.specifier == .attributed) {
//         try config.setColor(w, ATTRIBUTE);
//         for (ty.data.attributed.attributes) |attr| {
//             try w.writeByteNTimes(' ', level + half);
//             try w.print("attr: {s}", .{@tagName(attr.tag)});
//             try tree.dumpAttribute(attr, w);
//         }
//         try config.setColor(w, .reset);
//     }

//     switch (tag) {
//         .invalid => unreachable,
//         .file_scope_asm => {
//             try w.writeByteNTimes(' ', level + 1);
//             try tree.dumpNode(data.decl.node, level + delta, mapper, config, w);
//         },
//         .gnu_asm_simple => {
//             try w.writeByteNTimes(' ', level);
//             try tree.dumpNode(data.un, level, mapper, config, w);
//         },
//         .static_assert => {
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("condition:\n");
//             try tree.dumpNode(data.bin.lhs, level + delta, mapper, config, w);
//             if (data.bin.rhs != .none) {
//                 try w.writeByteNTimes(' ', level + 1);
//                 try w.writeAll("diagnostic:\n");
//                 try tree.dumpNode(data.bin.rhs, level + delta, mapper, config, w);
//             }
//         },
//         .fn_proto,
//         .static_fn_proto,
//         .inline_fn_proto,
//         .inline_static_fn_proto,
//         => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
//             try config.setColor(w, .reset);
//         },
//         .fn_def,
//         .static_fn_def,
//         .inline_fn_def,
//         .inline_static_fn_def,
//         => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
//             try config.setColor(w, .reset);
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("body:\n");
//             try tree.dumpNode(data.decl.node, level + delta, mapper, config, w);
//         },
//         .typedef,
//         .@"var",
//         .extern_var,
//         .static_var,
//         .implicit_static_var,
//         .threadlocal_var,
//         .threadlocal_extern_var,
//         .threadlocal_static_var,
//         => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
//             try config.setColor(w, .reset);
//             if (data.decl.node != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("init:\n");
//                 try tree.dumpNode(data.decl.node, level + delta, mapper, config, w);
//             }
//         },
//         .enum_field_decl => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
//             try config.setColor(w, .reset);
//             if (data.decl.node != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("value:\n");
//                 try tree.dumpNode(data.decl.node, level + delta, mapper, config, w);
//             }
//         },
//         .record_field_decl => {
//             if (data.decl.name != 0) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("name: ");
//                 try config.setColor(w, NAME);
//                 try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
//                 try config.setColor(w, .reset);
//             }
//             if (data.decl.node != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("bits:\n");
//                 try tree.dumpNode(data.decl.node, level + delta, mapper, config, w);
//             }
//         },
//         .indirect_record_field_decl => {},
//         .compound_stmt,
//         .array_init_expr,
//         .struct_init_expr,
//         .enum_decl,
//         .struct_decl,
//         .union_decl,
//         => {
//             const maybe_field_attributes = if (ty.getRecord()) |record| record.field_attributes else null;
//             for (tree.data[data.range.start..data.range.end], 0..) |stmt, i| {
//                 if (i != 0) try w.writeByte('\n');
//                 try tree.dumpNode(stmt, level + delta, mapper, config, w);
//                 if (maybe_field_attributes) |field_attributes| {
//                     if (field_attributes[i].len == 0) continue;

//                     try config.setColor(w, ATTRIBUTE);
//                     try tree.dumpFieldAttributes(field_attributes[i], level + delta + half, w);
//                     try config.setColor(w, .reset);
//                 }
//             }
//         },
//         .compound_stmt_two,
//         .array_init_expr_two,
//         .struct_init_expr_two,
//         .enum_decl_two,
//         .struct_decl_two,
//         .union_decl_two,
//         => {
//             var attr_array = [2][]const Attribute{ &.{}, &.{} };
//             const empty: [][]const Attribute = &attr_array;
//             const field_attributes = if (ty.getRecord()) |record| (record.field_attributes orelse empty.ptr) else empty.ptr;
//             if (data.bin.lhs != .none) {
//                 try tree.dumpNode(data.bin.lhs, level + delta, mapper, config, w);
//                 if (field_attributes[0].len > 0) {
//                     try config.setColor(w, ATTRIBUTE);
//                     try tree.dumpFieldAttributes(field_attributes[0], level + delta + half, w);
//                     try config.setColor(w, .reset);
//                 }
//             }
//             if (data.bin.rhs != .none) {
//                 try tree.dumpNode(data.bin.rhs, level + delta, mapper, config, w);
//                 if (field_attributes[1].len > 0) {
//                     try config.setColor(w, ATTRIBUTE);
//                     try tree.dumpFieldAttributes(field_attributes[1], level + delta + half, w);
//                     try config.setColor(w, .reset);
//                 }
//             }
//         },
//         .union_init_expr => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("field index: ");
//             try config.setColor(w, LITERAL);
//             try w.print("{d}\n", .{data.union_init.field_index});
//             try config.setColor(w, .reset);
//             if (data.union_init.node != .none) {
//                 try tree.dumpNode(data.union_init.node, level + delta, mapper, config, w);
//             }
//         },
//         .compound_literal_expr,
//         .static_compound_literal_expr,
//         .thread_local_compound_literal_expr,
//         .static_thread_local_compound_literal_expr,
//         => {
//             try tree.dumpNode(data.un, level + half, mapper, config, w);
//         },
//         .labeled_stmt => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("label: ");
//             try config.setColor(w, LITERAL);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
//             try config.setColor(w, .reset);
//             if (data.decl.node != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("stmt:\n");
//                 try tree.dumpNode(data.decl.node, level + delta, mapper, config, w);
//             }
//         },
//         .case_stmt => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("value:\n");
//             try tree.dumpNode(data.bin.lhs, level + delta, mapper, config, w);
//             if (data.bin.rhs != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("stmt:\n");
//                 try tree.dumpNode(data.bin.rhs, level + delta, mapper, config, w);
//             }
//         },
//         .case_range_stmt => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("range start:\n");
//             try tree.dumpNode(tree.data[data.if3.body], level + delta, mapper, config, w);

//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("range end:\n");
//             try tree.dumpNode(tree.data[data.if3.body + 1], level + delta, mapper, config, w);

//             if (data.if3.cond != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("stmt:\n");
//                 try tree.dumpNode(data.if3.cond, level + delta, mapper, config, w);
//             }
//         },
//         .default_stmt => {
//             if (data.un != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("stmt:\n");
//                 try tree.dumpNode(data.un, level + delta, mapper, config, w);
//             }
//         },
//         .binary_cond_expr, .cond_expr, .if_then_else_stmt, .builtin_choose_expr => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("cond:\n");
//             try tree.dumpNode(data.if3.cond, level + delta, mapper, config, w);

//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("then:\n");
//             try tree.dumpNode(tree.data[data.if3.body], level + delta, mapper, config, w);

//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("else:\n");
//             try tree.dumpNode(tree.data[data.if3.body + 1], level + delta, mapper, config, w);
//         },
//         .builtin_types_compatible_p => {
//             std.debug.assert(tree.nodes.items(.tag)[@intFromEnum(data.bin.lhs)] == .invalid);
//             std.debug.assert(tree.nodes.items(.tag)[@intFromEnum(data.bin.rhs)] == .invalid);

//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("lhs: ");

//             const lhs_ty = tree.nodes.items(.ty)[@intFromEnum(data.bin.lhs)];
//             try config.setColor(w, TYPE);
//             try lhs_ty.dump(mapper, tree.comp.langopts, w);
//             try config.setColor(w, .reset);
//             try w.writeByte('\n');

//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("rhs: ");

//             const rhs_ty = tree.nodes.items(.ty)[@intFromEnum(data.bin.rhs)];
//             try config.setColor(w, TYPE);
//             try rhs_ty.dump(mapper, tree.comp.langopts, w);
//             try config.setColor(w, .reset);
//             try w.writeByte('\n');
//         },
//         .if_then_stmt => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("cond:\n");
//             try tree.dumpNode(data.bin.lhs, level + delta, mapper, config, w);

//             if (data.bin.rhs != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("then:\n");
//                 try tree.dumpNode(data.bin.rhs, level + delta, mapper, config, w);
//             }
//         },
//         .switch_stmt, .while_stmt, .do_while_stmt => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("cond:\n");
//             try tree.dumpNode(data.bin.lhs, level + delta, mapper, config, w);

//             if (data.bin.rhs != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("body:\n");
//                 try tree.dumpNode(data.bin.rhs, level + delta, mapper, config, w);
//             }
//         },
//         .for_decl_stmt => {
//             const for_decl = data.forDecl(tree);

//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("decl:\n");
//             for (for_decl.decls) |decl| {
//                 try tree.dumpNode(decl, level + delta, mapper, config, w);
//                 try w.writeByte('\n');
//             }
//             if (for_decl.cond != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("cond:\n");
//                 try tree.dumpNode(for_decl.cond, level + delta, mapper, config, w);
//             }
//             if (for_decl.incr != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("incr:\n");
//                 try tree.dumpNode(for_decl.incr, level + delta, mapper, config, w);
//             }
//             if (for_decl.body != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("body:\n");
//                 try tree.dumpNode(for_decl.body, level + delta, mapper, config, w);
//             }
//         },
//         .forever_stmt => {
//             if (data.un != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("body:\n");
//                 try tree.dumpNode(data.un, level + delta, mapper, config, w);
//             }
//         },
//         .for_stmt => {
//             const for_stmt = data.forStmt(tree);

//             if (for_stmt.init != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("init:\n");
//                 try tree.dumpNode(for_stmt.init, level + delta, mapper, config, w);
//             }
//             if (for_stmt.cond != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("cond:\n");
//                 try tree.dumpNode(for_stmt.cond, level + delta, mapper, config, w);
//             }
//             if (for_stmt.incr != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("incr:\n");
//                 try tree.dumpNode(for_stmt.incr, level + delta, mapper, config, w);
//             }
//             if (for_stmt.body != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("body:\n");
//                 try tree.dumpNode(for_stmt.body, level + delta, mapper, config, w);
//             }
//         },
//         .goto_stmt, .addr_of_label => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("label: ");
//             try config.setColor(w, LITERAL);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl_ref)});
//             try config.setColor(w, .reset);
//         },
//         .continue_stmt, .break_stmt, .implicit_return, .null_stmt => {},
//         .return_stmt => {
//             if (data.un != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("expr:\n");
//                 try tree.dumpNode(data.un, level + delta, mapper, config, w);
//             }
//         },
//         .call_expr => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("lhs:\n");
//             try tree.dumpNode(tree.data[data.range.start], level + delta, mapper, config, w);

//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("args:\n");
//             for (tree.data[data.range.start + 1 .. data.range.end]) |arg| try tree.dumpNode(arg, level + delta, mapper, config, w);
//         },
//         .call_expr_one => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("lhs:\n");
//             try tree.dumpNode(data.bin.lhs, level + delta, mapper, config, w);
//             if (data.bin.rhs != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("arg:\n");
//                 try tree.dumpNode(data.bin.rhs, level + delta, mapper, config, w);
//             }
//         },
//         .builtin_call_expr => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{tree.tokSlice(@intFromEnum(tree.data[data.range.start]))});
//             try config.setColor(w, .reset);

//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("args:\n");
//             for (tree.data[data.range.start + 1 .. data.range.end]) |arg| try tree.dumpNode(arg, level + delta, mapper, config, w);
//         },
//         .builtin_call_expr_one => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
//             try config.setColor(w, .reset);
//             if (data.decl.node != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("arg:\n");
//                 try tree.dumpNode(data.decl.node, level + delta, mapper, config, w);
//             }
//         },
//         .special_builtin_call_one => {
//             try w.writeByteNTimes(' ', level + half);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
//             try config.setColor(w, .reset);
//             if (data.decl.node != .none) {
//                 try w.writeByteNTimes(' ', level + half);
//                 try w.writeAll("arg:\n");
//                 try tree.dumpNode(data.decl.node, level + delta, mapper, config, w);
//             }
//         },
//         .comma_expr,
//         .assign_expr,
//         .mul_assign_expr,
//         .div_assign_expr,
//         .mod_assign_expr,
//         .add_assign_expr,
//         .sub_assign_expr,
//         .shl_assign_expr,
//         .shr_assign_expr,
//         .bit_and_assign_expr,
//         .bit_xor_assign_expr,
//         .bit_or_assign_expr,
//         .bool_or_expr,
//         .bool_and_expr,
//         .bit_or_expr,
//         .bit_xor_expr,
//         .bit_and_expr,
//         .equal_expr,
//         .not_equal_expr,
//         .less_than_expr,
//         .less_than_equal_expr,
//         .greater_than_expr,
//         .greater_than_equal_expr,
//         .shl_expr,
//         .shr_expr,
//         .add_expr,
//         .sub_expr,
//         .mul_expr,
//         .div_expr,
//         .mod_expr,
//         => {
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("lhs:\n");
//             try tree.dumpNode(data.bin.lhs, level + delta, mapper, config, w);
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("rhs:\n");
//             try tree.dumpNode(data.bin.rhs, level + delta, mapper, config, w);
//         },
//         .explicit_cast, .implicit_cast => try tree.dumpNode(data.cast.operand, level + delta, mapper, config, w),
//         .addr_of_expr,
//         .computed_goto_stmt,
//         .deref_expr,
//         .plus_expr,
//         .negate_expr,
//         .bit_not_expr,
//         .bool_not_expr,
//         .pre_inc_expr,
//         .pre_dec_expr,
//         .imag_expr,
//         .real_expr,
//         .post_inc_expr,
//         .post_dec_expr,
//         .paren_expr,
//         => {
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("operand:\n");
//             try tree.dumpNode(data.un, level + delta, mapper, config, w);
//         },
//         .decl_ref_expr => {
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl_ref)});
//             try config.setColor(w, .reset);
//         },
//         .enumeration_ref => {
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{tree.tokSlice(data.decl_ref)});
//             try config.setColor(w, .reset);
//         },
//         .bool_literal,
//         .nullptr_literal,
//         .int_literal,
//         .char_literal,
//         .float_literal,
//         .string_literal_expr,
//         => {},
//         .member_access_expr, .member_access_ptr_expr => {
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("lhs:\n");
//             try tree.dumpNode(data.member.lhs, level + delta, mapper, config, w);

//             var lhs_ty = tree.nodes.items(.ty)[@intFromEnum(data.member.lhs)];
//             if (lhs_ty.isPtr()) lhs_ty = lhs_ty.elemType();
//             lhs_ty = lhs_ty.canonicalize(.standard);

//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("name: ");
//             try config.setColor(w, NAME);
//             try w.print("{s}\n", .{mapper.lookup(lhs_ty.data.record.fields[data.member.index].name)});
//             try config.setColor(w, .reset);
//         },
//         .array_access_expr => {
//             if (data.bin.lhs != .none) {
//                 try w.writeByteNTimes(' ', level + 1);
//                 try w.writeAll("lhs:\n");
//                 try tree.dumpNode(data.bin.lhs, level + delta, mapper, config, w);
//             }
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("index:\n");
//             try tree.dumpNode(data.bin.rhs, level + delta, mapper, config, w);
//         },
//         .sizeof_expr, .alignof_expr => {
//             if (data.un != .none) {
//                 try w.writeByteNTimes(' ', level + 1);
//                 try w.writeAll("expr:\n");
//                 try tree.dumpNode(data.un, level + delta, mapper, config, w);
//             }
//         },
//         .generic_expr_one => {
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("controlling:\n");
//             try tree.dumpNode(data.bin.lhs, level + delta, mapper, config, w);
//             try w.writeByteNTimes(' ', level + 1);
//             if (data.bin.rhs != .none) {
//                 try w.writeAll("chosen:\n");
//                 try tree.dumpNode(data.bin.rhs, level + delta, mapper, config, w);
//             }
//         },
//         .generic_expr => {
//             const nodes = tree.data[data.range.start..data.range.end];
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("controlling:\n");
//             try tree.dumpNode(nodes[0], level + delta, mapper, config, w);
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("chosen:\n");
//             try tree.dumpNode(nodes[1], level + delta, mapper, config, w);
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("rest:\n");
//             for (nodes[2..]) |expr| {
//                 try tree.dumpNode(expr, level + delta, mapper, config, w);
//             }
//         },
//         .generic_association_expr, .generic_default_expr, .stmt_expr, .imaginary_literal => {
//             try tree.dumpNode(data.un, level + delta, mapper, config, w);
//         },
//         .array_filler_expr => {
//             try w.writeByteNTimes(' ', level + 1);
//             try w.writeAll("count: ");
//             try config.setColor(w, LITERAL);
//             try w.print("{d}\n", .{data.int});
//             try config.setColor(w, .reset);
//         },
//         .struct_forward_decl,
//         .union_forward_decl,
//         .enum_forward_decl,
//         .default_init_expr,
//         .cond_dummy_expr,
//         => {},
//     }
// }
