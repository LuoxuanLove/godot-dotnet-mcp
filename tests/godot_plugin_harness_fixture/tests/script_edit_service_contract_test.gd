extends RefCounted

const GDScriptEditServiceScript = preload("res://addons/godot_dotnet_mcp/tools/script/gdscript_edit_service.gd")
const CSharpEditServiceScript = preload("res://addons/godot_dotnet_mcp/tools/script/csharp_edit_service.gd")
const GDScriptEditHelperScript = preload("res://addons/godot_dotnet_mcp/tools/script/gdscript_edit_helper.gd")
const CSharpEditHelperScript = preload("res://addons/godot_dotnet_mcp/tools/script/csharp_edit_helper.gd")

var _temp_paths: Array[String] = []


func run_case(_tree: SceneTree) -> Dictionary:
	var gd_service = GDScriptEditServiceScript.new()
	var cs_service = CSharpEditServiceScript.new()
	var gd_helper = GDScriptEditHelperScript.new()
	var cs_helper = CSharpEditHelperScript.new()

	var temp_dir := "res://tests_tmp/script_edit_service_contracts"
	_ensure_dir(temp_dir)

	var gd_path := "%s/sample_service_split.gd" % temp_dir
	var cs_path := "%s/SampleServiceSplit.cs" % temp_dir
	_temp_paths.append_array([gd_path, cs_path, temp_dir])

	var gd_create: Dictionary = gd_service.execute("edit_gd", {
		"action": "create",
		"path": gd_path,
		"extends": "Node"
	})
	if not bool(gd_create.get("success", false)):
		return _failure("Split GDScript edit service failed to create a script.")

	var gd_add_function: Dictionary = gd_service.execute("edit_gd", {
		"action": "add_function",
		"path": gd_path,
		"name": "ping",
		"body": "return 1",
		"return_type": "int"
	})
	if not bool(gd_add_function.get("success", false)):
		return _failure("Split GDScript action service failed to add a function.")

	var gd_functions: Dictionary = gd_service.execute("edit_gd", {
		"action": "get_functions",
		"path": gd_path
	})
	if not bool(gd_functions.get("success", false)):
		return _failure("Split GDScript edit helper failed to list functions.")
	if int(gd_functions.get("data", {}).get("count", 0)) < 2:
		return _failure("GDScript edit helper should report both _ready and ping functions.")

	var cs_create: Dictionary = cs_service.execute("edit_cs", {
		"action": "create",
		"path": cs_path,
		"class_name": "SampleServiceSplit",
		"base_type": "Node"
	})
	if not bool(cs_create.get("success", false)):
		return _failure("Split C# edit service failed to create a script.")

	var cs_add_method: Dictionary = cs_service.execute("edit_cs", {
		"action": "add_method",
		"path": cs_path,
		"name": "Ping",
		"return_type": "int",
		"body": "return 1;"
	})
	if not bool(cs_add_method.get("success", false)):
		return _failure("Split C# action service failed to add a method.")

	var cs_rename: Dictionary = cs_service.execute("edit_cs", {
		"action": "rename_member",
		"path": cs_path,
		"name": "Ping",
		"new_name": "Pong"
	})
	if not bool(cs_rename.get("success", false)):
		return _failure("Split C# action service failed to rename a method.")

	var cs_text_result = gd_helper._read_text_file(cs_path)
	if not bool(cs_text_result.get("success", false)):
		return _failure("Failed to read the rewritten C# file after split actions.")
	var cs_text := str(cs_text_result.get("data", {}).get("content", ""))
	if "Pong" not in cs_text:
		return _failure("Renamed C# method should be written back to disk.")

	var cs_validation: Dictionary = cs_helper.validate_written_script(cs_path, cs_text)
	if not bool(cs_validation.get("success", false)):
		return _failure("C# edit helper should validate the rewritten script.")

	return {
		"name": "script_edit_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"gd_function_count": int(gd_functions.get("data", {}).get("count", 0)),
			"cs_class_name": str(cs_validation.get("data", {}).get("class_name", "")),
			"gd_service_path": gd_path,
			"cs_service_path": cs_path
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


func _failure(message: String) -> Dictionary:
	return {
		"name": "script_edit_service_contracts",
		"success": false,
		"error": message
	}
