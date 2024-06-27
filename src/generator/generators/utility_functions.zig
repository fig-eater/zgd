const std = @import("std");
const func_gen = @import("function_generator.zig");
const Api = @import("../Api.zig");
const Dir = std.fs.Dir;

pub fn generate(output_directory: Dir, functions: []const Api.Function) !void {
    const file = try output_directory.createFile("utility_functions.zig", .{});
    defer file.close();
    const writer = file.writer();

    try writer.writeAll("const bindings = struct {\n");
    for (functions) |func| {
        try func_gen.writeFunction(writer, func);
    }
    try writer.writeAll("};\n");
}
