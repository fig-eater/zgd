const std = @import("std");
const util = @import("../util.zig");
const aro = @import("aro");
const translate = @import("interface/translator.zig");

const Dir = std.fs.Dir;

pub fn generate(
    allocator: std.mem.Allocator,
    interface_path: []const u8,
    include_dir_path: []const u8,
    output_dir: Dir,
) !void {
    const file = try output_dir.createFile("interface.zig", .{});
    defer file.close();
    const writer = file.writer();

    var comp = aro.Compilation.init(allocator);
    defer comp.deinit();

    { // set langopts
        try comp.addDefaultPragmaHandlers();
        comp.langopts.setEmulatedCompiler(aro.target_util.systemCompiler(comp.target));

        comp.langopts.preserve_comments_in_macros = true;
        comp.langopts.preserve_comments = true;
    }
    _ = include_dir_path;
    // try comp.addSystemIncludeDir(include_dir_path);-
    // try comp.addSystemIncludeDir("/home/frog/dev/zgd/aro/include");
    const source = try comp.addSourceFromPath(interface_path);

    // const builtin_macros = try comp.generateBuiltinMacros(.include_system_defines);
    var preprocessor = try aro.Preprocessor.initDefault(&comp);
    defer preprocessor.deinit();
    // preprocessor.verbose = true;
    _ = try preprocessor.preprocess(source);
    // try preprocessor.preprocessSources(&.{source, builtin_macros}); //

    var tree = try preprocessor.parse();
    defer tree.deinit();
    try tree.dump(.no_color, writer);

    try translate.translate(tree);

    // try tree.dump(.no_color, writer);
    // for (tree.root_decls) |node| {
    //     // tree.dump(config: std.io.tty.Config, writer: anytype)
    //     const tag: aro.Tree.Tag = tree.nodes.items(.tag)[@intFromEnum(node)];
    //     const @"type": aro.Type = tree.nodes.items(.ty)[@intFromEnum(node)];
    //     const data: aro.Tree.Node.Data = tree.nodes.items(.data)[@intFromEnum(node)];

    //     _ = @"type";
    //     _ = tag;
    //     _ = data;

    //     try writer.writeByte('\n');
    // }

    // var preprocessor = try aro.Preprocessor.initDefault(&comp);
    // defer preprocessor.deinit();
    // const toks = try preprocessor.preprocess(source);
    // defer aro.Tree.TokenWithExpansionLocs.free(toks.expansion_locs, allocator);

    {

        // const tree = try preprocessor.parse();
        // try tree.dump(.no_color, file.writer());

        // const parsed_tree = try preprocessor.parse();
        // _ = parsed_tree;

        // const writer = file.writer();
        // try writeVariantEnum(writer);
        // try writeVariantOpEnum(writer);
        // try writeCallErrorTypeEnum(writer);
        // try writeCallErrorStruct(writer);

        // try writeInstanceBindingCallbacks(writer);

        // try writeUtilityFns(writer);
    }
}
