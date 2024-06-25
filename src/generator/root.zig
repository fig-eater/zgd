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

    if (args.len < 3) {
        std.debug.print("usage: {s} EXTENSION_API_PATH OUTPUT_PATH\n", .{args[0]});
        return;
    }

    const extension_api_full_path = if (std.fs.path.isAbsolute(args[1]))
        args[1]
    else
        try std.fs.cwd().realpathAlloc(allocator, args[1]);
    defer if (extension_api_full_path.ptr != args[1].ptr)
        allocator.free(extension_api_full_path);

    const output_directory_full_path = if (std.fs.path.isAbsolute(args[2]))
        args[1]
    else output_directory_full_path: {
        std.fs.cwd().makeDir(args[2]) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        break :output_directory_full_path try std.fs.cwd().realpathAlloc(allocator, args[2]);
    };
    defer if (output_directory_full_path.ptr != args[2].ptr)
        allocator.free(output_directory_full_path);

    const input_file = try std.fs.openFileAbsolute(extension_api_full_path, .{});
    defer input_file.close();

    std.fs.makeDirAbsolute(output_directory_full_path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    try generator.generate(
        allocator,
        input_file.reader().any(),
        try std.fs.openDirAbsolute(output_directory_full_path, .{}),
    );
}
