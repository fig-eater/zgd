const std = @import("std");
const Formatter = std.fmt.Formatter;

/// Formatter that can convert any text into a formatted case
///
/// Format:
/// - {c} formats as camelCase
/// - {k} formats as kebob-case
/// - {p} formats as PascalCase
/// - {s} formats as snake_case
/// - {S} formats as UPPER_SNAKE_CASE
pub const ConvertCaseFormatter = Formatter(formatConvertCase);

/// Creates a formatter that can convert any text into a formatted case
///
/// Format:
/// - {c} formats as camelCase
/// - {k} formats as kebob-case
/// - {p} formats as PascalCase
/// - {s} formats as snake_case
/// - {S} formats as UPPER_SNAKE_CASE
pub fn fmtConvertCase(bytes: []const u8) ConvertCaseFormatter {
    return .{ .data = bytes };
}

/// Comptime function for creating a case formatter function
pub fn FormatCase(
    comptime wordFn: fn (data: []const u8, word_idx: usize, writer: anytype) anyerror!void,
    comptime gap: ?u8,
) fn (
    data: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) anyerror!void {
    return struct {
        fn formatFn(
            data: []const u8,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) anyerror!void {
            _ = fmt;
            _ = options;
            const State = union(enum) {
                init,
                in_word: struct { word_start: usize, last_type: ByteType },
                in_gap,
            };
            var state: State = .init;

            var word_idx: usize = 0;
            var i: usize = 0;
            loop: while (i < data.len) : (i += 1) continue_loop: {
                const c = data[i];
                const byte_type = byteType(c);

                switch (state) {
                    .init => if (byte_type != .gap) {
                        state = .{ .in_word = .{ .word_start = i, .last_type = byte_type } };
                    },
                    .in_gap => if (byte_type != .gap) {
                        if (gap) |g| {
                            try writer.writeByte(g);
                        }
                        state = .{ .in_word = .{ .word_start = i, .last_type = byte_type } };
                    },
                    .in_word => in_word_block: {
                        std.debug.assert(state.in_word.last_type != .gap);

                        switch (byte_type) {
                            .letter_uppercase => switch (state.in_word.last_type) {
                                .digit => {
                                    state.in_word.last_type = byte_type;
                                    i += 1;
                                    while (i < data.len) : (i += 1) {
                                        const c_lookahead = data[i];
                                        const byte_type_lookahead = byteType(c_lookahead);
                                        switch (byte_type_lookahead) {
                                            .letter_lowercase => {
                                                if (state.in_word.last_type == .letter_uppercase) {
                                                    const word = data[state.in_word.word_start..(i - 1)];
                                                    try wordFn(word, word_idx, writer);
                                                    word_idx += 1;
                                                    if (gap) |g| {
                                                        try writer.writeByte(g);
                                                    }
                                                    state.in_word.word_start = i - 1;
                                                }
                                            },
                                            .gap => {
                                                try wordFn(data[state.in_word.word_start..i], word_idx, writer);
                                                word_idx += 1;
                                                state = .in_gap;
                                                break :continue_loop;
                                            },
                                            else => {},
                                        }
                                        state.in_word.last_type = byte_type_lookahead;
                                    }
                                    break :loop;
                                },
                                .letter_lowercase => {
                                    // lowercase to uppercase
                                    try wordFn(data[state.in_word.word_start..i], word_idx, writer);
                                    word_idx += 1;
                                    if (gap) |g| {
                                        try writer.writeByte(g);
                                    }
                                    state.in_word.word_start = i;
                                },
                                .gap => unreachable,
                                else => {},
                            },
                            .letter_lowercase => if (state.in_word.last_type == .letter_uppercase and state.in_word.word_start != i - 1) {
                                try wordFn(data[state.in_word.word_start..(i - 1)], word_idx, writer);
                                word_idx += 1;
                                state.in_word.word_start = i - 1;
                            },
                            .gap => {
                                // end of word
                                // write the word
                                try wordFn(data[state.in_word.word_start..i], word_idx, writer);
                                word_idx += 1;
                                state = .in_gap;
                                break :in_word_block;
                            },
                            else => {},
                        }
                        state.in_word.last_type = byte_type;
                    },
                }
            }

            switch (state) {
                .in_word => |w| {
                    try wordFn(data[w.word_start..], word_idx, writer);
                    word_idx += 1;
                },
                else => {},
            }
        }
    }.formatFn;
}

pub fn formatConvertCase(
    data: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    const formatFunction = comptime format_function_blk: {
        const compile_error_msg = "expected {c}, {k}, {p}, {s}, or {S}, found {" ++ fmt ++ "}";

        if (fmt.len == 0 or fmt.len > 1) {
            @compileError(compile_error_msg);
        }

        break :format_function_blk switch (fmt[0]) {
            // camelCase
            'c' => FormatCase(writeWordCamelCase, null),
            // kebob-case
            'k' => FormatCase(writeWordLowerCase, '-'),
            // PascalCase
            'p' => FormatCase(writeWordPascalCase, null),
            // snake_case
            's' => FormatCase(writeWordLowerCase, '_'),
            // UPPER_SNAKE_CASE
            'S' => FormatCase(writeWordUpperCase, '_'),
            else => @compileError(compile_error_msg),
        };
    };

    try formatFunction(data, fmt, options, writer);
}

const ByteType = enum {
    letter_uppercase,
    letter_lowercase,
    digit,
    gap,
};

inline fn byteType(b: u8) ByteType {
    const vt = std.ascii.control_code.vt;
    const ff = std.ascii.control_code.ff;
    return switch (b) {
        'A'...'Z' => .letter_uppercase,
        'a'...'z' => .letter_lowercase,
        '0'...'9' => .digit,
        // whitespace gap
        '-', '_', ' ', '\t', '\n', '\r', vt, ff => .gap,
        else => .letter_lowercase,
    };
}

fn writeWordCamelCase(data: []const u8, word_idx: usize, writer: anytype) !void {
    if (word_idx == 0)
        try writeWordLowerCase(data, word_idx, writer)
    else
        try writeWordPascalCase(data, word_idx, writer);
}

fn writeWordLowerCase(data: []const u8, _: usize, writer: anytype) !void {
    for (data) |c| {
        try writer.writeByte(std.ascii.toLower(c));
    }
}

fn writeWordUpperCase(data: []const u8, _: usize, writer: anytype) !void {
    for (data) |c| {
        try writer.writeByte(std.ascii.toUpper(c));
    }
}

fn writeWordPascalCase(data: []const u8, _: usize, writer: anytype) !void {
    if (data.len <= 0) return;

    try writer.writeByte(std.ascii.toUpper(data[0]));
    for (data[1..]) |c| {
        try writer.writeByte(std.ascii.toLower(c));
    }
}
