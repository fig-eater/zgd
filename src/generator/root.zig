const std = @import("std");
const generator = @import("generator.zig");
const gen_fs = @import("fs.zig");
const heap = std.heap;
const Allocator = std.mem.Allocator;
const AnyReader = std.io.AnyReader;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            std.debug.print("Memory leaked\n", .{});
        }
    }
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("usage: {s} OUTPUT_PATH\n", .{args[0]});
        return;
    }

    const output_directory_full_path = if (std.fs.path.isAbsolute(args[1]))
        args[1]
    else output_directory_full_path: {
        std.fs.cwd().makeDir(args[1]) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        break :output_directory_full_path try std.fs.cwd().realpathAlloc(allocator, args[1]);
    };
    defer if (output_directory_full_path.ptr != args[1].ptr)
        allocator.free(output_directory_full_path);

    std.fs.makeDirAbsolute(output_directory_full_path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    try generator.generate(
        allocator,
        try std.fs.openDirAbsolute(output_directory_full_path, .{}),
    );
}
