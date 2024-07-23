const gdi = @import("../gdextension_interface.zig");
const interface_fn_names = [_][*c]const u8{
    "get_godot_version",
    "mem_alloc",
    "mem_realloc",
    "mem_free",
    "print_error",
    "print_error_with_message",
    "print_warning",
    "print_warning_with_message",
    "print_script_error",
    "print_script_error_with_message",
    "get_native_struct_size",
    "variant_new_copy",
    "variant_new_nil",
    "variant_destroy",
    "variant_call",
    "variant_call_static",
    "variant_evaluate",
    "variant_set",
    "variant_set_named",
    "variant_set_keyed",
    "variant_set_indexed",
    "variant_get",
    "variant_get_named",
    "variant_get_keyed",
    "variant_get_indexed",
    "variant_iter_init",
    "variant_iter_next",
    "variant_iter_get",
    "variant_hash",
    "variant_recursive_hash",
    "variant_hash_compare",
    "variant_booleanize",
    "variant_duplicate",
    "variant_stringify",
    "variant_get_type",
    "variant_has_method",
    "variant_has_member",
    "variant_has_key",
    "variant_get_type_name",
    "variant_can_convert",
    "variant_can_convert_strict",
    "get_variant_from_type_constructor",
    "get_variant_to_type_constructor",
    "variant_get_ptr_operator_evaluator",
    "variant_get_ptr_builtin_method",
    "variant_get_ptr_constructor",
    "variant_get_ptr_destructor",
    "variant_construct",
    "variant_get_ptr_setter",
    "variant_get_ptr_getter",
    "variant_get_ptr_indexed_setter",
    "variant_get_ptr_indexed_getter",
    "variant_get_ptr_keyed_setter",
    "variant_get_ptr_keyed_getter",
    "variant_get_ptr_keyed_checker",
    "variant_get_constant_value",
    "variant_get_ptr_utility_function",
    "string_new_with_latin1_chars",
    "string_new_with_utf8_chars",
    "string_new_with_utf16_chars",
    "string_new_with_utf32_chars",
    "string_new_with_wide_chars",
    "string_new_with_latin1_chars_and_len",
    "string_new_with_utf8_chars_and_len",
    "string_new_with_utf16_chars_and_len",
    "string_new_with_utf32_chars_and_len",
    "string_new_with_wide_chars_and_len",
    "string_to_latin1_chars",
    "string_to_utf8_chars",
    "string_to_utf16_chars",
    "string_to_utf32_chars",
    "string_to_wide_chars",
    "string_operator_index",
    "string_operator_index_const",
    "string_operator_plus_eq_string",
    "string_operator_plus_eq_char",
    "string_operator_plus_eq_cstr",
    "string_operator_plus_eq_wcstr",
    "string_operator_plus_eq_c32str",
    "string_resize",
    "string_name_new_with_latin1_chars",
    "string_name_new_with_utf8_chars",
    "string_name_new_with_utf8_chars_and_len",
    "xml_parser_open_buffer",
    "file_access_store_buffer",
    "file_access_get_buffer",
    "worker_thread_pool_add_native_group_task",
    "worker_thread_pool_add_native_task",
    "packed_byte_array_operator_index",
    "packed_byte_array_operator_index_const",
    "packed_float32_array_operator_index",
    "packed_float32_array_operator_index_const",
    "packed_float64_array_operator_index",
    "packed_float64_array_operator_index_const",
    "packed_int32_array_operator_index",
    "packed_int32_array_operator_index_const",
    "packed_int64_array_operator_index",
    "packed_int64_array_operator_index_const",
    "packed_string_array_operator_index",
    "packed_string_array_operator_index_const",
    "packed_vector2_array_operator_index",
    "packed_vector2_array_operator_index_const",
    "packed_vector3_array_operator_index",
    "packed_vector3_array_operator_index_const",
    "packed_vector4_array_operator_index",
    "packed_vector4_array_operator_index_const",
    "packed_color_array_operator_index",
    "packed_color_array_operator_index_const",
    "array_operator_index",
    "array_operator_index_const",
    "array_ref",
    "array_set_typed",
    "dictionary_operator_index",
    "dictionary_operator_index_const",
    "object_method_bind_call",
    "object_method_bind_ptrcall",
    "object_destroy",
    "global_get_singleton",
    "object_get_instance_binding",
    "object_set_instance_binding",
    "object_free_instance_binding",
    "object_set_instance",
    "object_get_class_name",
    "object_cast_to",
    "object_get_instance_from_id",
    "object_get_instance_id",
    "object_has_script_method",
    "object_call_script_method",
    "ref_get_object",
    "ref_set_object",
    "script_instance_create",
    "script_instance_create2",
    "script_instance_create3",
    "placeholder_script_instance_create",
    "placeholder_script_instance_update",
    "object_get_script_instance",
    "callable_custom_create",
    "callable_custom_create2",
    "callable_custom_get_userdata",
    "classdb_construct_object",
    "classdb_get_method_bind",
    "classdb_get_class_tag",
    "classdb_register_extension_class",
    "classdb_register_extension_class2",
    "classdb_register_extension_class3",
    "classdb_register_extension_class_method",
    "classdb_register_extension_class_virtual_method",
    "classdb_register_extension_class_integer_constant",
    "classdb_register_extension_class_property",
    "classdb_register_extension_class_property_indexed",
    "classdb_register_extension_class_property_group",
    "classdb_register_extension_class_property_subgroup",
    "classdb_register_extension_class_signal",
    "classdb_unregister_extension_class",
    "get_library_path",
    "editor_add_plugin",
    "editor_remove_plugin",
    "editor_help_load_xml_from_utf8_chars",
    "editor_help_load_xml_from_utf8_chars_and_len",
};

pub var bindings: struct {
    var getGodotVersion: gdi.GDExtensionInterfaceGetGodotVersion = undefined;
    var memAlloc: gdi.GDExtensionInterfaceMemAlloc = undefined;
    var memRealloc: gdi.GDExtensionInterfaceMemRealloc = undefined;
    var memFree: gdi.GDExtensionInterfaceMemFree = undefined;
    var printError: gdi.GDExtensionInterfacePrintError = undefined;
    var printErrorWithMessage: gdi.GDExtensionInterfacePrintErrorWithMessage = undefined;
    var printWarning: gdi.GDExtensionInterfacePrintWarning = undefined;
    var printWarningWithMessage: gdi.GDExtensionInterfacePrintWarningWithMessage = undefined;
    var printScriptError: gdi.GDExtensionInterfacePrintScriptError = undefined;
    var printScriptErrorWithMessage: gdi.GDExtensionInterfacePrintScriptErrorWithMessage = undefined;
    var getNativeStructSize: gdi.GDExtensionInterfaceGetNativeStructSize = undefined;
    var variantNewCopy: gdi.GDExtensionInterfaceVariantNewCopy = undefined;
    var variantNewNil: gdi.GDExtensionInterfaceVariantNewNil = undefined;
    var variantDestroy: gdi.GDExtensionInterfaceVariantDestroy = undefined;
    var variantCall: gdi.GDExtensionInterfaceVariantCall = undefined;
    var variantCallStatic: gdi.GDExtensionInterfaceVariantCallStatic = undefined;
    var variantEvaluate: gdi.GDExtensionInterfaceVariantEvaluate = undefined;
    var variantSet: gdi.GDExtensionInterfaceVariantSet = undefined;
    var variantSetNamed: gdi.GDExtensionInterfaceVariantSetNamed = undefined;
    var variantSetKeyed: gdi.GDExtensionInterfaceVariantSetKeyed = undefined;
    var variantSetIndexed: gdi.GDExtensionInterfaceVariantSetIndexed = undefined;
    var variantGet: gdi.GDExtensionInterfaceVariantGet = undefined;
    var variantGetNamed: gdi.GDExtensionInterfaceVariantGetNamed = undefined;
    var variantGetKeyed: gdi.GDExtensionInterfaceVariantGetKeyed = undefined;
    var variantGetIndexed: gdi.GDExtensionInterfaceVariantGetIndexed = undefined;
    var variantIterInit: gdi.GDExtensionInterfaceVariantIterInit = undefined;
    var variantIterNext: gdi.GDExtensionInterfaceVariantIterNext = undefined;
    var variantIterGet: gdi.GDExtensionInterfaceVariantIterGet = undefined;
    var variantHash: gdi.GDExtensionInterfaceVariantHash = undefined;
    var variantRecursiveHash: gdi.GDExtensionInterfaceVariantRecursiveHash = undefined;
    var variantHashCompare: gdi.GDExtensionInterfaceVariantHashCompare = undefined;
    var variantBooleanize: gdi.GDExtensionInterfaceVariantBooleanize = undefined;
    var variantDuplicate: gdi.GDExtensionInterfaceVariantDuplicate = undefined;
    var variantStringify: gdi.GDExtensionInterfaceVariantStringify = undefined;
    var variantGetType: gdi.GDExtensionInterfaceVariantGetType = undefined;
    var variantHasMethod: gdi.GDExtensionInterfaceVariantHasMethod = undefined;
    var variantHasMember: gdi.GDExtensionInterfaceVariantHasMember = undefined;
    var variantHasKey: gdi.GDExtensionInterfaceVariantHasKey = undefined;
    var variantGetTypeName: gdi.GDExtensionInterfaceVariantGetTypeName = undefined;
    var variantCanConvert: gdi.GDExtensionInterfaceVariantCanConvert = undefined;
    var variantCanConvertStrict: gdi.GDExtensionInterfaceVariantCanConvertStrict = undefined;
    var getVariantFromTypeConstructor: gdi.GDExtensionInterfaceGetVariantFromTypeConstructor = undefined;
    var getVariantToTypeConstructor: gdi.GDExtensionInterfaceGetVariantToTypeConstructor = undefined;
    var variantGetPtrOperatorEvaluator: gdi.GDExtensionInterfaceVariantGetPtrOperatorEvaluator = undefined;
    var variantGetPtrBuiltinMethod: gdi.GDExtensionInterfaceVariantGetPtrBuiltinMethod = undefined;
    var variantGetPtrConstructor: gdi.GDExtensionInterfaceVariantGetPtrConstructor = undefined;
    var variantGetPtrDestructor: gdi.GDExtensionInterfaceVariantGetPtrDestructor = undefined;
    var variantConstruct: gdi.GDExtensionInterfaceVariantConstruct = undefined;
    var variantGetPtrSetter: gdi.GDExtensionInterfaceVariantGetPtrSetter = undefined;
    var variantGetPtrGetter: gdi.GDExtensionInterfaceVariantGetPtrGetter = undefined;
    var variantGetPtrIndexedSetter: gdi.GDExtensionInterfaceVariantGetPtrIndexedSetter = undefined;
    var variantGetPtrIndexedGetter: gdi.GDExtensionInterfaceVariantGetPtrIndexedGetter = undefined;
    var variantGetPtrKeyedSetter: gdi.GDExtensionInterfaceVariantGetPtrKeyedSetter = undefined;
    var variantGetPtrKeyedGetter: gdi.GDExtensionInterfaceVariantGetPtrKeyedGetter = undefined;
    var variantGetPtrKeyedChecker: gdi.GDExtensionInterfaceVariantGetPtrKeyedChecker = undefined;
    var variantGetConstantValue: gdi.GDExtensionInterfaceVariantGetConstantValue = undefined;
    var variantGetPtrUtilityFunction: gdi.GDExtensionInterfaceVariantGetPtrUtilityFunction = undefined;
    var stringNewWithLatin1Chars: gdi.GDExtensionInterfaceStringNewWithLatin1Chars = undefined;
    var stringNewWithUtf8Chars: gdi.GDExtensionInterfaceStringNewWithUtf8Chars = undefined;
    var stringNewWithUtf16Chars: gdi.GDExtensionInterfaceStringNewWithUtf16Chars = undefined;
    var stringNewWithUtf32Chars: gdi.GDExtensionInterfaceStringNewWithUtf32Chars = undefined;
    var stringNewWithWideChars: gdi.GDExtensionInterfaceStringNewWithWideChars = undefined;
    var stringNewWithLatin1CharsAndLen: gdi.GDExtensionInterfaceStringNewWithLatin1CharsAndLen = undefined;
    var stringNewWithUtf8CharsAndLen: gdi.GDExtensionInterfaceStringNewWithUtf8CharsAndLen = undefined;
    var stringNewWithUtf16CharsAndLen: gdi.GDExtensionInterfaceStringNewWithUtf16CharsAndLen = undefined;
    var stringNewWithUtf32CharsAndLen: gdi.GDExtensionInterfaceStringNewWithUtf32CharsAndLen = undefined;
    var stringNewWithWideCharsAndLen: gdi.GDExtensionInterfaceStringNewWithWideCharsAndLen = undefined;
    var stringToLatin1Chars: gdi.GDExtensionInterfaceStringToLatin1Chars = undefined;
    var stringToUtf8Chars: gdi.GDExtensionInterfaceStringToUtf8Chars = undefined;
    var stringToUtf16Chars: gdi.GDExtensionInterfaceStringToUtf16Chars = undefined;
    var stringToUtf32Chars: gdi.GDExtensionInterfaceStringToUtf32Chars = undefined;
    var stringToWideChars: gdi.GDExtensionInterfaceStringToWideChars = undefined;
    var stringOperatorIndex: gdi.GDExtensionInterfaceStringOperatorIndex = undefined;
    var stringOperatorIndexConst: gdi.GDExtensionInterfaceStringOperatorIndexConst = undefined;
    var stringOperatorPlusEqString: gdi.GDExtensionInterfaceStringOperatorPlusEqString = undefined;
    var stringOperatorPlusEqChar: gdi.GDExtensionInterfaceStringOperatorPlusEqChar = undefined;
    var stringOperatorPlusEqCstr: gdi.GDExtensionInterfaceStringOperatorPlusEqCstr = undefined;
    var stringOperatorPlusEqWcstr: gdi.GDExtensionInterfaceStringOperatorPlusEqWcstr = undefined;
    var stringOperatorPlusEqC32str: gdi.GDExtensionInterfaceStringOperatorPlusEqC32str = undefined;
    var stringResize: gdi.GDExtensionInterfaceStringResize = undefined;
    var stringNameNewWithLatin1Chars: gdi.GDExtensionInterfaceStringNameNewWithLatin1Chars = undefined;
    var stringNameNewWithUtf8Chars: gdi.GDExtensionInterfaceStringNameNewWithUtf8Chars = undefined;
    var stringNameNewWithUtf8CharsAndLen: gdi.GDExtensionInterfaceStringNameNewWithUtf8CharsAndLen = undefined;
    var xmlParserOpenBuffer: gdi.GDExtensionInterfaceXmlParserOpenBuffer = undefined;
    var fileAccessStoreBuffer: gdi.GDExtensionInterfaceFileAccessStoreBuffer = undefined;
    var fileAccessGetBuffer: gdi.GDExtensionInterfaceFileAccessGetBuffer = undefined;
    var workerThreadPoolAddNativeGroupTask: gdi.GDExtensionInterfaceWorkerThreadPoolAddNativeGroupTask = undefined;
    var workerThreadPoolAddNativeTask: gdi.GDExtensionInterfaceWorkerThreadPoolAddNativeTask = undefined;
    var packedByteArrayOperatorIndex: gdi.GDExtensionInterfacePackedByteArrayOperatorIndex = undefined;
    var packedByteArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedByteArrayOperatorIndexConst = undefined;
    var packedFloat32ArrayOperatorIndex: gdi.GDExtensionInterfacePackedFloat32ArrayOperatorIndex = undefined;
    var packedFloat32ArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst = undefined;
    var packedFloat64ArrayOperatorIndex: gdi.GDExtensionInterfacePackedFloat64ArrayOperatorIndex = undefined;
    var packedFloat64ArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst = undefined;
    var packedInt32ArrayOperatorIndex: gdi.GDExtensionInterfacePackedInt32ArrayOperatorIndex = undefined;
    var packedInt32ArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedInt32ArrayOperatorIndexConst = undefined;
    var packedInt64ArrayOperatorIndex: gdi.GDExtensionInterfacePackedInt64ArrayOperatorIndex = undefined;
    var packedInt64ArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedInt64ArrayOperatorIndexConst = undefined;
    var packedStringArrayOperatorIndex: gdi.GDExtensionInterfacePackedStringArrayOperatorIndex = undefined;
    var packedStringArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedStringArrayOperatorIndexConst = undefined;
    var packedVector2ArrayOperatorIndex: gdi.GDExtensionInterfacePackedVector2ArrayOperatorIndex = undefined;
    var packedVector2ArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedVector2ArrayOperatorIndexConst = undefined;
    var packedVector3ArrayOperatorIndex: gdi.GDExtensionInterfacePackedVector3ArrayOperatorIndex = undefined;
    var packedVector3ArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedVector3ArrayOperatorIndexConst = undefined;
    var packedVector4ArrayOperatorIndex: gdi.GDExtensionInterfacePackedVector4ArrayOperatorIndex = undefined;
    var packedVector4ArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedVector4ArrayOperatorIndexConst = undefined;
    var packedColorArrayOperatorIndex: gdi.GDExtensionInterfacePackedColorArrayOperatorIndex = undefined;
    var packedColorArrayOperatorIndexConst: gdi.GDExtensionInterfacePackedColorArrayOperatorIndexConst = undefined;
    var arrayOperatorIndex: gdi.GDExtensionInterfaceArrayOperatorIndex = undefined;
    var arrayOperatorIndexConst: gdi.GDExtensionInterfaceArrayOperatorIndexConst = undefined;
    var arrayRef: gdi.GDExtensionInterfaceArrayRef = undefined;
    var arraySetTyped: gdi.GDExtensionInterfaceArraySetTyped = undefined;
    var dictionaryOperatorIndex: gdi.GDExtensionInterfaceDictionaryOperatorIndex = undefined;
    var dictionaryOperatorIndexConst: gdi.GDExtensionInterfaceDictionaryOperatorIndexConst = undefined;
    var objectMethodBindCall: gdi.GDExtensionInterfaceObjectMethodBindCall = undefined;
    var objectMethodBindPtrcall: gdi.GDExtensionInterfaceObjectMethodBindPtrcall = undefined;
    var objectDestroy: gdi.GDExtensionInterfaceObjectDestroy = undefined;
    var globalGetSingleton: gdi.GDExtensionInterfaceGlobalGetSingleton = undefined;
    var objectGetInstanceBinding: gdi.GDExtensionInterfaceObjectGetInstanceBinding = undefined;
    var objectSetInstanceBinding: gdi.GDExtensionInterfaceObjectSetInstanceBinding = undefined;
    var objectFreeInstanceBinding: gdi.GDExtensionInterfaceObjectFreeInstanceBinding = undefined;
    var objectSetInstance: gdi.GDExtensionInterfaceObjectSetInstance = undefined;
    var objectGetClassName: gdi.GDExtensionInterfaceObjectGetClassName = undefined;
    var objectCastTo: gdi.GDExtensionInterfaceObjectCastTo = undefined;
    var objectGetInstanceFromId: gdi.GDExtensionInterfaceObjectGetInstanceFromId = undefined;
    var objectGetInstanceId: gdi.GDExtensionInterfaceObjectGetInstanceId = undefined;
    var objectHasScriptMethod: gdi.GDExtensionInterfaceObjectHasScriptMethod = undefined;
    var objectCallScriptMethod: gdi.GDExtensionInterfaceObjectCallScriptMethod = undefined;
    var refGetObject: gdi.GDExtensionInterfaceRefGetObject = undefined;
    var refSetObject: gdi.GDExtensionInterfaceRefSetObject = undefined;
    var scriptInstanceCreate: gdi.GDExtensionInterfaceScriptInstanceCreate = undefined;
    var scriptInstanceCreate2: gdi.GDExtensionInterfaceScriptInstanceCreate2 = undefined;
    var scriptInstanceCreate3: gdi.GDExtensionInterfaceScriptInstanceCreate3 = undefined;
    var placeholderScriptInstanceCreate: gdi.GDExtensionInterfacePlaceHolderScriptInstanceCreate = undefined;
    var placeholderScriptInstanceUpdate: gdi.GDExtensionInterfacePlaceHolderScriptInstanceUpdate = undefined;
    var objectGetScriptInstance: gdi.GDExtensionInterfaceObjectGetScriptInstance = undefined;
    var callableCustomCreate: gdi.GDExtensionInterfaceCallableCustomCreate = undefined;
    var callableCustomCreate2: gdi.GDExtensionInterfaceCallableCustomCreate2 = undefined;
    var callableCustomGetUserdata: gdi.GDExtensionInterfaceCallableCustomGetUserData = undefined;
    var classdbConstructObject: gdi.GDExtensionInterfaceClassdbConstructObject = undefined;
    var classdbGetMethodBind: gdi.GDExtensionInterfaceClassdbGetMethodBind = undefined;
    var classdbGetClassTag: gdi.GDExtensionInterfaceClassdbGetClassTag = undefined;
    var classdbRegisterExtensionClass: gdi.GDExtensionInterfaceClassdbRegisterExtensionClass = undefined;
    var classdbRegisterExtensionClass2: gdi.GDExtensionInterfaceClassdbRegisterExtensionClass2 = undefined;
    var classdbRegisterExtensionClass3: gdi.GDExtensionInterfaceClassdbRegisterExtensionClass3 = undefined;
    var classdbRegisterExtensionClassMethod: gdi.GDExtensionInterfaceClassdbRegisterExtensionClassMethod = undefined;
    var classdbRegisterExtensionClassVirtualMethod: gdi.GDExtensionInterfaceClassdbRegisterExtensionClassVirtualMethod = undefined;
    var classdbRegisterExtensionClassIntegerConstant: gdi.GDExtensionInterfaceClassdbRegisterExtensionClassIntegerConstant = undefined;
    var classdbRegisterExtensionClassProperty: gdi.GDExtensionInterfaceClassdbRegisterExtensionClassProperty = undefined;
    var classdbRegisterExtensionClassPropertyIndexed: gdi.GDExtensionInterfaceClassdbRegisterExtensionClassPropertyIndexed = undefined;
    var classdbRegisterExtensionClassPropertyGroup: gdi.GDExtensionInterfaceClassdbRegisterExtensionClassPropertyGroup = undefined;
    var classdbRegisterExtensionClassPropertySubgroup: gdi.GDExtensionInterfaceClassdbRegisterExtensionClassPropertySubgroup = undefined;
    var classdbRegisterExtensionClassSignal: gdi.GDExtensionInterfaceClassdbRegisterExtensionClassSignal = undefined;
    var classdbUnregisterExtensionClass: gdi.GDExtensionInterfaceClassdbUnregisterExtensionClass = undefined;
    var getLibraryPath: gdi.GDExtensionInterfaceGetLibraryPath = undefined;
    var editorAddPlugin: gdi.GDExtensionInterfaceEditorAddPlugin = undefined;
    var editorRemovePlugin: gdi.GDExtensionInterfaceEditorRemovePlugin = undefined;
    var editorHelpLoadXmlFromUtf8Chars: gdi.GDExtensionsInterfaceEditorHelpLoadXmlFromUtf8Chars = undefined;
    var editorHelpLoadXmlFromUtf8CharsAndLen: gdi.GDExtensionsInterfaceEditorHelpLoadXmlFromUtf8CharsAndLen = undefined;
} = undefined;
