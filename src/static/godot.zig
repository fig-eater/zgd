const std = @import("std");
const gdi = @import("gdextension_interface.zig");
const internal = @import("internal/godot_internal.zig");
const InitializationLevel = gdi.GDExtensionInitializationLevel;
// gdextension initialization
pub const GDExtension = struct {
    getProcAddressFn: gdi.GDExtensionInterfaceGetProcAddress,
    class_lib_ptr: gdi.GDExtensionClassLibraryPtr,
    godot_init_struct: [*c]gdi.GDExtensionInitialization,
    init_deinit_fns: InitDeinitFns,

    pub const InitDeinitFns = struct {
        initCoreFn: ?*InitializerFn = null,
        initServersFn: ?*InitializerFn = null,
        initSceneFn: ?*InitializerFn = null,
        initEditorFn: ?*InitializerFn = null,
        deinitCoreFn: ?*InitializerFn = null,
        deinitServersFn: ?*InitializerFn = null,
        deinitSceneFn: ?*InitializerFn = null,
        deinitEditorFn: ?*InitializerFn = null,
    };

    pub const InitializerFn = fn (user_data: ?*anyopaque, init_level: InitializationLevel) void;

    pub fn initExtension(
        initializer: GDExtension,
        user_data: ?*anyopaque,
        level: InitializationLevel,
    ) callconv(.C) void {
        switch (level) {
            gdi.GDEXTENSION_INITIALIZATION_CORE => if (initializer.initCoreFn) |func|
                func(user_data, level),
            gdi.GDEXTENSION_INITIALIZATION_SERVERS => if (initializer.initServersFn) |func|
                func(user_data, level),
            gdi.GDEXTENSION_INITIALIZATION_SCENE => if (initializer.initSceneFn) |func|
                func(user_data, level),
            gdi.GDEXTENSION_INITIALIZATION_EDITOR => if (initializer.initEditorFn) |func|
                func(user_data, level),
            else => unreachable,
        }
    }

    pub fn deinitExtension(
        initializer: GDExtension,
        user_data: ?*anyopaque,
        level: InitializationLevel,
    ) callconv(.C) void {
        switch (level) {
            gdi.GDEXTENSION_INITIALIZATION_CORE => if (initializer.deinitCoreFn) |func|
                func(user_data, level),
            gdi.GDEXTENSION_INITIALIZATION_SERVERS => if (initializer.deinitServersFn) |func|
                func(user_data, level),
            gdi.GDEXTENSION_INITIALIZATION_SCENE => if (initializer.deinitSceneFn) |func|
                func(user_data, level),
            gdi.GDEXTENSION_INITIALIZATION_EDITOR => if (initializer.deinitEditorFn) |func|
                func(user_data, level),
            else => unreachable,
        }
    }

    pub fn allocator() std.mem.Allocator {}
};

// pub const GDExtensionInitializationFunction = ?*const fn (GDExtensionInterfaceGetProcAddress, GDExtensionClassLibraryPtr, [*c]GDExtensionInitialization) callconv(.C) GDExtensionBool;

/// Initialize bindings and GDextension
pub fn init(
    getProcAddressFn: gdi.GDExtensionInterfaceGetProcAddress,
    class_lib_ptr: gdi.GDExtensionClassLibraryPtr,
    godot_init_struct: [*c]gdi.GDExtensionInitialization,
    init_deinit_fns: GDExtension.InitDeinitFns,
) GDExtension {
    std.debug.assert(getProcAddressFn != null);
    std.debug.assert(class_lib_ptr != null);
    std.debug.assert(godot_init_struct != null);

    // initInterface(getProcAddressFn);
    // internal.

    // godot_init_struct.*.initialize =
    return GDExtension{
        .getProcAddressFn = getProcAddressFn,
        .class_lib_ptr = class_lib_ptr,
        .godot_init_struct = godot_init_struct,
        .init_deinit_fns = init_deinit_fns,
    };
}

// fn initInterface(
//     get_proc_addr_fn: gdi.GDExtensionInterfaceGetProcAddress,
// ) void {
//     const getProcAddr = get_proc_addr_fn.?;
//     const interface_fn_struct: std.builtin.Type.Struct = @typeInfo(@TypeOf(interface_fns)).Struct;
//     std.debug.assert(interface_fn_struct.fields.len == interface_fn_names.len);
//     inline for (interface_fn_names, interface_fn_struct.fields) |fn_name, field| {
//         @field(interface_fns, field.name) = @ptrCast(getProcAddr(fn_name));
//     }
// }

/// Get an allocator which uses the Godot
pub fn allocator() std.mem.Allocator {
    const bindings = @import("internal/godot_internal.zig").bindings;
    const fns = struct {
        fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
            _ = ctx;
            _ = ptr_align;
            _ = ret_addr;
            return @ptrCast(bindings.memAlloc(len));
        }

        fn resize(ctx: *anyopaque, old_mem: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
            _ = ctx;
            _ = buf_align;
            _ = ret_addr;
            std.debug.assert(old_mem.len != 0);
            if (bindings.memRealloc(old_mem.ptr, new_len)) |new_ptr| {
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
            bindings.memFree(buf.ptr);
        }
    };
    return std.mem.Allocator{
        .ptr = undefined,
        .vtable = std.mem.Allocator.VTable{
            .alloc = &fns.alloc,
            .resize = &fns.resize,
            .free = &fns.free,
        },
    };
}
