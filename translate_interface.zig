const std = @import("std");
const Allocator = std.mem.Allocator;
fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            gpa.detectLeaks();
        }
    }
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        return error.InvalidArgs;
    }
    const file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();
    const stat = try file.stat();
    _ = stat; // autofix
    // file.reada
    // stat.size;
}

const Preprocessor = struct {
    fn preprocess(allocator: Allocator, buf: []const u8) !void {
        const define_map = std.StringHashMap([]const u8).init(allocator);
        _ = define_map; // autofix
        for (buf, 0..) |c, i| {
            switch (c) {
                ' ', '\t' => {},
                '\n' => {},
                '#' => {
                    const directives = .{
                        "define",
                        "undef",
                        "include",
                        "ifdef",
                        "ifndef",
                        "if",
                        "else",
                        "endif",
                    };
                    for (directives) |directive| {
                        if (std.mem.eql(u8, buf[i..directive.len], directive)) {}
                    }
                },
            }
        }
    }

    const define = struct {
        label: []const u8,
        def: []const u8,
    };

    const undef = struct {
        label: []const u8,
    };

    const include = struct {
        path: []const u8,
    };

    const ifdef = struct {
        path: []const u8,
    };
};
