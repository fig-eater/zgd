const std = @import("std");
const Allocator = std.mem.Allocator;
const gd = @import("../gen_root.zig");

/// Create a StringName from a slice
pub fn fromZigSlice(text: []const u8) gd.StringName {
    var sn: gd.StringName = undefined;
    gd.stringNameNewWithUtf8CharsAndLen(&sn, text.ptr, text.len);
    return sn;
}

/// Create a string from a zero-terminated slice
pub fn fromZigSliceZ(text: [:0]const u8) gd.StringName {
    var sn: gd.StringName = undefined;
    gd.stringNameNewWithUtf8Chars(&sn, text.ptr);
    return sn;
}
