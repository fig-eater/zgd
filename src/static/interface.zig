const std = @import("std");
const gd = @import("../godot_root.zig");
const gdi = gd.interface;

/// Initialize function bindings for GDExtension interface
///
/// `getProcAddress` - function pointer to GDExtensionInterfaceGetProcAddress function
/// provided by extension entry point.
pub fn initBindings(getProcAddress: gdi.InterfaceGetProcAddress) void {
    std.debug.assert(getProcAddress != null);
    inline for (@typeInfo(gdi.bindings).Struct.decls) |decl| {
        @field(gdi.bindings, decl.name) = @ptrCast(getProcAddress.?(decl.name));
    }
}
