const std = @import("std");
const generator = @import("generator.zig");
const util = @import("util.zig");
const Api = @import("Api.zig");
const Allocator = std.mem.Allocator;
const AnyReader = std.io.AnyReader;

const BuildConfigError = error{ InvalidBuildConfigError, CouldNotInferBuildConfig };

const ArgIndices = enum {
    exe,
    build_config,
    api_path,
    interface_path,
    include_path,
    output_path,
};
const expected_arg_count = std.meta.fields(ArgIndices).len;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            std.debug.print("Memory leaked\n", .{});
        }
    }
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != expected_arg_count) {
        std.debug.print(
            "Error: Incorrect arg count got {d} expected {d}\n",
            .{ args.len - 1, expected_arg_count - 1 },
        );
        printUsage(getArg(args, .exe));
        std.process.exit(1);
    }

    var output_dir = try getOutputDirectory(getArg(args, .output_path));
    defer output_dir.close();
    const build_config = getBuildConfig(args);

    const api_path = getArg(args, .api_path);
    const api_file = if (std.fs.path.isAbsolute(api_path))
        try std.fs.openFileAbsolute(api_path, .{})
    else
        try std.fs.cwd().openFile(api_path, .{});
    defer api_file.close();
    const parsed_api = try Api.parse(allocator, api_file.reader());
    defer parsed_api.deinit();
    try generator.generate(
        allocator,
        parsed_api.json.value,
        getArg(args, .interface_path),
        getArg(args, .include_path),
        build_config,
        output_dir,
    );
}

pub fn printUsage(arg0: []const u8) void {
    std.debug.print(
        "usage: {s} [" ++ buildConfigUsageString() ++ "] API_PATH INTERFACE_PATH INCLUDE_PATH OUTPUT_PATH\n",
        .{arg0},
    );
}

fn buildConfigUsageString() []const u8 {
    comptime {
        var config_string: []const u8 = &.{};
        const configs = @typeInfo(util.BuildConfig).Enum.fields;
        for (configs) |config| {
            config_string = config_string ++ config.name ++ "|";
        }
        return config_string[0 .. config_string.len - 1];
    }
}

fn getBuildConfig(args: [][:0]u8) util.BuildConfig {
    std.debug.assert(args.len == expected_arg_count);
    const build_config_string = getArg(args, .build_config);
    return std.meta.stringToEnum(util.BuildConfig, build_config_string) orelse {
        printUsage(getArg(args, .exe));
        std.debug.print("Error: Invalid Build Configuration \"{s}\"\n", .{build_config_string});
        std.process.exit(@truncate(@intFromError(BuildConfigError.InvalidBuildConfigError)));
    };
}

fn getOutputDirectory(path: []const u8) !std.fs.Dir {
    if (std.fs.path.isAbsolute(path)) {
        try util.makeDirAbsoluteIfMissing(path);
        return try std.fs.openDirAbsolute(path, .{});
    } else {
        try util.makeDirIfMissing(std.fs.cwd(), path);
        return try std.fs.cwd().openDir(path, .{});
    }
}

fn getArg(args: [][:0]u8, arg: ArgIndices) [:0]u8 {
    return args[@intFromEnum(arg)];
}
