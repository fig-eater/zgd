const gd = @This();
const std = @import("std");
const gen = @import("gen");
const gdi = gd.interface;
const fmt = @import("fmt.zig");
pub usingnamespace gen;

pub const InitFn = fn (user_data: ?*anyopaque, init_level: gdi.InitializationLevel) void;

/// Initialize bindings and GDextension
pub fn init(
    getProcAddressFn: gdi.InterfaceGetProcAddress,
    class_lib_ptr: gdi.ClassLibraryPtr,
    godot_init_struct: [*c]gdi.Initialization,
    userdata: ?*anyopaque,
    comptime init_deinit_fns: struct {
        initCoreFn: ?InitFn = null,
        initServersFn: ?InitFn = null,
        initSceneFn: ?InitFn = null,
        initEditorFn: ?InitFn = null,
        deinitCoreFn: ?InitFn = null,
        deinitServersFn: ?InitFn = null,
        deinitSceneFn: ?InitFn = null,
        deinitEditorFn: ?InitFn = null,
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

    // gdi.initBindings(getProcAddressFn);
    initBuiltinClasses();

    godot_init_struct.* = .{
        .initialize = InitDeinit.initExtension,
        .deinitialize = InitDeinit.deinitExtension,
        .userdata = userdata,
        .minimum_initialization_level = gdi.InitializationLevel.core,
    };
}

pub fn initBuiltinClasses() void {
    inline for (comptime std.enums.values(gdi.VariantType)) |t| {
        switch (t) {
            .variant_max, .nil, .bool, .int, .float, .object => {},
            else => {
                const T = VariantType(t);
                for (@typeInfo(T.internal.bindings).Struct.fields) |binding| {
                    const binding_name = gd.StringName.fromZigSlice(binding.name);
                    @field(T.internal.bindings, binding.name) = gdi.variantGetPtrBuiltinMethod(
                        t,
                        &binding_name,
                        @field(T.internal.hashes, binding_name),
                    );
                }
            },
        }
    }
}

fn initUtilityFunctionBindings() void {
    // gdi.variantGetPtrUtilityFunction();
    // gen.utility_functions.bindings;
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

/// Initialize function bindings for GDExtension interface
///
/// `getProcAddress` - function pointer to GDExtensionInterfaceGetProcAddress function
/// provided by extension entry point.
pub fn initInterfaceBindings(getProcAddress: gdi.InterfaceGetProcAddress) void {
    std.debug.assert(getProcAddress != null);
    inline for (@typeInfo(gdi.bindings).Struct.decls) |decl| {
        @field(gdi.bindings, decl.name) = @ptrCast(getProcAddress.?(decl.name));
    }
}

/// Get the type from a VariantType enum value
pub fn VariantType(comptime t: gdi.VariantType) type {
    return comptime ret: {
        switch (t) {
            .variant_max, .nil => {
                @compileError("Invalid type");
            },
            else => {
                const tag_name = @tagName(t);
                var buf: [tag_name.len]u8 = .{0} ** tag_name.len;
                const name = fmt.bufPrint(buf[0..], "{p}", .{fmt.fmtId(tag_name)}) catch
                    unreachable;
                if (!@hasDecl(gd.builtin_classes, name)) {
                    @compileError("Type not found: " ++ name);
                }
                break :ret @field(gd.builtin_classes, name);
            },
        }
    };
}
