const std = @import("std");
const generator = @import("generator.zig");
const common = @import("common.zig");
const heap = std.heap;
const Allocator = std.mem.Allocator;
const AnyReader = std.io.AnyReader;

const BuildConfigError = error{ InvalidBuildConfigError, CouldNotInferBuildConfig };

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
        printUsage(args[0]);
        std.process.exit(1);
    }

    const build_config_string: ?[]const u8 = if (args.len >= 3) args[2] else null;
    const build_config = getBuildConfig(build_config_string) catch |err| switch (err) {
        BuildConfigError.InvalidBuildConfigError => {
            printUsage(args[0]);
            std.debug.print("Error: Invalid Build Configuration \"{s}\"\n", .{
                build_config_string orelse "",
            });
            std.process.exit(1);
        },
        BuildConfigError.CouldNotInferBuildConfig => {
            printUsage(args[0]);
            std.debug.print("Error: Could not infer build configuration." ++
                " Pass in build configuration as second argument\n", .{});
            std.process.exit(1);
        },
    };

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
        build_config,
    );
}

pub fn printUsage(arg0: []const u8) void {
    std.debug.print("usage: {s} OUTPUT_PATH [" ++ buildConfigUsageString() ++ "]\n", .{arg0});
}

fn buildConfigUsageString() []const u8 {
    comptime {
        var config_string: []const u8 = &.{};
        const configs = @typeInfo(common.BuildConfig).Enum.fields;
        for (configs) |config| {
            config_string = config_string ++ config.name ++ "|";
        }
        return config_string[0 .. config_string.len - 1];
    }
}

fn getBuildConfig(string: ?[]const u8) BuildConfigError!common.BuildConfig {
    if (string) |str| {
        const configs = @typeInfo(common.BuildConfig).Enum.fields;
        inline for (configs) |field| {
            if (std.mem.eql(u8, field.name, str)) {
                return @enumFromInt(field.value);
            }
        }
        return BuildConfigError.InvalidBuildConfigError;
    } else {
        if (@sizeOf(usize) == 4)
            return .float_32
        else if (@sizeOf(usize) == 8)
            return .float_64;
        return BuildConfigError.CouldNotInferBuildConfig;
    }
}
