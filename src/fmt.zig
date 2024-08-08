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
    const is_valid_id = isValidIdCaseInsensitive(data);

    if (!is_valid_id) try writer.writeAll("@\"");

    case_fmt.formatConvertCase(data, fmt, options, writer);

    if (!is_valid_id) try writer.writeByte('"');
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

fn isValidIdCaseInsensitive(bytes: []const u8) bool {
    if (!std.zig.isValidId(bytes)) return false;
    const bytes_len = bytes.len;
    const bytes_last = bytes_len - 1;
    check_keyword_block: for (std.zig.Token.keywords.keys()) |keyword| {
        if (keyword.len == bytes_len and
            keyword[0] == (bytes[0] | 0b00100000) and
            keyword[bytes_last] == (bytes[bytes_last] | 0b00100000))
        {
            for (bytes[1..bytes_last], keyword[1..bytes_last]) |data_char, key_char| {
                if ((data_char | 0b00100000) != key_char) {
                    continue :check_keyword_block; // continue to next word
                }
            }
            return false; // matches keyword
        }
    }
    return true;
}
