const Dir = @import("std").fs.Dir;

pub fn makeDirIfMissing(dir: Dir, path: []const u8) !void {
    dir.makeDir(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}
