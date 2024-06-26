const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const io = std.io;
const Api = @import("extension_api.zig");
const AnyReader = std.io.AnyReader;
const FileWriter = std.fs.File.Writer;
const IdFormatter = std.fmt.Formatter(gen_fmt.formatIdSpecial);
const Dir = std.fs.Dir;
const gen_fmt = @import("fmt.zig");
const gen_fs = @import("fs.zig");
const zig_version_string = @import("builtin").zig_version_string;

const BuiltinClassGenerator = *const fn (
    allocator: Allocator,
    output_directory: Dir,
    bindings_directory: Dir,
    class: Api.BuiltinClass,
    godot_writer: FileWriter,
    size: usize,
) anyerror!void;

// 8mb should be large enough for the whole extension_api.json file
const api_read_buffer_starting_size = 1024 * 1024 * 8;

const build_configuration = "float_32";
const internal_name = "internal";
const function_bindings_name = "bindings";
const opaque_field_name = "__opaque";

const global_enum_prefix_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "Side", "SIDE_" },
    .{ "Corner", "CORNER_" },
    .{ "HorizontalAlignment", "HORIZONTAL_ALIGNMENT_" },
    .{ "VerticalAlignment", "VERTICAL_ALIGNMENT_" },
    .{ "InlineAlignment", "INLINE_ALIGNMENT_" },
    .{ "EulerOrder", "EULER_ORDER_" },
    .{ "Key", "KEY_" },
    .{ "MouseButton", "MOUSE_BUTTON_" },
    .{ "JoyButton", "JOY_BUTTON_" },
    .{ "JoyAxis", "JOY_AXIS_" },
    .{ "MIDIMessage", "MIDI_MESSAGE_" },
    .{ "Error", "ERR_" },
    .{ "PropertyHint", "PROPERTY_HINT_" },
    .{ "Variant.Type", "TYPE_" },
    .{ "Variant.Operator", "OP_" },
});

const type_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "int", "i64" },
    .{ "int32", "i32" },
    .{ "float", "f32" },
});

var builtin_class_custom_generator_map = std.StaticStringMap(BuiltinClassGenerator).initComptime(.{
    .{ "int", &generateBuiltinClassInt },
    .{ "float", &generateBuiltinClassFloat },
    .{ "Nil", &generateBuiltinClassIgnore },
    .{ "bool", &generateBuiltinClassBool },
});

pub fn generate(
    allocator: Allocator,
    extension_api_reader: anytype,
    output_directory: Dir,
) !void {
    var buffer = try allocator.alloc(u8, api_read_buffer_starting_size);
    defer allocator.free(buffer);

    var total_bytes_read: usize = try extension_api_reader.readAll(buffer);
    while (total_bytes_read >= buffer.len) {
        buffer = try allocator.realloc(buffer, buffer.len * 2);
        total_bytes_read += try extension_api_reader.readAll(buffer[total_bytes_read..]);
    }

    const parsed_api = try std.json.parseFromSlice(
        Api,
        allocator,
        buffer[0..total_bytes_read],
        .{},
    );
    defer parsed_api.deinit();

    // create core library file
    const file = try output_directory.createFile("godot.zig", .{});
    defer file.close();
    const godot_writer = file.writer();

    try generateHeader(allocator, output_directory, parsed_api.value.header);
    try generateGlobalEnums(allocator, output_directory, parsed_api.value.global_enums);
    try generateUtilityFunctions(allocator, output_directory, parsed_api.value.utility_functions);
    try generateBuiltinClasses(allocator, output_directory, godot_writer, parsed_api.value);
    // try writeTypes(gen, writer);

}

// pub fn generateVersionFile(allocator: Allocator, output_directory: Dir) void {
//     const result = try std.process.Child.run(.{
//         .allocator = allocator,
//         .argv = &.{ "godot", "--version" },
//     });
//     const result = try std.process.Child.run(.{});
//     const version_file = try output_directory.createFile("version", .{});
//     defer version_file.close();
//     // version_file.writer();
// }

fn initBuiltinSizeMap(
    allocator: Allocator,
    class_size_configurations: []Api.BuiltinClassSize,
) !std.StringHashMap(usize) {
    var class_size_map = std.StringHashMap(usize).init(allocator);
    errdefer class_size_map.deinit();
    for (class_size_configurations) |configuration| {
        if (std.mem.eql(u8, configuration.build_configuration, build_configuration)) {
            for (configuration.sizes) |size| {
                try class_size_map.put(size.name, @intCast(size.size));
            }
            return class_size_map;
        }
    }
    return error.configuration_not_found;
}

fn generateBuiltinClasses(
    allocator: Allocator,
    output_directory: Dir,
    godot_writer: FileWriter,
    api: Api,
) !void {
    var built_in_size_map = try initBuiltinSizeMap(allocator, api.builtin_class_sizes);
    defer built_in_size_map.deinit();

    try gen_fs.makeDirIfMissing(output_directory, "classes");
    const classes_dir = try output_directory.openDir("classes", .{});

    try gen_fs.makeDirIfMissing(classes_dir, "internal");
    const internal_dir = try classes_dir.openDir("internal", .{});

    for (api.builtin_classes) |class| {
        const handler = if (builtin_class_custom_generator_map.get(class.name)) |handler|
            handler
        else
            &generateBuiltinClass;
        try handler(
            allocator,
            classes_dir,
            internal_dir,
            class,
            godot_writer,
            if (built_in_size_map.get(class.name)) |size| size else 0,
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
    try godot_writer.print("pub const {p} = @import(\"classes/{s}.zig\");\n", .{
        IdFormatter{ .data = class.name },
        class.name,
    });

    const class_name_id = try std.fmt.allocPrint(allocator, "{p}", .{
        IdFormatter{ .data = class.name },
    });
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
        "{s}_" ++ internal_name ++ ".zig",
        .{class.name},
    );
    defer allocator.free(internal_file_name);
    const internal_file = try internals_dir.createFile(internal_file_name, .{});
    defer internal_file.close();
    const internal_file_writer = internal_file.writer();

    // import godot lib into both
    try writer.writeAll("const overloading = @import(\"overloading\");");
    try writer.writeAll("const GD = @import(\"../godot.zig\");\n");
    try internal_file_writer.writeAll("const GD = @import(\"../../godot.zig\");\n");

    // import internal into class file
    try writer.print(
        "const internal = @import(\"" ++ internal_name ++ "/{s}\");\n",
        .{internal_file_name},
    );

    // write class size to internal
    try internal_file_writer.print("pub const size = {d};\n", .{size});

    // write opaque blob to class
    try writer.writeAll(opaque_field_name ++ ": [internal.size]u8,\n");

    // method bindings
    if (class.methods) |methods| {
        try internal_file_writer.writeAll("var " ++ function_bindings_name ++ ": struct {\n");
        for (methods) |func| {
            const func_name_id = try std.fmt.allocPrint(allocator, "{c}", .{
                IdFormatter{ .data = func.name },
            });
            defer allocator.free(func_name_id);

            const return_type_id = try std.fmt.allocPrint(allocator, "{p}", .{
                IdFormatter{ .data = func.return_type },
            });
            defer allocator.free(return_type_id);

            try internal_file_writer.print("    {s}: *fn (", .{func_name_id});
            try writer.print("pub inline fn {s}(", .{func_name_id});

            // add self as first param if non-static
            if (!func.is_static) {
                if (func.is_const) {
                    try writer.print("self: GD.{s}", .{class_name_id});
                    try internal_file_writer.print("self: GD.{s}", .{class_name_id});
                } else {
                    try writer.print("self: * GD.{s}", .{class_name_id});
                    try internal_file_writer.print("self: * GD.{s}", .{class_name_id});
                }
            }

            if (func.arguments) |args| {
                if (!func.is_static) {
                    try writer.writeAll(", ");
                    try internal_file_writer.writeAll(", ");
                }
                try writeFunctionArgs(internal_file_writer, args);
                try writeFunctionArgs(writer, args);
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
                    try writer.print("{s}_", .{IdFormatter{ .data = args[0].name }});
                    for (args[1..]) |arg| {
                        try writer.print(", {s}_", .{IdFormatter{ .data = arg.name }});
                    }
                }

                try writer.writeAll(");\n");
            }
            try writer.writeAll("}\n"); // close function definition
        }
        try internal_file_writer.writeAll("} = undefined;\n");

        { // write constructors

        }
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

fn generateHeader(_: Allocator, output_directory: Dir, header: Api.Header) !void {
    const file = try output_directory.createFile("header.zig", .{});
    defer file.close();
    const writer = file.writer();

    try writer.print(
        \\pub const version = struct {{
        \\    pub const major = {d};
        \\    pub const minor = {d};
        \\    pub const patch = {d};
        \\    pub const status = "{s}";
        \\    pub const build = "{s}";
        \\    pub const full_name = "{s}";
        \\}};
        \\
        \\/// zig version bindings were generated for
        \\pub const generated_zig_version = "{s}";
        \\
    , .{
        header.version_major,
        header.version_minor,
        header.version_patch,
        header.version_status,
        header.version_build,
        header.version_full_name,

        zig_version_string,
    });
}

fn generateUtilityFunctions(
    _: Allocator,
    output_directory: Dir,
    functions: []Api.Function,
) !void {
    const file = try output_directory.createFile("utility_functions.zig", .{});
    defer file.close();
    const writer = file.writer();

    try writer.writeAll("const bindings = struct {\n");
    for (functions) |func| {
        if (func.arguments) |args| {
            try writer.print("    {s}: *fn (", .{func.name});
            try writeFunctionArgs(writer.any(), args);
            try writer.print(") {s},\n", .{func.return_type});
        } else {
            try writer.print("    {s}: *fn () {s},\n", .{ func.name, func.return_type });
        }
    }
    try writer.writeAll("};\n");
}

fn writeFunctionArgs(writer: anytype, args: []Api.Function.Argument) !void {
    try writer.print("{s}_: GD.{p}", .{
        IdFormatter{ .data = args[0].name },
        IdFormatter{ .data = args[0].type },
    });
    for (args[1..]) |arg| {
        try writer.print(", {s}_: GD.{p}", .{
            IdFormatter{ .data = arg.name },
            IdFormatter{ .data = arg.type },
        });
    }
}

fn generateGlobalEnums(
    _: Allocator,
    output_directory: Dir,
    global_enums: []const Api.GlobalEnum,
) !void {
    const file = try output_directory.createFile("global_enums.zig", .{});
    defer file.close();
    const writer = file.writer();

    for (global_enums) |global_enum| {
        if (global_enum.is_bitfield) {
            try writer.print(
                "pub const {p} = enum(i64) {{\n",
                .{IdFormatter{ .data = global_enum.name }},
            );
            const prefix = global_enum_prefix_map.get(global_enum.name);
            for (global_enum.values) |value| {
                try writer.print("    {s} = {d},\n", .{
                    IdFormatter{ .data = withoutPrefix(value.name, prefix) },
                    value.value,
                });
            }
            try writer.writeAll("};\n");
        } else {
            try writer.print(
                "pub const {p} = enum(i64) {{\n",
                .{IdFormatter{ .data = global_enum.name }},
            );
            const prefix = global_enum_prefix_map.get(global_enum.name);
            for (global_enum.values) |value| {
                try writer.print("    {s} = {d},\n", .{
                    IdFormatter{ .data = withoutPrefix(value.name, prefix) },
                    value.value,
                });
            }
            try writer.writeAll("};\n");
        }
    }
}

fn withoutPrefix(bytes: []const u8, prefix: ?[]const u8) []const u8 {
    if (prefix) |p| if (bytes.len > p.len and std.mem.startsWith(u8, bytes, p)) {
        return bytes[p.len..];
    };
    return bytes;
}
