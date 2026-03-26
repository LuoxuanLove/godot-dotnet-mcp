extends RefCounted

const ScriptExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/script/executor.gd")
const LegacyScriptToolsScript = preload("res://addons/godot_dotnet_mcp/tools/script_tools.gd")

var _temp_paths: Array[String] = []


func run_case(_tree: SceneTree) -> Dictionary:
	var executor = ScriptExecutorScript.new()
	var legacy_wrapper = LegacyScriptToolsScript.new()
	var executor_tools: Array[Dictionary] = executor.get_tools()
	var wrapper_tools: Array[Dictionary] = legacy_wrapper.get_tools()

	if executor_tools.size() != 8:
		return _failure("Script executor should expose 8 tool definitions after the split.")
	if wrapper_tools.size() != executor_tools.size():
		return _failure("Legacy script_tools wrapper should mirror the new executor tool count.")

	var expected_names := ["read", "open", "inspect", "symbols", "exports", "references", "edit_gd", "edit_cs"]
	var actual_names: Array[String] = []
	for tool_def in executor_tools:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Script executor is missing tool definition '%s'." % expected_name)

	var temp_dir := "res://tests_tmp/script_executor_contracts"
	_ensure_dir(temp_dir)

	var gd_path := "%s/sample_script_contract.gd" % temp_dir
	var cs_path := "%s/SampleScriptContract.cs" % temp_dir
	var created_gd_path := "%s/created_script_contract.gd" % temp_dir

	_write_text(gd_path, "class_name SampleScriptContract\nextends Node\n\n@export var speed: float = 1.0\n")
	_write_text(cs_path, "using Godot;\n\npublic partial class SampleScriptContractCs : Node\n{\n    [Export] public float Speed = 2.0f;\n}\n")
	_temp_paths.append_array([gd_path, cs_path, created_gd_path])
	_temp_paths.append(temp_dir)

	var read_result: Dictionary = executor.execute("read", {"path": gd_path})
	if not bool(read_result.get("success", false)):
		return _failure("Script executor failed to read a GDScript file.")
	if str(read_result.get("data", {}).get("language", "")) != "gdscript":
		return _failure("Script read should detect gdscript language.")

	var inspect_result: Dictionary = executor.execute("inspect", {"path": cs_path})
	if not bool(inspect_result.get("success", false)):
		return _failure("Script executor failed to inspect a C# file.")
	if str(inspect_result.get("data", {}).get("class_name", "")) != "SampleScriptContractCs":
		return _failure("Script inspect should return the C# class name from the split service path.")

	var create_result: Dictionary = executor.execute("edit_gd", {
		"action": "create",
		"path": created_gd_path,
		"extends": "Node"
	})
	if not bool(create_result.get("success", false)):
		return _failure("Script executor failed to create a GDScript file through the split edit service.")

	var references_result: Dictionary = executor.execute("references", {
		"action": "get_class_map",
		"refresh": true
	})
	if not bool(references_result.get("success", false)):
		return _failure("Script executor failed to build the reference index after the split.")

	return {
		"name": "script_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": executor_tools.size(),
			"class_map_count": int(references_result.get("data", {}).get("count", references_result.get("count", 0))),
			"created_gd_path": created_gd_path
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	for path in _temp_paths:
		if path.ends_with(".gd") or path.ends_with(".cs"):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for i in range(_temp_paths.size() - 1, -1, -1):
		var path = _temp_paths[i]
		if not path.ends_with(".gd") and not path.ends_with(".cs"):
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_temp_paths.clear()


func _ensure_dir(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)


func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create script contract fixture: %s" % path)
		return
	file.store_string(content)
	file.close()


func _failure(message: String) -> Dictionary:
	return {
		"name": "script_tool_executor_contracts",
		"success": false,
		"error": message
	}
