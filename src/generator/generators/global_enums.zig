const std = @import("std");
const enum_gen = @import("enum_generator.zig");
const Api = @import("../Api.zig");
const Dir = std.fs.Dir;
const PrefixMap = std.StaticStringMap([]const u8);

const global_enum_prefix_map = PrefixMap.initComptime(.{
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

pub fn generate(output_directory: Dir, global_enums: []const Api.Enum) !void {
    const file = try output_directory.createFile("global_enums.zig", .{});
    defer file.close();
    const writer = file.writer();

    for (global_enums) |global_enum| {
        if (global_enum.is_bitfield) {
            try enum_gen.writeBitfield(writer, global_enum, global_enum_prefix_map);
        } else {
            try enum_gen.writeEnum(writer, global_enum, global_enum_prefix_map);
        }
    }
}
