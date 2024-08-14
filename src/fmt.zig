const std = @import("std");
const aro = @import("aro");
const case_fmt = @import("case_fmt.zig");
pub usingnamespace case_fmt;
pub usingnamespace std.fmt;

/// Formatter for valid zig ids with a specific case
pub fn fmtId(data: []const u8) IdFormatter {
    return .{ .data = data };
}

pub const IdFormatter = std.fmt.Formatter(formatId);

pub const AroValFormatter = std.fmt.Formatter(formatAroValue);

/// Return bytes without the prefix
pub fn withoutPrefix(bytes: []const u8, prefix: []const u8) []const u8 {
    if (bytes.len > prefix.len and std.mem.startsWith(u8, bytes, prefix)) {
        return bytes[prefix.len..];
    }
    return bytes;
}

pub fn formatId(
    data: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    if (fmt.len > 1 and fmt[0] == '_') {
        try writer.writeByte('_');
        try case_fmt.formatConvertCase(data, fmt[1..], options, writer);
    } else if (!isValidId(data)) {
        try writer.writeAll("@\"");
        try case_fmt.formatConvertCase(data, fmt, options, writer);
        try writer.writeByte('"');
    } else {
        try case_fmt.formatConvertCase(data, fmt, options, writer);
    }
}

pub fn formatAroValue(
    data: struct {
        aro.Value,
        aro.Type,
        *const aro.Compilation,
    },
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    const val, const ty, const comp = data;

    if (ty.is(.bool)) {
        return writer.writeAll(if (val.isZero(comp)) "false" else "true");
    }
    const key = comp.interner.get(val.ref());
    switch (key) {
        .null => return writer.writeAll("null"),
        .int => |r| switch (r) {
            inline else => |x| return writer.print("{d}", .{x}),
        },
        .float => |r| switch (r) {
            .f16 => |x| return writer.print("{d}", .{
                @round(@as(f64, @floatCast(x)) * 1000) / 1000,
            }),
            .f32 => |x| return writer.print("{d}", .{
                @round(@as(f64, @floatCast(x)) * 1000000) / 1000000,
            }),
            inline else => |x| return writer.print("{d}", .{@as(f64, @floatCast(x))}),
        },
        .bytes => |b| return aro.Value.printString(b, ty, comp, writer),
        .complex => @panic("not supported"),
        else => unreachable, // not a value
    }
}

fn isValidId(bytes: []const u8) bool {
    if (bytes.len == 0) return false;
    switch (bytes[0]) {
        '_', 'a'...'z', 'A'...'Z' => {},
        '0'...'9' => return false,
        else => return false,
    }

    const min_keyword_len, const max_keyword_len = comptime max_keyword_len_blk: {
        var max_keyword_len = 0;
        var min_keyword_len = std.math.maxInt(usize);
        for (std.zig.Token.keywords.keys()) |keyword| {
            if (keyword.len > max_keyword_len) {
                max_keyword_len = keyword.len;
            }
            if (keyword.len < min_keyword_len) {
                min_keyword_len = keyword.len;
            }
        }
        break :max_keyword_len_blk .{ min_keyword_len, max_keyword_len };
    };

    if (bytes.len <= max_keyword_len and bytes.len >= min_keyword_len) {
        var buffer: [max_keyword_len]u8 = undefined;
        for (bytes, 0..) |c, i| switch (c) {
            'A'...'Z' => buffer[i] = c | 0b00100000,
            '_', 'a'...'z', '0'...'9' => buffer[i] = c,
            else => return false,
        };
        return std.zig.Token.keywords.get(buffer[0..bytes.len]) == null;
    } else {
        for (bytes[1..]) |c| switch (c) {
            '_', 'a'...'z', 'A'...'Z', '0'...'9' => {},
            else => return false,
        };
    }

    return true;
}
