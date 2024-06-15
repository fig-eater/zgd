const std = @import("std");
const heap = std.heap;
const generator = @import("generator.zig");
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
    const input_file = try std.fs.cwd().openFile(args[1], .{});
    defer input_file.close();
    // const output_directory = try std.fs.cwd().createFile(args[2], .{});
    // defer output_directory.close();
    try generator.generate(allocator, input_file.reader().any(), args[2]);
}
