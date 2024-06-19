const std = @import("std");
const heap = std.heap;
const generator = @import("generator.zig");
const Allocator = std.mem.Allocator;
const AnyReader = std.io.AnyReader;

pub fn main() !void {
    // var gpa = heap.GeneralPurposeAllocator(.{}){};
    // defer {
    //     if (gpa.deinit() == .leak) {
    //         std.debug.print("Memory leaked\n", .{});
    //     }
    // }
    // const allocator = gpa.allocator();
    // const args = try std.process.argsAlloc(allocator);
    // defer std.process.argsFree(allocator, args);
    // if (args.len < 3) {
    //     std.debug.print("usage: {s} EXTENSION_API_PATH OUTPUT_PATH\n", .{args[0]});
    //     return;
    // }
    // const input_file = try std.fs.cwd().openFile(args[1], .{});
    // defer input_file.close();

    // try generator.generate(allocator, input_file.reader().any(), args[2]);
    const v = Vector2{ .x = 2.0, .y = 2.0 };
    const r = Rect2{ .position = v, .size = v };
    const vi = Vector2i{ .x = 2, .y = 2 };
    const ri = Rect2i{ .position = vi, .size = vi };
    // init(.{2});
    init({});
    init(r);
    init(ri);
    init(.{ v, v });
    init(.{ 4.0, 4.0, 4.0, 4.0 });
    init(.{ Vector2{ .x = 2.0, .y = 3.0 }, Vector2{ .x = 2.0, .y = 3.0 } });
}

const Vector2 = struct { x: f32, y: f32 };
const Vector2i = struct { x: i32, y: i32 };
const Rect2 = struct { position: Vector2, size: Vector2 };
const Rect2i = struct { position: Vector2i, size: Vector2i };

fn init0() void {
    std.debug.print("0\n", .{});
}

fn init1(a: Rect2) void {
    std.debug.print("1 {any}\n", .{a});
}

fn init2(a: Rect2i) void {
    std.debug.print("2 {any}\n", .{a});
}

fn init3(a: Vector2, b: Vector2) void {
    std.debug.print("3 {any} {any}\n", .{ a, b });
}

fn init4(a: f32, b: f32, c: f32, d: f32) void {
    std.debug.print("4 {d} {d} {d} {d}\n", .{ a, b, c, d });
}
const init = makeOverloaded(.{
    init0, // void
    init1, // from: Rect2
    init2, // from: Rect2i
    init3, // postition: Vector2, size: Vector2
    init4, // x: f32, y: f32, w: f32, h: f32
});

fn makeOverloaded(comptime functions: anytype) fn (args: anytype) OverloadedFnReturnType(functions) {
    comptime {
        const ReturnType = OverloadedFnReturnType(functions);

        // get function entries from the functions touple
        const function_entries = functions_fields: {
            switch (@typeInfo(@TypeOf(functions))) {
                .Struct => |s| if (s.is_tuple) break :functions_fields s.fields,
                else => {},
            }
            @compileError("Expected `functions` to be touple found " ++ @typeName(@TypeOf(functions)));
        };

        // Check for inconsistant function return types, make sure the touple only has functions,
        // and set these function lists
        var void_function: ?usize = null;
        var single_arg_functions: []const usize = &.{};
        var multi_arg_functions: []const usize = &.{};
        for (function_entries, 0..) |entry, i| {
            switch (@typeInfo(entry.type)) {
                .Fn => |func| {
                    if (func.return_type != ReturnType)
                        @compileError("inconsistant function return types, expected " ++
                            @typeName(ReturnType) ++ " found " ++ @typeName(func.return_type));

                    switch (func.params.len) {
                        0 => void_function = i,
                        1 => single_arg_functions = single_arg_functions ++ .{i},
                        else => multi_arg_functions = multi_arg_functions ++ .{i},
                    }
                },
                else => @compileError("Expected `functions` to be touple of functions, found " ++
                    @typeName(entry.type)),
            }
        }

        // check for ambiguous function overloads
        if (function_entries.len > 1) {
            for (function_entries[0 .. function_entries.len - 1], 1..) |entry1, i| {
                for (function_entries[i..]) |entry2| {
                    if (hasSameArgs(entry1.type, entry2.type)) {
                        @compileError("Ambiguous function overload. Function " ++
                            @typeName(entry1.type) ++ " and " ++ @typeName(entry2.type) ++
                            " have same argument types");
                    }
                }
            }
        }

        const MatchingFunctionType = enum { none, single, multiple };

        return struct {
            fn overloaded(args: anytype) ReturnType {
                const func, const matching_type: MatchingFunctionType = comptime is_single_block: {
                    const ArgsType = @TypeOf(args);
                    const args_ti = @typeInfo(ArgsType);
                    if (args_ti == .Void) {
                        if (void_function) |func_idx| {
                            break :is_single_block .{ functions[func_idx], .none };
                        }
                        @compileError("no zero argument function overload");
                    }
                    for (single_arg_functions) |func_idx| {
                        const func_ti = @typeInfo(@TypeOf(functions[func_idx])).Fn;
                        if (isConvertableTo(ArgsType, func_ti.params[0].type.?)) {
                            break :is_single_block .{ functions[func_idx], .single };
                        }
                    }

                    if (args_ti == .Struct) {
                        multi_arg_function_loop: for (multi_arg_functions) |func_idx| {
                            const func_ti = @typeInfo(@TypeOf(functions[func_idx])).Fn;
                            if (func_ti.params.len == args_ti.Struct.fields.len) {
                                for (
                                    args_ti.Struct.fields,
                                    func_ti.params,
                                ) |arg_field, func_param| {
                                    if (!isConvertableTo(arg_field.type, func_param.type.?)) {
                                        continue :multi_arg_function_loop;
                                    }
                                }
                                break :is_single_block .{ functions[func_idx], .multiple };
                            }
                        }
                    }

                    @compileError("no matching function overload for " ++ @typeName(ArgsType));
                };

                switch (matching_type) {
                    .none => return @call(.auto, func, .{}),
                    .single => return @call(.auto, func, .{args}),
                    .multiple => return @call(.auto, func, args),
                }
            }
        }.overloaded;
    }
}

fn hasSameArgs(comptime a: anytype, comptime b: anytype) bool {
    if (a == b) return true;
    const ati = @typeInfo(a);
    const bti = @typeInfo(b);
    if (ati != .Fn or bti != .Fn) @compileError("a and b must be functions");

    if (ati.Fn.params.len != bti.Fn.params.len) return false;

    for (ati.Fn.params, bti.Fn.params) |ap, bp| {
        if (ap.type != bp.type) return false;
    }
    return true;
}

fn OverloadedFnReturnType(comptime functions: anytype) type {
    comptime switch (@typeInfo(@TypeOf(functions))) {
        .Struct => |s| {
            if (s.fields.len <= 0) return noreturn;
            switch (@typeInfo(s.fields[0].type)) {
                .Fn => |f| return if (f.return_type) |rt| rt else void,
                else => return noreturn,
            }
        },
        else => return noreturn,
    };
}

pub fn isConvertableTo(comptime From: type, comptime To: type) bool {
    comptime {
        if (From == To) return true;
        const from_type_info = @typeInfo(From);
        const to_type_info = @typeInfo(To);
        return switch (to_type_info) {
            .ComptimeInt, .ComptimeFloat => unreachable, // this should be handled above From == To
            .Int => |to| switch (from_type_info) {
                .Int => |from| from.bits == to.bits and
                    from.signedness == to.signedness,
                .ComptimeInt => true,
                else => false,
            },
            .Float => |to| switch (from_type_info) {
                .Float => |from| from.bits == to.bits,
                .ComptimeFloat => true,
                else => false,
            },
            else => false,
        };
    }
}

fn makeOverloaded2(comptime ReturnType: type, comptime overload_args: anytype) fn (args: anytype) ReturnType {
    for (overload_args[1]) |tfp| {
        if (@typeInfo(tfp[0]) != .Struct) {
            @compileError("expected struct found " ++ @typeName(tfp[0]));
        }
    }

    return struct {
        fn f(args: anytype) ReturnType {
            const ArgsType = @TypeOf(args);
            const args_type_info = @typeInfo(ArgsType);

            const type_fn_pair, const is_single: bool = comptime type_fn_pair: {
                for (overload_args[0]) |overload_tfp| {
                    if (ArgsType == overload_tfp[0]) {
                        break :type_fn_pair .{ overload_tfp, true };
                    }
                }

                switch (args_type_info) {
                    .Struct => |args_struct_info| {
                        multiple_loop: for (overload_args[1]) |overload_tfp| {
                            const struct_info = @typeInfo(overload_tfp[0]).Struct;
                            if (ArgsType == overload_tfp[0]) {
                                break :type_fn_pair .{ overload_tfp, false };
                            } else if (args_struct_info.fields.len == struct_info.fields.len) {
                                for (args_struct_info.fields, struct_info.fields) |a, b| {
                                    if (!isConvertableTo(a.type, b.type)) {
                                        continue :multiple_loop;
                                    }
                                }
                                break :type_fn_pair .{ overload_tfp, false };
                            }
                        }
                    },
                    else => {},
                }

                @compileError("");
            };

            const call_args = comptime switch (args_type_info) {
                .Void => .{},
                .Struct => if (is_single) .{args} else args,
                else => .{args},
            };

            return @call(.auto, type_fn_pair[1], call_args);
        }
    }.f;
}
