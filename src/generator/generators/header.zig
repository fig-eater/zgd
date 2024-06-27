const std = @import("std");
const Api = @import("../Api.zig");
const Dir = std.fs.Dir;

pub fn generate(output_directory: Dir, header: Api.Header) !void {
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

        @import("builtin").zig_version_string,
    });
}
