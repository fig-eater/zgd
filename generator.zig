const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const io = std.io;
const Api = @import("extension_api.zig");
const AnyReader = std.io.AnyReader;

// 8mb should be large enough for the whole extension_api.json file
const api_read_buffer_starting_size = 1024; //* 1024 * 8;

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

const build_configuraiton = "float_32";

pub fn generate(allocator: Allocator, extension_api_reader: AnyReader, output_directory: []u8) !void {
    var buffer = try allocator.alloc(u8, api_read_buffer_starting_size);
    defer allocator.free(buffer);

    var total_bytes_read: usize = try extension_api_reader.readAll(buffer);
    while (total_bytes_read >= buffer.len) {
        buffer = try allocator.realloc(buffer, buffer.len * 2);
        total_bytes_read += try extension_api_reader.readAll(buffer[total_bytes_read..]);
    }

    const parsed_api = try std.json.parseFromSlice(Api, allocator, buffer[0..total_bytes_read], .{});
    defer parsed_api.deinit();

    try makeDirIfMissing(output_directory);

    try generateHeader(allocator, output_directory, parsed_api.value.header);
    try generateGlobalEnums(allocator, output_directory, parsed_api.value.global_enums);
    try generateUtilityFunctions(allocator, output_directory, parsed_api.value.utility_functions);
    try generateBuiltinClasses(allocator, output_directory, parsed_api.value);
    // try writeTypes(gen, writer);
}

fn initBuiltinSizeMap(allocator: Allocator, class_size_configurations: []Api.BuiltinClassSize) !std.StringHashMap(usize) {
    var class_size_map = std.StringHashMap(usize).init(allocator);
    errdefer class_size_map.deinit();
    for (class_size_configurations) |configuration| {
        if (std.mem.eql(u8, configuration.build_configuration, build_configuraiton)) {
            for (configuration.sizes) |size| {
                try class_size_map.put(size.name, @intCast(size.size));
            }
            return class_size_map;
        }
    }
    return error.configuration_not_found;
}

fn generateBuiltinClasses(allocator: Allocator, output_directory: []const u8, api: Api) !void {
    var built_in_size_map = try initBuiltinSizeMap(allocator, api.builtin_class_sizes);
    defer built_in_size_map.deinit();

    const class_directory_path = try std.fs.path.join(allocator, &.{ output_directory, "classes" });
    defer allocator.free(class_directory_path);

    try makeDirIfMissing(class_directory_path);

    const class_binding_directory_path = try std.fs.path.join(allocator, &.{ class_directory_path, "bindings" });
    defer allocator.free(class_binding_directory_path);

    try makeDirIfMissing(class_binding_directory_path);

    for (api.builtin_classes) |class| {
        try generateBuiltinClass(allocator, class_directory_path, class_binding_directory_path, class, if (built_in_size_map.get(class.name)) |size| size else 0);
    }
}

fn generateBuiltinClass(allocator: Allocator, output_directory: []const u8, bindings_directory: []const u8, class: Api.BuiltinClass, size: usize) !void {
    const file_name = try std.fmt.allocPrint(allocator, "{s}.zig", .{class.name});
    defer allocator.free(file_name);
    const file_path = try std.fs.path.join(allocator, &.{ output_directory, file_name });
    defer allocator.free(file_path);
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    const writer = file.writer();

    try writer.print("pub const size = {d};\n", .{size});

    // method bindings
    if (class.methods) |methods| {
        const bindings_file_name = try std.fmt.allocPrint(allocator, "{s}_bindings.zig", .{class.name});
        defer allocator.free(bindings_file_name);
        const bindings_file_path = try std.fs.path.join(allocator, &.{ bindings_directory, bindings_file_name });
        defer allocator.free(bindings_file_path);
        const bindings_file = try std.fs.cwd().createFile(bindings_file_path, .{});
        defer bindings_file.close();
        const bindings_writer = bindings_file.writer();

        _ = try bindings_writer.write("var function_bindings: struct {\n");
        for (methods) |func| {
            try bindings_writer.print("    {s}: *fn (", .{func.name});
            try writer.print("pub inline fn {s}(", .{func.name});
            if (!func.is_static) {
                if (func.is_const) {
                    try writer.print("self: {s}", .{class.name});
                } else {
                    try writer.print("self: * {s}", .{class.name});
                }
            }

            if (func.arguments) |args| {
                if (!func.is_static) _ = try writer.write(", ");

                try writeFunctionArgs(bindings_writer, args);
                try bindings_writer.print(") {s},\n", .{func.return_type});

                try writeFunctionArgs(writer, args);
                try writer.print(") {s} {{\n", .{func.return_type});
            } else {
                try bindings_writer.print("    {s}: *fn () {s},\n", .{ func.name, func.return_type });
            }
        }
        _ = try bindings_writer.write("} = undefined;\n");
        _ = try writer.write("}\n");
    }
}

fn generateHeader(allocator: Allocator, output_directory: []u8, header: Api.Header) !void {
    const file_path = try std.fs.path.join(allocator, &.{ output_directory, "header.zig" });
    defer allocator.free(file_path);
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    const writer = file.writer();

    try writer.print(
        \\pub const version = struct {{
        \\    const major = {d};
        \\    const minor = {d};
        \\    const patch = {d};
        \\    const status = "{s}";
        \\    const build = "{s}";
        \\    const full_name = "{s}";
        \\}};
        \\
    , .{
        header.version_major,
        header.version_minor,
        header.version_patch,
        header.version_status,
        header.version_build,
        header.version_full_name,
    });
}

fn generateUtilityFunctions(
    allocator: Allocator,
    output_directory: []u8,
    functions: []Api.Function,
) !void {
    const file_path = try std.fs.path.join(allocator, &.{ output_directory, "utility_functions.zig" });
    defer allocator.free(file_path);
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    const writer = file.writer();

    _ = try writer.write("const bindings = struct {\n");
    for (functions) |func| {
        if (func.arguments) |args| {
            try writer.print("    {s}: *fn (", .{func.name});
            try writeFunctionArgs(writer.any(), args);
            try writer.print(") {s},\n", .{func.return_type});
        } else {
            try writer.print("    {s}: *fn () {s},\n", .{ func.name, func.return_type });
        }
    }
    _ = try writer.write("};\n");
}

fn writeFunctionArgs(writer: anytype, args: []Api.Function.Argument) !void {
    try writer.print("{s}: {s}", .{ args[0].name, args[0].type });
    for (args[1..]) |arg| {
        try writer.print(", {s}: {s}", .{ arg.name, arg.type });
    }
}

fn generateGlobalEnums(
    allocator: Allocator,
    output_directory: []u8,
    global_enums: []const Api.GlobalEnum,
) !void {
    const file_path = try std.fs.path.join(allocator, &.{ output_directory, "global_enums.zig" });
    defer allocator.free(file_path);
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    const writer = file.writer();

    for (global_enums) |global_enum| {
        if (global_enum.is_bitfield) {
            const enum_label = try getLabel(toTitleCase, allocator, global_enum.name, null);
            try writer.print("pub const {s} = enum(i64) {{\n", .{enum_label});
            allocator.free(enum_label);
            const prefix = global_enum_prefix_map.get(global_enum.name);
            for (global_enum.values) |value| {
                const label = try getLabel(toSnakeCase, allocator, value.name, prefix);
                try writer.print("    {s} = {d},\n", .{ label, value.value });
                allocator.free(label);
            }
            _ = try writer.write("};\n");
        } else {
            const enum_label = try getLabel(toTitleCase, allocator, global_enum.name, null);
            try writer.print("pub const {s} = enum(i64) {{\n", .{enum_label});
            allocator.free(enum_label);
            const prefix = global_enum_prefix_map.get(global_enum.name);
            for (global_enum.values) |value| {
                const label = try getLabel(toSnakeCase, allocator, value.name, prefix);
                try writer.print("    {s} = {d},\n", .{ label, value.value });
                allocator.free(label);
            }
            _ = try writer.write("};\n");
        }
    }
}

fn getLabel(
    comptime converter: StringConverter,
    allocator: Allocator,
    text: []const u8,
    remove_prefix: ?[]const u8,
) ![]const u8 {
    var label: []const u8 = text;
    if (remove_prefix) |p| if (text.len > p.len and std.mem.startsWith(u8, text, p)) {
        label = text[p.len..];
    };

    label = try converter(allocator, label);
    if (!std.zig.isValidId(label)) {
        const new_label = try allocator.alloc(u8, label.len + 3);
        new_label[0] = '@';
        new_label[1] = '"';
        std.mem.copyForwards(u8, new_label[2..], label);
        new_label[new_label.len - 1] = '"';
        allocator.free(label);
        return new_label;
    }
    return label;
}

const StringConverter = fn (Allocator, []const u8) anyerror![]const u8;

fn toSnakeCase(allocator: Allocator, string: []const u8) ![]u8 {
    const PrevCharType = packed struct(u2) {
        lowercase: bool = false,
        gap: bool = false,
    };
    var prevchar: PrevCharType = .{};
    var output_idx: usize = 0;
    const output = try allocator.alloc(u8, string.len * 2);
    errdefer allocator.free(output);
    for (string) |c| {
        switch (c) {
            'A'...'Z' => {
                if (prevchar.lowercase or prevchar.gap) {
                    output[output_idx] = '_';
                    output_idx += 1;
                }
                prevchar = .{};
                output[output_idx] = c | 0b00100000;
                output_idx += 1;
            },
            '_', '-', '.' => prevchar = .{ .gap = true },
            else => if (std.ascii.isWhitespace(c)) {
                prevchar = .{ .gap = true };
            } else {
                if (prevchar.gap) {
                    output[output_idx] = '_';
                    output_idx += 1;
                }
                prevchar = .{ .lowercase = true };
                output[output_idx] = c;
                output_idx += 1;
            },
        }
    }
    return allocator.realloc(output, output_idx);
}

fn toCamelCase(allocator: Allocator, string: []const u8) ![]u8 {
    var gap: bool = false;
    const output = try allocator.alloc(u8, string.len);
    errdefer allocator.free(output);
    var output_idx: usize = 0;
    for (string) |c| {
        switch (c) {
            'a'...'z' => {
                output[output_idx] = if (gap) c & 0b11011111 else c;
                output_idx += 1;
                gap = false;
            },
            '_', '-', '.' => gap = true,
            else => if (std.ascii.isWhitespace(c)) {
                gap = true;
            } else {
                output[output_idx] = c;
                output_idx += 1;
                gap = false;
            },
        }
    }
    return allocator.realloc(output, output_idx);
}

fn toTitleCase(allocator: Allocator, text: []const u8) ![]u8 {
    const camel_case_text = try toCamelCase(allocator, text);
    camel_case_text[0] = std.ascii.toUpper(camel_case_text[0]);
    return camel_case_text;
}

fn makeDirIfMissing(path: []const u8) !void {
    std.fs.cwd().makeDir(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}
