const Api = @import("../Api.zig");
const IdFormatter = @import("../fmt.zig").IdFormatter;

pub fn generate(godot_writer: anytype, global_constants: []const Api.GlobalConstant) !void {
    var id_fmt: IdFormatter = undefined;
    for (global_constants) |global_const| {
        id_fmt.data = global_const.name;
        try godot_writer.print("pub const {s} = {d};\n", .{ id_fmt, global_const.value });
    }
}
