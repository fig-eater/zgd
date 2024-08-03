const std = @import("std");
const gd = @import("../godot_root.zig");
const gdi = gd.interface;
const fmt = @import("../fmt.zig");

pub const InitializerFn = fn (user_data: ?*anyopaque, init_level: gdi.InitializationLevel) void;

/// Initialize bindings and GDextension
pub fn init(
    getProcAddressFn: gdi.InterfaceGetProcAddress,
    class_lib_ptr: gdi.ClassLibraryPtr,
    godot_init_struct: [*c]gdi.Initialization,
    userdata: ?*anyopaque,
    comptime init_deinit_fns: struct {
        initCoreFn: ?InitializerFn = null,
        initServersFn: ?InitializerFn = null,
        initSceneFn: ?InitializerFn = null,
        initEditorFn: ?InitializerFn = null,
        deinitCoreFn: ?InitializerFn = null,
        deinitServersFn: ?InitializerFn = null,
        deinitSceneFn: ?InitializerFn = null,
        deinitEditorFn: ?InitializerFn = null,
    },
) void {
    const InitDeinit = struct {
        pub fn initExtension(
            user_data: ?*anyopaque,
            level: gdi.InitializationLevel,
        ) callconv(.C) void {
            switch (level) {
                gdi.InitializationLevel.core => if (init_deinit_fns.initCoreFn) |func|
                    func(user_data, level),
                gdi.InitializationLevel.servers => if (init_deinit_fns.initServersFn) |func|
                    func(user_data, level),
                gdi.InitializationLevel.scene => if (init_deinit_fns.initSceneFn) |func|
                    func(user_data, level),
                gdi.InitializationLevel.editor => if (init_deinit_fns.initEditorFn) |func|
                    func(user_data, level),
                else => unreachable,
            }
        }

        pub fn deinitExtension(
            user_data: ?*anyopaque,
            level: gdi.InitializationLevel,
        ) callconv(.C) void {
            switch (level) {
                gdi.InitializationLevel.core => if (init_deinit_fns.deinitCoreFn) |func|
                    func(user_data, level),
                gdi.InitializationLevel.servers => if (init_deinit_fns.deinitServersFn) |func|
                    func(user_data, level),
                gdi.InitializationLevel.scene => if (init_deinit_fns.deinitSceneFn) |func|
                    func(user_data, level),
                gdi.InitializationLevel.editor => if (init_deinit_fns.deinitEditorFn) |func|
                    func(user_data, level),
                else => unreachable,
            }
        }
    };

    std.debug.assert(getProcAddressFn != null);
    std.debug.assert(class_lib_ptr != null);
    std.debug.assert(godot_init_struct != null);

    gdi.initBindings(getProcAddressFn);

    godot_init_struct.* = .{
        .initialize = InitDeinit.initExtension,
        .deinitialize = InitDeinit.deinitExtension,
        .userdata = userdata,
        .minimum_initialization_level = gdi.InitializationLevel.core,
    };
}

pub fn initBuiltinClasses() void {
    const a: std.builtin.Type.Enum = @typeInfo(gdi.VariantType).Enum;
    for (a.fields) |field| {
        const val: gdi.VariantType = @field(gdi.VariantType, field.name);
        if (val == .variant_max) continue;
        const constructor: gdi.PtrConstructor = gdi.variantGetPtrConstructor(val, 0);
        _ = constructor; // autofix
    }
}

/// Get an allocator which uses the Godot memory functions
pub fn allocator() std.mem.Allocator {
    const allocator_fns = struct {
        fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
            _ = ctx;
            _ = ptr_align;
            _ = ret_addr;
            return @ptrCast(gdi.memAlloc(len));
        }

        fn resize(ctx: *anyopaque, old_mem: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
            _ = ctx;
            _ = buf_align;
            _ = ret_addr;

            std.debug.assert(old_mem.len != 0);
            if (gdi.memRealloc(old_mem.ptr, new_len)) |new_ptr| {
                old_mem.ptr = new_ptr;
                old_mem.len = new_len;
                return true;
            }
            return false;
        }

        fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
            _ = ctx;
            _ = buf_align;
            _ = ret_addr;
            gdi.memFree(buf.ptr);
        }
    };
    return std.mem.Allocator{
        .ptr = undefined,
        .vtable = std.mem.Allocator.VTable{
            .alloc = &allocator_fns.alloc,
            .resize = &allocator_fns.resize,
            .free = &allocator_fns.free,
        },
    };
}
