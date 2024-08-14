const std = @import("std");
const func_gen = @import("function_generator.zig");
const Api = @import("../Api.zig");
const Dir = std.fs.Dir;
const fmt = @import("../../fmt.zig");

pub fn generate(output_directory: Dir, functions: []const Api.Function) !void {
    const file = try output_directory.createFile("utility_functions.zig", .{});
    defer file.close();
    const writer = file.writer();

    try writer.writeAll("const gd = @import(\"../gen_root.zig\");\n");

    for (functions) |func| {
        const fmt_name = fmt.fmtId(func.name);
        try writer.print("pub fn {c}(", .{fmt_name});
        if (func.arguments) |args| {
            try func_gen.writeFunctionArgs(writer, args);
        }
        try writer.print(") gd.{p} {{\n    return bindings.{c}.?(", .{ fmt.fmtId(func.return_type), fmt_name });
        if (func.arguments) |args| {
            try func_gen.writeCallArgs(writer, args);
        }
        try writer.writeAll(");\n}\n");
    }

    try writer.writeAll("const bindings = struct {\n");
    for (functions) |func| {
        try func_gen.writeFunction(writer, func);
    }
    try writer.writeAll("};\n");
}
