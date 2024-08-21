const std = @import("std");
const Api = @import("../Api.zig");
const fmt = @import("../../fmt.zig");
const IdFormatter = fmt.IdFormatter;
const Dir = std.fs.Dir;

pub fn writeFunction(writer: anytype, func: Api.Function) !void {
    if (func.arguments) |args| {
        try writer.print("    pub var {c}: ?*const fn (", .{fmt.fmtId(func.name)});
        try writeFunctionArgs(writer, args);
        try writer.print(") callconv(.C) gd.{p} = undefined;\n", .{fmt.fmtId(func.return_type)});
    } else {
        try writer.print("    pub var {c}: ?*const fn () callconv(.C) gd.{p} = undefined;\n", .{
            fmt.fmtId(func.name),
            fmt.fmtId(func.return_type),
        });
    }
}

pub fn writeConstructor(
    writer: anytype,
    internal_writer: anytype,
    class_name_id: []const u8,
    class: Api.BuiltinClass,
) !void {
    if (class.constructors.len == 1) { // write single constructor
        try writer.writeAll("pub inline fn init(");
        try internal_writer.writeAll("pub var init: *const fn (");
        if (class.constructors[0].arguments) |args| {
            try writeFunctionArgs(writer, args);
            try writeFunctionArgs(internal_writer, args);
        }
        try writer.print(") gd.{s} {{\n", .{class_name_id});
        try writer.writeAll("    return internal.init(");
        if (class.constructors[0].arguments) |args| {
            try writeCallArgs(writer, args);
        }
        try internal_writer.print(") gd.{s} = undefined;\n", .{class_name_id});
        try writer.writeAll(");\n}\n");
    } else { // write overloaded
        try writer.writeAll("pub const init = @import(\"overloading\").make(.{\n");
        try internal_writer.writeAll("pub var constructors: struct {\n");
        for (class.constructors) |constructor| {
            try writer.print("    internal.init{d},", .{constructor.index});
            try internal_writer.writeAll("    *const fn (");
            if (constructor.arguments) |args| {
                try writeFunctionArgs(internal_writer, args);
                try writer.writeAll(" // ");
                try writeArgsDocs(writer, args);
            }
            try writer.writeAll("\n");
            try internal_writer.print(") gd.{s},\n", .{class_name_id});
        }
        try writer.writeAll("});\n");
        try internal_writer.writeAll("} = undefined;\n");

        for (class.constructors) |constructor| {
            try internal_writer.print("pub inline fn init{d}(", .{constructor.index});
            if (constructor.arguments) |args| {
                try writeFunctionArgs(internal_writer, args);
            }
            try internal_writer.print(") gd.{s} {{\n", .{class_name_id});
            try internal_writer.print("    return constructors[{d}](", .{constructor.index});
            if (constructor.arguments) |args| {
                try writeCallArgs(internal_writer, args);
            }
            try internal_writer.writeAll(");\n}\n");
        }
    }
}

pub fn writeMethod(writer: anytype, method: Api.Method) !void {
    _ = writer;
    _ = method;
}

// TODO add support for default parameters (use structs with defaults)
pub fn writeFunctionArgs(writer: anytype, args: []const Api.Function.Argument) !void {
    if (args.len == 0) return;
    var name_formatter: IdFormatter = undefined;
    var type_formatter: IdFormatter = undefined;
    name_formatter.data = args[0].name;
    type_formatter.data = args[0].type;
    try writer.print("{_s}: gd.{p}", .{ name_formatter, type_formatter });
    for (args[1..]) |arg| {
        name_formatter.data = arg.name;
        type_formatter.data = arg.type;
        try writer.print(", {_s}: gd.{p}", .{ name_formatter, type_formatter });
    }
}

pub fn writeCallArgs(writer: anytype, args: []const Api.Function.Argument) !void {
    if (args.len == 0) return;
    var name_formatter: IdFormatter = undefined;
    name_formatter.data = args[0].name;
    try writer.print("{_s}", .{name_formatter});
    for (args[1..]) |arg| {
        name_formatter.data = arg.name;
        try writer.print(", {_s}", .{name_formatter});
    }
}

pub fn writeArgsDocs(writer: anytype, args: []const Api.Function.Argument) !void {
    if (args.len == 0) return;
    var name_formatter: IdFormatter = undefined;
    var type_formatter: IdFormatter = undefined;
    name_formatter.data = args[0].name;
    type_formatter.data = args[0].type;
    try writer.print("{_s}:{p}", .{ name_formatter, type_formatter });
    for (args[1..]) |arg| {
        name_formatter.data = arg.name;
        type_formatter.data = arg.type;
        try writer.print(", {_s}:{p}", .{ name_formatter, type_formatter });
    }
}
