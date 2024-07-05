const Api = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;
// 8mb should be large enough for the whole extension_api.json file
const api_read_buffer_starting_size = 1024 * 1024 * 8;

header: Header,
builtin_class_sizes: []BuiltinClassSize,
builtin_class_member_offsets: []BuiltinClassMemberOffset,
global_enums: []Enum,
global_constants: []GlobalConstant,
utility_functions: []Function,
builtin_classes: []BuiltinClass,
classes: []Class,
singletons: []Singleton,
native_structures: []NativeStructure,

const string = []const u8;
const int = i64;

pub const Header = struct {
    version_major: int,
    version_minor: int,
    version_patch: int,
    version_status: string,
    version_build: string,
    version_full_name: string,
};

pub const BuiltinClassSize = struct {
    build_configuration: string,
    sizes: []Value,
    pub const Value = struct {
        name: string,
        size: int,
    };
};

pub const BuiltinClassMemberOffset = struct {
    build_configuration: string,
    classes: []@This().Class,
    pub const Class = struct {
        name: string,
        members: []Member,
        pub const Member = struct {
            member: string,
            offset: int,
            meta: string,
        };
    };
};

pub const Enum = struct {
    name: string,
    is_bitfield: bool = false, // only used for global enum
    values: []Value,
    pub const Value = struct {
        name: string,
        value: int,
    };
};

pub const GlobalConstant = struct {
    name: string,
    value: i64,
    is_bitfield: bool,
};

pub const Function = struct {
    hash: u64,
    name: string,
    return_type: string = "void",
    arguments: ?[]Argument = null,
    category: ?string = null, // only for utility functions
    is_vararg: bool,
    is_const: bool = true, // only for methods in BuiltinClass
    is_static: bool = true, // only for methods

    pub const Argument = struct {
        name: string,
        type: string,
        default_value: ?string = null,
    };
};

pub const Method = struct {
    name: string,
    is_const: bool,
    is_static: bool,
    is_vararg: bool,
    is_virtual: bool,
    hash: u64 = 0,
    hash_compatibility: ?[]u64 = null,
    return_value: ?ReturnValue = null,
    arguments: ?[]Argument = null,

    pub const Argument = struct {
        name: string,
        type: string,
        meta: string = "",
        default_value: string = "",
    };
    pub const ReturnValue = struct {
        type: string,
        meta: string = "",
        default_value: string = "",
    };
};

pub const BuiltinClass = struct {
    name: string,
    indexing_return_type: string = "",
    is_keyed: bool,
    members: ?[]Member = null,
    constants: ?[]Constant = null,
    enums: ?[]Enum = null,
    operators: []Operator,
    methods: ?[]Function = null,
    constructors: []Constructor,
    has_destructor: bool,

    pub const Member = struct {
        name: string,
        type: string,
    };

    pub const Constant = struct {
        name: string,
        type: string,
        value: string,
    };

    pub const Operator = struct {
        name: string,
        right_type: string = "",
        return_type: string,
    };

    pub const Constructor = struct {
        index: int,
        arguments: ?[]Function.Argument = null,
    };
};

pub const Class = struct {
    name: string,
    is_refcounted: bool,
    is_instantiable: bool,
    inherits: string = "",
    api_type: string,
    constants: ?[]struct {
        name: string,
        value: int,
    } = null,
    enums: ?[]struct {
        name: string,
        is_bitfield: bool,
        values: []struct {
            name: string,
            value: int,
        },
    } = null,
    methods: ?[]Method = null,
    signals: ?[]struct {
        name: string,
        arguments: ?[]struct {
            name: string,
            type: string,
        } = null,
    } = null,
    properties: ?[]struct {
        type: string,
        name: string,
        setter: string = "",
        getter: string,
        index: int = -1,
    } = null,
};

pub const Singleton = struct {
    name: string,
    type: string,
};

pub const NativeStructure = struct {
    name: string,
    format: string,
};

pub fn parse(allocator: Allocator, api_reader: anytype) !ParsedApi {
    var buffer = try allocator.alloc(u8, api_read_buffer_starting_size);

    var total_bytes_read: usize = try api_reader.readAll(buffer);
    while (total_bytes_read >= buffer.len) {
        buffer = try allocator.realloc(buffer, buffer.len * 2);
        total_bytes_read += try api_reader.readAll(buffer[total_bytes_read..]);
    }

    return .{
        .allocator = allocator,
        .json = try std.json.parseFromSlice(
            Api,
            allocator,
            buffer[0..total_bytes_read],
            .{},
        ),
        .buffer = buffer,
    };
}

const ParsedApi = struct {
    allocator: Allocator,
    json: std.json.Parsed(Api),
    buffer: []const u8,
    pub fn deinit(self: @This()) void {
        self.allocator.free(self.buffer);
        self.json.deinit();
    }
};
