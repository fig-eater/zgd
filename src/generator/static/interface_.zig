pub const VariantType = enum(c_int) {
    nil,

    //  atomic types
    bool,
    int,
    float,
    string,

    // math types
    vector2,
    vector2i,
    rect2,
    rect2i,
    vector3,
    vector3i,
    transform2d,
    vector4,
    vector4i,
    plane,
    quaternion,
    aabb,
    basis,
    transform3d,
    projection,

    // misc types
    color,
    string_name,
    node_path,
    rid,
    object,
    callable,
    signal,
    dictionary,
    array,

    // typed arrays
    packed_byte_array,
    packed_int32_array,
    packed_int64_array,
    packed_float32_array,
    packed_float64_array,
    packed_string_array,
    packed_vector2_array,
    packed_vector3_array,
    packed_color_array,
    packed_vector4_array,
};

pub const VariantOperator = enum(c_int) {
    // comparison
    equal,
    not_equal,
    less,
    less_equal,
    greater,
    greater_equal,

    // mathematic
    add,
    subtract,
    multiply,
    divide,
    negate,
    positive,
    module,
    power,

    // bitwise
    shift_left,
    shift_right,
    bit_and,
    bit_or,
    bit_xor,
    bit_negate,

    // logic
    @"and",
    @"or",
    xor,
    not,

    // containment
    in,
};

// In this API there are multiple functions which expect the caller to pass a pointer
// on return value as parameter.
// In order to make it clear if the caller should initialize the return value or not
// we have two flavor of types:
// - `GDExtensionXXXPtr` for pointer on an initialized value
// - `GDExtensionUninitializedXXXPtr` for pointer on uninitialized value
//
// Notes:
// - Not respecting those requirements can seems harmless, but will lead to unexpected
//   segfault or memory leak (for instance with a specific compiler/OS, or when two
//   native extensions start doing ptrcall on each other).
// - Initialization must be done with the function pointer returned by `variant_get_ptr_constructor`,
//   zero-initializing the variable should not be considered a valid initialization method here !
// - Some types have no destructor (see `extension_api.json`'s `has_destructor` field), for
//   them it is always safe to skip the constructor for the return value if you are in a hurry ;-)

pub const VariantPtr = *anyopaque;
pub const ConstVariantPtr = *const anyopaque;
pub const UninitializedVariantPtr = *anyopaque;
pub const StringNamePtr = *anyopaque;
pub const ConstStringNamePtr = *const anyopaque;
pub const UninitializedStringNamePtr = *anyopaque;
pub const StringPtr = *anyopaque;
pub const ConstStringPtr = *const anyopaque;
pub const UninitializedStringPtr = *anyopaque;
pub const ObjectPtr = *anyopaque;
pub const ConstObjectPtr = *const anyopaque;
pub const UninitializedObjectPtr = *anyopaque;
pub const TypePtr = *anyopaque;
pub const ConstTypePtr = *const anyopaque;
pub const UninitializedTypePtr = *anyopaque;
pub const MethodBindPtr = *const anyopaque;
pub const Int = i64;
pub const Bool = u8;
pub const GDObjectInstanceID = u64;
pub const RefPtr = *anyopaque;
pub const ConstRefPtr = *const anyopaque;

// VARIANT DATA I/O

pub const CallError = struct {
    @"error": CallErrorType,
    argument: i32,
    expected: i32,

    pub const CallErrorType = enum(c_int) {
        ok,
        error_invalid_method,
        error_invalid_argument, // Expected a different variant type.
        error_too_many_arguments, // Expected lower number of arguments.
        error_too_few_arguments, // Expected higher number of arguments.
        error_instance_is_null,
        error_method_not_const, // Used for const call.
    };
};

pub const VariantFromTypeConstructorFunc = ?*const fn (UninitializedVariantPtr, TypePtr) callconv(.C) void;
pub const TypeFromVariantConstructorFunc = ?*const fn (UninitializedTypePtr, VariantPtr) callconv(.C) void;
pub const PtrOperatorEvaluator = ?*const fn (ConstTypePtr, ConstTypePtr, TypePtr) callconv(.C) void;
pub const PtrBuiltInMethod = ?*const fn (TypePtr, [*c]const ConstTypePtr, TypePtr, c_int) callconv(.C) void;
pub const PtrConstructor = ?*const fn (UninitializedTypePtr, [*c]const ConstTypePtr) callconv(.C) void;
pub const PtrDestructor = ?*const fn (TypePtr) callconv(.C) void;
pub const PtrSetter = ?*const fn (TypePtr, ConstTypePtr) callconv(.C) void;
pub const PtrGetter = ?*const fn (ConstTypePtr, TypePtr) callconv(.C) void;
pub const PtrIndexedSetter = ?*const fn (TypePtr, Int, ConstTypePtr) callconv(.C) void;
pub const PtrIndexedGetter = ?*const fn (ConstTypePtr, Int, TypePtr) callconv(.C) void;
pub const PtrKeyedSetter = ?*const fn (TypePtr, ConstTypePtr, ConstTypePtr) callconv(.C) void;
pub const PtrKeyedGetter = ?*const fn (ConstTypePtr, ConstTypePtr, TypePtr) callconv(.C) void;
pub const PtrKeyedChecker = ?*const fn (ConstVariantPtr, ConstVariantPtr) callconv(.C) u32;
pub const PtrUtilityFunction = ?*const fn (TypePtr, [*c]const ConstTypePtr, c_int) callconv(.C) void;
pub const ClassConstructor = ?*const fn (...) callconv(.C) ObjectPtr;
pub const InstanceBindingCreateCallback = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) ?*anyopaque;
pub const InstanceBindingFreeCallback = ?*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) void;
pub const InstanceBindingReferenceCallback = ?*const fn (?*anyopaque, ?*anyopaque, Bool) callconv(.C) Bool;

pub const InstanceBindingCallbacks = struct {
    create_callback: InstanceBindingCreateCallback,
    free_callback: InstanceBindingFreeCallback,
    reference_callback: InstanceBindingReferenceCallback,
};

// EXTENSION CLASSES

pub const ClassInstancePtr = *anyopaque;



Bool (*GDExtensionClassSet)(GDExtensionClassInstancePtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionConstVariantPtr p_value);
Bool (*GDExtensionClassGet)(GDExtensionClassInstancePtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret);
uint64_t (*GDExtensionClassGetRID)(GDExtensionClassInstancePtr p_instance);

