// Options used within this package

const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

pub const Precision = enum { single, double };
const precision_default = Precision.single;

godot_path: ?[]const u8,
dump_path: ?[]const u8,
precision: Precision,
force_bindings_regen: bool,

pub fn init(b: *Build) @This() {
    return @This(){
        .godot_path = b.option(
            []const u8,
            "zgd-godot",
            "Path to godot to use for binding generation. Default uses godot in path",
        ),
        .dump_path = b.option(
            []const u8,
            "zgd-dump-path",
            "Dumped godot api files. Default dumps godot api files into zig cache.",
        ),
        .precision = b.option(
            Precision,
            "zgd-precision",
            "Float precision for bindings. Default: " ++ @tagName(precision_default),
        ) orelse precision_default,
        .force_bindings_regen = b.option(
            bool,
            "zgd-force",
            "Force regeneration of godot bindings. Default: false",
        ) orelse false,
    };
}
