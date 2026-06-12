extends RefCounted

const DebugCompatibilityScript = preload("res://addons/godot_dotnet_mcp/tools/debug_tools.gd")
const EditorCompatibilityScript = preload("res://addons/godot_dotnet_mcp/tools/editor_tools.gd")

const CASE_NAME := "tool_root_monolith_closure_contracts"
const TOOLS_ROOT := "res://addons/godot_dotnet_mcp/tools"
const ALLOWED_ROOT_TOOL_FILES := {
	"base_tools.gd": true,
	"debug_tools.gd": true,
	"editor_tools.gd": true
}
const COMPATIBILITY_WRAPPERS := {
	"debug_tools.gd": "res://addons/godot_dotnet_mcp/tools/debug/executor.gd",
	"editor_tools.gd": "res://addons/godot_dotnet_mcp/tools/editor/executor.gd"
}


func run_case(_tree: SceneTree) -> Dictionary:
	var dir := DirAccess.open(TOOLS_ROOT)
	if dir == null:
		return _failure("Tools root should be readable for root monolith closure guard.")

	var root_tool_files: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with("_tools.gd"):
			root_tool_files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	root_tool_files.sort()

	for file_name in root_tool_files:
		if not ALLOWED_ROOT_TOOL_FILES.has(file_name):
			return _failure("Unexpected root domain monolith remains: %s" % file_name, {
				"root_tool_files": root_tool_files
			})

	for file_name in COMPATIBILITY_WRAPPERS.keys():
		if not root_tool_files.has(file_name):
			return _failure("Compatibility wrapper should remain loadable: %s" % file_name, {
				"root_tool_files": root_tool_files
			})
		var expected_base := str(COMPATIBILITY_WRAPPERS.get(file_name, ""))
		var script = DebugCompatibilityScript if file_name == "debug_tools.gd" else EditorCompatibilityScript
		var base_script = script.new().get_script().get_base_script()
		if base_script == null or str(base_script.resource_path) != expected_base:
			return _failure("%s should stay a thin wrapper over %s." % [file_name, expected_base])

	return {
		"success": true,
		"name": CASE_NAME,
		"root_tool_files": root_tool_files,
		"compatibility_wrappers": COMPATIBILITY_WRAPPERS.keys()
	}


func _failure(message: String, extra: Dictionary = {}) -> Dictionary:
	var data := extra.duplicate(true)
	data["message"] = message
	return {
		"success": false,
		"name": CASE_NAME,
		"error": message,
		"data": data
	}
