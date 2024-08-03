const std = @import("std");
const aro = @import("aro");

pub usingnamespace std.fmt;

pub const IdFormatter = std.fmt.Formatter(formatIdSpecial);
pub const AroValFormatter = std.fmt.Formatter(formatAroValue);

/// Return bytes without the prefix
pub fn withoutPrefix(bytes: []const u8, prefix: []const u8) []const u8 {
    if (bytes.len > prefix.len and std.mem.startsWith(u8, bytes, prefix)) {
        return bytes[prefix.len..];
    }
    return bytes;
}

pub fn formatIdSpecial(
    data: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    if (fmt.len == 0) {
        try std.zig.fmtId(data).format("{}", options, writer);
        return;
    }

    const formatFunction = comptime switch (fmt[0]) {
        's' => formatSnakeCase,
        'c' => formatCamelCase,
        'p' => formatPascalCase,
        else => @compileError("expected {}, {s}, {c}, or {p}, found {" ++ fmt ++ "}"),
    };

    const is_valid_id = isValidIdCaseInsensitive(data);

    if (!is_valid_id) try writer.writeAll("@\"");

    try formatFunction(data, fmt, options, writer);

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

pub fn formatSnakeCase(
    data: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    var last_lowercase: bool = false;
    var last_digit: bool = false;
    for (data) |c| {
        switch (c) {
            'A'...'Z' => {
                if (last_lowercase or last_digit) try writer.writeByte('_');
                try writer.writeByte(c | 0b00100000);
                last_lowercase = false;
                last_digit = false;
            },
            'a'...'z' => {
                try writer.writeByte(c);
                last_lowercase = true;
                last_digit = false;
            },
            '0'...'9' => {
                try writer.writeByte(c);
                last_digit = true;
            },
            else => {
                try writer.writeByte(c);
                last_digit = false;
                last_lowercase = false;
            },
        }
    }
}

pub fn formatCamelCase(
    data: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;

    const rest_start = rest_start_block: {
        for (data, 0..) |c, i| {
            switch (c) {
                'A'...'Z' => {
                    try writer.writeByte(c | 0b00100000); // make first character lowercase
                    break :rest_start_block i + 1;
                },
                // skip whitespace or separator
                '_',
                ' ',
                '\t',
                '\n',
                '\r',
                std.ascii.control_code.vt,
                std.ascii.control_code.ff,
                => {},
                else => {
                    try writer.writeByte(c);
                    break :rest_start_block i + 1;
                },
            }
        }
        break :rest_start_block data.len;
    };

    if (rest_start < data.len) {
        var word_start: bool = false;
        for (data[rest_start..]) |c| {
            switch (c) {
                'a'...'z' => {
                    try writer.writeByte(if (word_start) c & 0b11011111 else c);
                    word_start = false;
                },
                // white space or separator
                '_',
                ' ',
                '\t',
                '\n',
                '\r',
                std.ascii.control_code.vt,
                std.ascii.control_code.ff,
                => word_start = true,
                else => {
                    try writer.writeByte(c);
                    word_start = false;
                },
            }
        }
    }
}

pub fn formatPascalCase(
    data: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;

    var word_start: bool = true;
    for (data) |c| {
        switch (c) {
            'a'...'z' => {
                try writer.writeByte(if (word_start) c & 0b11011111 else c);
                word_start = false;
            },
            // white space or separator
            '_',
            ' ',
            '\t',
            '\n',
            '\r',
            std.ascii.control_code.vt,
            std.ascii.control_code.ff,
            => word_start = true,
            else => {
                try writer.writeByte(c);
                word_start = false;
            },
        }
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
