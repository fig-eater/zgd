const std = @import("std");
const func_gen = @import("function_generator.zig");
const Api = @import("../Api.zig");
const common = @import("../common.zig");
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;
const FileWriter = std.fs.File.Writer;

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
    godot_writer: FileWriter,
    api: Api,
    build_config: common.BuildConfig,
) !void {
    var built_in_size_map = try initBuiltinSizeMap(allocator, api.builtin_class_sizes, build_config);
    defer built_in_size_map.deinit();

    try common.makeDirIfMissing(output_directory, "classes");
    const classes_dir = try output_directory.openDir("classes", .{});

    try common.makeDirIfMissing(classes_dir, "internal");
    const internal_dir = try classes_dir.openDir("internal", .{});

    for (api.builtin_classes) |class| {
        const handler = builtin_class_custom_generator_map.get(class.name) orelse
            &generateBuiltinClass;
        try handler(
            allocator,
            classes_dir,
            internal_dir,
            class,
            godot_writer,
            built_in_size_map.get(class.name) orelse 0,
        );
    }
}

fn generateBuiltinClass(
    allocator: Allocator,
    output_dir: Dir,
    internals_dir: Dir,
    class: Api.BuiltinClass,
    godot_writer: FileWriter,
    size: usize,
) !void {
    var id_fmt: common.IdFormatter = undefined;
    id_fmt.data = class.name;
    try godot_writer.print("pub const {p} = @import(\"classes/{s}.zig\");\n", .{
        id_fmt,
        class.name,
    });

    id_fmt.data = class.name;
    const class_name_id = try std.fmt.allocPrint(allocator, "{p}", .{id_fmt});
    defer allocator.free(class_name_id);

    // setup class file writer
    const file_name = try std.fmt.allocPrint(allocator, "{s}.zig", .{class_name_id});
    defer allocator.free(file_name);
    const file = try output_dir.createFile(file_name, .{});
    defer file.close();
    const writer = file.writer();

    // setup internal class file writer
    const internal_file_name = try std.fmt.allocPrint(
        allocator,
        "{s}_" ++ common.internal_name ++ ".zig",
        .{class.name},
    );
    defer allocator.free(internal_file_name);
    const internal_file = try internals_dir.createFile(internal_file_name, .{});
    defer internal_file.close();
    const internal_file_writer = internal_file.writer();

    // import godot lib into both
    try writer.writeAll("const overloading = @import(\"overloading\");\n");
    try writer.writeAll("const GD = @import(\"../godot.zig\");\n");
    try internal_file_writer.writeAll("const GD = @import(\"../../godot.zig\");\n");

    // import internal into class file
    try writer.print(
        "const internal = @import(\"" ++ common.internal_name ++ "/{s}\");\n",
        .{internal_file_name},
    );

    // write class size to internal
    try internal_file_writer.print("pub const size = {d};\n", .{size});

    // write opaque blob to class
    try writer.writeAll(common.opaque_field_name ++ ": [internal.size]u8,\n");

    // method bindings
    if (class.methods) |methods| {
        try func_gen.writeConstructor(writer, internal_file_writer, class_name_id, class); // write constructors

        try internal_file_writer.writeAll("var " ++ common.function_bindings_name ++ ": struct {\n");
        for (methods) |func| {
            id_fmt.data = func.name;
            const func_name_id = try std.fmt.allocPrint(allocator, "{c}", .{id_fmt});
            defer allocator.free(func_name_id);

            id_fmt.data = func.return_type;
            const return_type_id = try std.fmt.allocPrint(allocator, "{p}", .{id_fmt});
            defer allocator.free(return_type_id);

            try internal_file_writer.print("    {s}: *fn (", .{func_name_id});
            try writer.print("pub inline fn {s}(", .{func_name_id});

            // add self as first param if non-static
            if (!func.is_static) {
                if (func.is_const) {
                    try writer.print("self: GD.{s}", .{class_name_id});
                    try internal_file_writer.print("self: GD.{s}", .{class_name_id});
                } else {
                    try writer.print("self: *GD.{s}", .{class_name_id});
                    try internal_file_writer.print("self: *GD.{s}", .{class_name_id});
                }
            }

            if (func.arguments) |args| {
                if (!func.is_static) {
                    try writer.writeAll(", ");
                    try internal_file_writer.writeAll(", ");
                }
                try func_gen.writeFunctionArgs(internal_file_writer, args);
                try func_gen.writeFunctionArgs(writer, args);
            }
            try internal_file_writer.print(") GD.{s},\n", .{return_type_id});
            try writer.print(") GD.{s} {{\n", .{return_type_id});

            { // call binding function
                try writer.print("    return internal.bindings.{s}(", .{func_name_id});

                if (!func.is_static) {
                    try writer.writeAll("self");
                }

                if (func.arguments) |args| {
                    if (!func.is_static) {
                        try writer.writeAll(", ");
                    }
                    id_fmt.data = args[0].name;
                    try writer.print("{s}_", .{id_fmt});
                    for (args[1..]) |arg| {
                        id_fmt.data = arg.name;
                        try writer.print(", {s}_", .{id_fmt});
                    }
                }

                try writer.writeAll(");\n");
            }
            try writer.writeAll("}\n"); // close function definition
        }
        try internal_file_writer.writeAll("} = undefined;\n");
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
    class_size_configurations: []Api.BuiltinClassSize,
    build_config: common.BuildConfig,
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
