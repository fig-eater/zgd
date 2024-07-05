const Api = @import("../Api.zig");
const util = @import("../util.zig");

pub fn generate(godot_writer: anytype, structures: []const Api.NativeStructure) !void {
    var id_fmt: util.IdFormatter = undefined;
    for (structures) |structure| {
        id_fmt.data = structure.name;
        try godot_writer.print("pub const {p} = \"{s}\";\n", .{ id_fmt, structure.format });
    }
}
