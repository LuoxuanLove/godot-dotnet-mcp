extends RefCounted

const PROJECT_PROBE_PATH := "res://ProbeProjectScript.cs"
const PLUGIN_PROBE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/ProbePluginScript.cs"
const FACADE_LIKE_PROBE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/ProbeFacadeLikeScript.cs"
const CAPABILITIES_PROBE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/ProbeCapabilitiesScript.cs"
const PARSE_PROBE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/ProbeParseScript.cs"
const PATCH_PROBE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/ProbePatchScript.cs"
const PASCAL_FACADE_PROBE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/ProbePascalFacadeScript.cs"
const VARIANT_FACADE_PROBE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/ProbeVariantFacadeScript.cs"
const VOID_METHOD_PROBE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/ProbeVoidMethodScript.cs"


func run_case(_tree: SceneTree) -> Dictionary:
	var project_script = load(PROJECT_PROBE_PATH)
	var plugin_script = load(PLUGIN_PROBE_PATH)
	var facade_like_script = load(FACADE_LIKE_PROBE_PATH)
	var capabilities_script = load(CAPABILITIES_PROBE_PATH)
	var parse_script = load(PARSE_PROBE_PATH)
	var patch_script = load(PATCH_PROBE_PATH)
	var pascal_facade_script = load(PASCAL_FACADE_PROBE_PATH)
	var variant_facade_script = load(VARIANT_FACADE_PROBE_PATH)
	var void_method_script = load(VOID_METHOD_PROBE_PATH)
	if project_script == null or not (project_script is Script):
		return _failure("Project-path C# probe could not be loaded")
	if plugin_script == null or not (plugin_script is Script):
		return _failure("Plugin-path C# probe could not be loaded")
	if facade_like_script == null or not (facade_like_script is Script):
		return _failure("Facade-like C# probe could not be loaded")
	if capabilities_script == null or not (capabilities_script is Script):
		return _failure("Capabilities C# probe could not be loaded")
	if parse_script == null or not (parse_script is Script):
		return _failure("Parse C# probe could not be loaded")
	if patch_script == null or not (patch_script is Script):
		return _failure("Patch C# probe could not be loaded")
	if pascal_facade_script == null or not (pascal_facade_script is Script):
		return _failure("Pascal facade C# probe could not be loaded")
	if variant_facade_script == null or not (variant_facade_script is Script):
		return _failure("Variant facade C# probe could not be loaded")
	if void_method_script == null or not (void_method_script is Script):
		return _failure("Void method C# probe could not be loaded")

	var project_can := (project_script as Script).can_instantiate()
	var plugin_can := (plugin_script as Script).can_instantiate()
	var facade_like_can := (facade_like_script as Script).can_instantiate()
	var capabilities_can := (capabilities_script as Script).can_instantiate()
	var parse_can := (parse_script as Script).can_instantiate()
	var patch_can := (patch_script as Script).can_instantiate()
	var pascal_facade_can := (pascal_facade_script as Script).can_instantiate()
	var variant_facade_can := (variant_facade_script as Script).can_instantiate()
	var void_method_can := (void_method_script as Script).can_instantiate()
	var project_class_exists := ClassDB.class_exists("ProbeProjectScript")
	var plugin_class_exists := ClassDB.class_exists("ProbePluginScript")
	var facade_like_class_exists := ClassDB.class_exists("ProbeFacadeLikeScript")
	var capabilities_class_exists := ClassDB.class_exists("ProbeCapabilitiesScript")
	var parse_class_exists := ClassDB.class_exists("ProbeParseScript")
	var patch_class_exists := ClassDB.class_exists("ProbePatchScript")
	var pascal_facade_class_exists := ClassDB.class_exists("ProbePascalFacadeScript")
	var variant_facade_class_exists := ClassDB.class_exists("ProbeVariantFacadeScript")
	var void_method_class_exists := ClassDB.class_exists("ProbeVoidMethodScript")

	return {
		"name": "plugin_path_csharp_registration_probe",
		"success": true,
		"error": "",
		"details": {
			"project_can_instantiate": project_can,
			"plugin_can_instantiate": plugin_can,
			"facade_like_can_instantiate": facade_like_can,
			"capabilities_can_instantiate": capabilities_can,
			"parse_can_instantiate": parse_can,
			"patch_can_instantiate": patch_can,
			"pascal_facade_can_instantiate": pascal_facade_can,
			"variant_facade_can_instantiate": variant_facade_can,
			"void_method_can_instantiate": void_method_can,
			"project_class_exists": project_class_exists,
			"plugin_class_exists": plugin_class_exists,
			"facade_like_class_exists": facade_like_class_exists,
			"capabilities_class_exists": capabilities_class_exists,
			"parse_class_exists": parse_class_exists,
			"patch_class_exists": patch_class_exists,
			"pascal_facade_class_exists": pascal_facade_class_exists,
			"variant_facade_class_exists": variant_facade_class_exists,
			"void_method_class_exists": void_method_class_exists
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_path_csharp_registration_probe",
		"success": false,
		"error": message,
		"details": {}
	}
