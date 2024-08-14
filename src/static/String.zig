const std = @import("std");
const unicode = std.unicode;
const Allocator = std.mem.Allocator;
const gd = @import("../gen_root.zig");

/// Create a String from a utf8 slice
pub fn fromSlice(text: []const u8) gd.String {
    var str: gd.String = undefined;
    gd.stringNewWithUtf8CharsAndLen(&str, text.ptr, text.len);
    return str;
}

/// Create a String from a zero-terminated utf8 slice
pub fn fromSliceZ(text: [:0]const u8) gd.String {
    var str: gd.String = undefined;
    gd.stringNewWithUtf8Chars(&str, text.ptr);
    return str;
}

/// Convert String to utf8 slice
pub fn toSlice(string: *const gd.String, buf: []u8) []u8 {
    const slice_len = gd.stringToUtf8Chars(string, buf.ptr, @truncate(buf.len));
    return buf[0..slice_len];
}

/// Convert String to an allocated utf8 slice
pub fn toSliceAlloc(self: *const gd.String, allocator: Allocator) ![]u8 {
    const len = gd.stringToUtf8Chars(self, null, 0);
    const buf = try allocator.alloc(u8, len);
    return toSlice(self, buf);
}

/// Appends `other` to the end of `string`
pub const append = gd.stringOperatorPlusEqString;

/// Resizes the underlying string data to the given number of characters.
///
/// Space needs to be allocated for the null terminating character ('\0') which
/// also must be added manually, in order for all string functions to work correctly.
///
/// Warning: This is an error-prone operation - only use it if there's no other
/// efficient way to accomplish your goal.
pub const resize = gd.interface.stringResize;

/// appends the slice `str` to self
pub fn appendSlice(self: *const gd.String, str: [:0]u8) void {
    gd.stringOperatorPlusEqCstr(self, str.ptr);
}

/// Gets a non-const pointer to a utf32 char in the string at index
pub fn getUtf32CharPtrAt(self: *const gd.String, idx: i64) !*u32 {
    return if (gd.stringOperatorIndex(self, idx)) |ptr|
        ptr
    else
        error.IndexOutOfBounds;
}

/// Gets the utf32 char at the index
pub fn getUtf32CharAt(self: *const gd.String, idx: i64) !u32 {
    return if (gd.stringOperatorIndexConst(self, idx)) |ptr|
        ptr.*
    else
        error.IndexOutOfBounds;
}

/// Set the utf32 char at the index
pub fn setUtf32Char(self: *const gd.String, idx: i64, char: u32) !void {
    (try getUtf32CharPtrAt(self, idx)).* = char;
}
