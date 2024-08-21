const std = @import("std");
const func_gen = @import("function_generator.zig");
const Api = @import("../Api.zig");
const util = @import("../util.zig");
const Allocator = std.mem.Allocator;
const fs = @import("../fs.zig");
const Dir = fs.Dir;
const FileWriter = fs.File.Writer;
const fmt = @import("../../fmt.zig");

const BuiltinClassGenerator = *const fn (
    allocator: Allocator,
    output_directory: Dir,
    bindings_directory: Dir,
    class: Api.BuiltinClass,
    godot_writer: FileWriter,
    size: usize,
) anyerror!void;

var builtin_class_custom_generator_map = std.StaticStringMap(BuiltinClassGenerator).initComptime(.{
    .{ "int", &generateBuiltinClassInt },
    .{ "float", &generateBuiltinClassFloat },
    .{ "Nil", &generateBuiltinClassIgnore },
    .{ "bool", &generateBuiltinClassBool },
});

pub fn generate(
    allocator: Allocator,
    output_directory: Dir,
    api: Api,
    build_config: util.BuildConfig,
) !void {
    const file = try output_directory.createFile("builtin_classes.zig", .{});
    defer file.close();
    const builtin_classes_writer = file.writer();

    try fs.makeDirIfMissing(output_directory, "builtin_classes");
    var builtin_classes_dir = try output_directory.openDir("builtin_classes", .{});
    defer builtin_classes_dir.close();

    try fs.makeDirIfMissing(builtin_classes_dir, "internal");
    var internal_dir = try builtin_classes_dir.openDir("internal", .{});
    defer internal_dir.close();

    var built_in_size_map = try initBuiltinSizeMap(
        allocator,
        api.builtin_class_sizes,
        build_config,
    );
    defer built_in_size_map.deinit();

    for (api.builtin_classes) |class| {
        const handler = builtin_class_custom_generator_map.get(class.name) orelse
            &generateBuiltinClass;
        try handler(
            allocator,
            builtin_classes_dir,
            internal_dir,
            class,
            builtin_classes_writer,
            built_in_size_map.get(class.name) orelse 0,
        );
    }
}

fn generateBuiltinClass(
    allocator: Allocator,
    output_dir: Dir,
    internals_dir: Dir,
    class: Api.BuiltinClass,
    builtin_writer: FileWriter,
    size: usize,
) !void {
    const fmt_class_name = fmt.fmtId(class.name);
    try builtin_writer.print("pub const {p} = @import(\"builtin_classes/{p}.zig\");\n", .{
        fmt_class_name,
        fmt_class_name,
    });

    const class_name_id = try fmt.allocPrint(allocator, "{p}", .{fmt_class_name});
    defer allocator.free(class_name_id);

    // setup class file writer
    const file_name = try fmt.allocPrint(allocator, "{s}.zig", .{class_name_id});
    defer allocator.free(file_name);
    const file = try output_dir.createFile(file_name, .{});
    defer file.close();
    const writer = file.writer();

    var static_dir = try output_dir.openDir("../../static", .{});
    defer static_dir.close();

    // setup internal class file writer
    const internal_file_name = try fmt.allocPrint(
        allocator,
        "{s}_" ++ util.internal_name ++ ".zig",
        .{class.name},
    );
    defer allocator.free(internal_file_name);
    const internal_file = try internals_dir.createFile(internal_file_name, .{});
    defer internal_file.close();
    const internal_writer = internal_file.writer();

    if (static_dir.access(file_name, .{})) {
        try writer.print("pub usingnamespace @import(\"../../static/{s}\");\n", .{file_name});
    } else |_| {}
    try writer.writeAll("const gd = @import(\"../../gen_root.zig\");\n");
    try writer.print(
        "pub const internal = @import(\"" ++ util.internal_name ++ "/{s}\");\n",
        .{internal_file_name},
    );
    try writer.writeAll(util.opaque_field_name ++ ": [internal.size]u8,\n");

    try internal_writer.writeAll("const gd = @import(\"../../../gen_root.zig\");\n");
    try internal_writer.print("pub const size = {d};\n", .{size});

    // method bindings
    if (class.methods) |methods| {

        // write hashes
        try internal_writer.writeAll("pub const hashes = .{\n");
        for (methods) |func| {
            try internal_writer.print("    .{s} = {d},\n", .{ func.name, func.hash });
        }
        try internal_writer.writeAll("};\n");

        try func_gen.writeConstructor(writer, internal_writer, class_name_id, class); // write constructors

        try internal_writer.writeAll("pub const " ++ util.function_bindings_name ++ " = struct {\n");
        for (methods) |func| {
            const func_name_fmt = fmt.fmtId(func.name);
            const func_name_s = try fmt.allocPrint(allocator, "{s}", .{func_name_fmt});
            defer allocator.free(func_name_s);

            const return_type_id = try fmt.allocPrint(allocator, "{p}", .{fmt.fmtId(func.return_type)});
            defer allocator.free(return_type_id);

            try internal_writer.print("    pub var {s}: ?*fn (", .{func_name_s});
            try writer.print("pub inline fn {c}(", .{func_name_fmt});

            // add self as first param if non-static
            if (!func.is_static) {
                if (func.is_const) {
                    try writer.print("self: gd.{s}", .{class_name_id});
                    try internal_writer.print("self: gd.{s}", .{class_name_id});
                } else {
                    try writer.print("self: *gd.{s}", .{class_name_id});
                    try internal_writer.print("self: *gd.{s}", .{class_name_id});
                }
            }

            if (func.arguments) |args| {
                if (!func.is_static) {
                    try writer.writeAll(", ");
                    try internal_writer.writeAll(", ");
                }
                try func_gen.writeFunctionArgs(internal_writer, args);
                try func_gen.writeFunctionArgs(writer, args);
            }
            try internal_writer.print(") gd.{s} = undefined;\n", .{return_type_id});
            try writer.print(") gd.{s} {{\n", .{return_type_id});

            { // call binding function
                try writer.print("    return internal.bindings.{s}(", .{func_name_s});

                if (!func.is_static) {
                    try writer.writeAll("self");
                }

                if (func.arguments) |args| {
                    if (!func.is_static) {
                        try writer.writeAll(", ");
                    }
                    try writer.print("{_s}", .{fmt.fmtId(args[0].name)});
                    for (args[1..]) |arg| {
                        try writer.print(", {_s}", .{fmt.fmtId(arg.name)});
                    }
                }

                try writer.writeAll(");\n");
            }
            try writer.writeAll("}\n"); // close function definition
        }
        try internal_writer.writeAll("};\n");
    }
}
fn generateBuiltinClassBool(
    _: Allocator,
    _: Dir,
    _: Dir,
    _: Api.BuiltinClass,
    godot_writer: FileWriter,
    _: usize,
) !void {
    try godot_writer.writeAll("pub const Bool = bool;\n");
}
fn generateBuiltinClassIgnore(
    _: Allocator,
    _: Dir,
    _: Dir,
    _: Api.BuiltinClass,
    _: FileWriter,
    _: usize,
) !void {}
fn generateBuiltinClassInt(
    _: Allocator,
    _: Dir,
    _: Dir,
    _: Api.BuiltinClass,
    godot_writer: FileWriter,
    _: usize,
) !void {
    try godot_writer.writeAll("pub const Int = i64;\n");
}
fn generateBuiltinClassFloat(
    _: Allocator,
    _: Dir,
    _: Dir,
    _: Api.BuiltinClass,
    godot_writer: FileWriter,
    _: usize,
) !void {
    try godot_writer.writeAll("pub const Float = f64;\n");
}

fn initBuiltinSizeMap(
    allocator: Allocator,
    class_size_configurations: []const Api.BuiltinClassSize,
    build_config: util.BuildConfig,
) !std.StringHashMap(usize) {
    var class_size_map = std.StringHashMap(usize).init(allocator);
    errdefer class_size_map.deinit();
    const build_config_name = @tagName(build_config);
    for (class_size_configurations) |configuration| {
        if (std.mem.eql(u8, configuration.build_configuration, build_config_name)) {
            for (configuration.sizes) |size| {
                try class_size_map.put(size.name, @intCast(size.size));
            }
            return class_size_map;
        }
    }
    return error.ConfigurationNotFound;
}
