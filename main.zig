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
    // const vi = Vector2i{ .x = 2, .y = 2 };
    // const ri = Rect2i{ .position = vi, .size = vi };
    // init(.{2});
    init({});
    init(r);
    // init(ri);
    // init(.{ v, v });
    // init(.{ 4.0, 4.0, 4.0, 4.0 });
    // init(.{ Vector2{ .x = 2.0, .y = 3.0 }, Vector2{ .x = 2.0, .y = 3.0 } });
}

const Vector2 = struct { x: f32, y: f32 };
const Vector2i = struct { x: i32, y: i32 };
const Rect2 = struct { position: Vector2, size: Vector2 };
const Rect2i = struct { position: Vector2i, size: Vector2i };

// const ExpectedArgs = struct {
//     void,
//     Rect2,
//     Rect2i,
// };

// const expected_args = .{
//     .single = .{
//         .{ void, noop },
//         .{ Rect2, noop },
//         .{ Rect2i, noop },
//     },
//     .multiple = .{
//         .{ struct { postition: Vector2, size: Vector2 }, noop },
//         .{ struct { x: f32, y: f32, w: f32, h: f32 }, noop },
//     },
// };

const MultiArgsFn = fn (args: anytype) void;

fn init0() void {
    std.debug.print("0\n", .{});
}

fn init1(a: Rect2) void {
    std.debug.print("0 {any}\n", .{a});
}

fn init2(a: Rect2i) void {
    std.debug.print("0 {any}\n", .{a});
}

fn init3(a: Vector2, b: Vector2) void {
    std.debug.print("0 {any} {any}\n", .{ a, b });
}

fn init4(a: f32, b: f32, c: f32, d: f32) void {
    std.debug.print("0 {d} {d} {d} {d}\n", .{ a, b, c, d });
}

const MultiArgs = struct {
    single: []const TypeFnPair,
    multiple: []const TypeFnPair,
    const TypeFnPair = struct { type, *const anyopaque };
};

const init = makeOverloaded(void, .{
    .single = &.{
        .{ void, &init0 },
        .{ Rect2, &init1 },
        .{ Rect2i, &init2 },
    },
    .multiple = &.{
        .{ struct { postition: Vector2, size: Vector2 }, &init3 },
        .{ struct { x: f32, y: f32, w: f32, h: f32 }, &init4 },
    },
});

fn makeOverloaded(comptime ReturnType: type, comptime overload_args: MultiArgs) fn (args: anytype) ReturnType {
    for (overload_args.multiple) |tfp| {
        if (@typeInfo(tfp[0]) != .Struct) {
            @compileError("expected struct found " ++ @typeName(tfp[0]));
        }
    }

    return struct {
        fn f(args: anytype) ReturnType {
            const ArgsType = @TypeOf(args);
            const args_type_info = @typeInfo(ArgsType);

            const type_fn_pair, const is_single: bool = comptime type_fn_pair: {
                for (overload_args.single) |overload_tfp| {
                    if (ArgsType == overload_tfp[0]) {
                        break :type_fn_pair .{ overload_tfp, true };
                    }
                }

                switch (args_type_info) {
                    .Struct => |args_struct_info| {
                        multiple_loop: for (overload_args.multiple) |overload_tfp| {
                            const struct_info = @typeInfo(overload_tfp[0]).Struct;
                            if (ArgsType == overload_tfp[0]) {
                                break :type_fn_pair overload_tfp;
                            } else if (args_struct_info.fields.len == struct_info.fields.len) {
                                for (args_struct_info.fields, struct_info.fields) |a, b| {
                                    if (!convertableTo(a.type, b.type)) {
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

            if (is_single) {} else {}

            const call_args, const params: []const std.builtin.Type.Fn.Param = comptime switch (args_type_info) {
                .Void => .{ .{}, &.{} },
                .Struct => blk: {
                    var params: []const std.builtin.Type.Fn.Param = &.{};

                    for (@typeInfo(type_fn_pair[0]).Struct.fields) |arg| {
                        params = params ++ std.builtin.Type.Fn.Param{
                            .is_generic = false,
                            .is_noalias = true,
                            .type = arg.type,
                        };
                    }

                    break :blk .{ args, params };
                },
                else => .{ .{args}, &.{std.builtin.Type.Fn.Param{
                    .is_generic = false,
                    .is_noalias = true,
                    .type = ArgsType,
                }} },
            };

            const FnType = @Type(std.builtin.Type{ .Fn = .{
                .calling_convention = .Unspecified,
                .is_generic = false,
                .is_var_args = false,
                .params = params,
                .return_type = ReturnType,
            } });

            return @call(.auto, @as(*const FnType, @ptrCast(type_fn_pair[1])), call_args);

            // if (ReturnType == void) {
            //     @call(.auto, type_fn_pair[1], args);
            // } else {
            //     return @call(.auto, type_fn_pair[1], args);
            // }
        }
    }.f;
}

fn init2222(args: anytype) void {
    const expected_args_info = comptime switch (@typeInfo(MultiArgs)) {
        .Struct => |s| s,
        else => @compileError("Expected struct"),
    };
    // const args_type_info = @typeInfo(@TypeOf(args));
    const T = comptime set_t: {
        for (expected_args_info.fields) |expected_arg| {
            if (@TypeOf(args) == expected_arg.type) {
                break :set_t expected_arg.type;
            }
        }

        for (expected_args_info.fields) |expected_arg| {
            if (equivalentTypes(@TypeOf(args), expected_arg.type)) {
                break :set_t expected_arg.type;
            }
        }

        var expected_types: []const u8 = "";
        for (expected_args_info.fields) |f| {
            expected_types = expected_types ++ @typeName(f.type) ++ " ";
        }

        @compileError("found: " ++ @typeName(@TypeOf(args)) ++ "\nexpected: " ++ expected_types);
    };
    _ = T;
    // switch (@typeInfo(@TypeOf(args))) {
    //     .Struct => |s| {
    //         // for () |value| {}
    //         for (s.fields) |field| {
    //             field.type;
    //         }
    //         // if (s.is_tuple) {

    //         // } else {}
    //     },
    //     else => @compileError("expected struct or touple"),
    // }

    // std.debug.print("{}\n", .{@TypeOf(args) == @TypeOf(InitArgs[2])});
    // InitArgs[2]{ .from = {} };
    // switch (args) {}
}

pub fn typeString(comptime T: type) []const u8 {
    comptime {
        switch (@typeInfo(T)) {
            else => return @typeName(T),
            // .Array => |t| { },
            .Struct => |s| {
                var ret: []const u8 = "{";
                if (s.fields.len > 0) {
                    ret = ret ++ typeString(s.fields[0].type);
                    for (s.fields[1..]) |f| {
                        ret = ret ++ "," ++ typeString(f.type);
                    }
                }
                ret = ret ++ "}";
                return ret;
            },
            .Optional => {},
            .ErrorUnion => {},
            .ErrorSet => {},
            .Union => {},
            .Fn => {},
            .Opaque => {},
            .Frame => {},
            .AnyFrame => {},
            .EnumLiteral => {},
        }
        return "";
    }
}

pub fn convertableTo(comptime From: type, comptime To: type) bool {
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

pub fn equivalentTypes(comptime A: type, comptime B: type) bool {
    comptime {
        if (A == B) return true;

        const ati = @typeInfo(A);
        const bti = @typeInfo(B);

        switch (bti) {
            .ComptimeInt => return ati == .ComptimeInt,
            .ComptimeFloat => return ati == .ComptimeFloat,
            .Int => |b| {
                switch (ati) {
                    .Int => |a| return a.bits == b.bits and a.signedness == b.signedness,
                    .ComptimeInt => return true,
                    else => return false,
                }
            },
            .Float => |b| {
                switch (ati) {
                    .Float => |a| return a.bits == b.bits,
                    .ComptimeFloat => return true,
                    else => return false,
                }
            },
            else => {},
        }

        if (!std.mem.eql(u8, @tagName(ati), @tagName(bti))) return false;

        switch (ati) {
            .Type, .NoReturn, .Int, .Float, .ComptimeFloat, .ComptimeInt => unreachable,
            .Void, .Bool, .Null, .Undefined => return true,
            .Pointer => |a| return std.meta.eql(a, @field(bti, @tagName(a))),
            .Array => |a| {
                const b = bti.Array;
                return a.len == b.len and
                    a.sentinel == b.sentinel and
                    equivalentTypes(a.child, b.child);
            },
            .Struct => |a| {
                const b = bti.Struct;
                return a.backing_integer == b.backing_integer and
                    a.layout == b.layout and
                    a.fields.len == b.fields.len and
                    field_check_block: {
                    for (a.fields, b.fields) |af, bf| {
                        if (!equivalentTypes(af.type, bf.type)) break :field_check_block false;
                    }
                    break :field_check_block true;
                };
            },
            .Optional => |a| return equivalentTypes(a.child, bti.Optional.child),
            .Union => {
                // a.
            },
            .Fn => {},
            .Opaque => {},
            .Frame => {},
            .AnyFrame => {},
            .Vector => {},
            .EnumLiteral => {},
            .ErrorUnion, .ErrorSet, .Enum => @compileError("unhandled"),
        }
    }
}
