const GD = @import("api/gen/gdextension_interface.zig");
pub fn example_library_init(get_proc_address_fn: GD.GDExtensionInterfaceGetProcAddress, ptr: GD.GDExtensionClassLibraryPtr, init: [*c]GD.GDExtensionInitialization) callconv(.C) GD.GDExtensionBool {
    _ = get_proc_address_fn;
    _ = ptr;
    _ = init;
    // init
}
// pub const GDExtensionInitializationFunction = ?*const fn (GDExtensionInterfaceGetProcAddress, GDExtensionClassLibraryPtr, [*c]GDExtensionInitialization) callconv(.C) GDExtensionBool;
