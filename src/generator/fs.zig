const std = @import("std");

pub fn makeDirAbsoluteIfMissing(path: []const u8) !void {
    std.fs.makeDirAbsolute(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

pub fn makeDirIfMissing(dir: std.fs.Dir, path: []const u8) !void {
    dir.makeDir(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}
