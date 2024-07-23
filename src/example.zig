const gd = @import("godot");

export fn extensionEntry(
    get_proc_address_fn: gd.GDExtensionInterfaceGetProcAddress,
    ptr: gd.GDExtensionClassLibraryPtr,
    init_struct: [*c]gd.GDExtensionInitialization,
) callconv(.C) bool {
    _ = gd.init(get_proc_address_fn, ptr, init_struct, .{});

    return true;
}
