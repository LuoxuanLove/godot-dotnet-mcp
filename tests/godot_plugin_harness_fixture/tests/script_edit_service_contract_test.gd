extends RefCounted

const GDScriptEditServiceScript = preload("res://addons/godot_dotnet_mcp/tools/script/gdscript_edit_service.gd")
const CSharpEditServiceScript = preload("res://addons/godot_dotnet_mcp/tools/script/csharp_edit_service.gd")
const CSharpEditActionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/script/csharp_edit_action_service.gd")
const GDScriptEditHelperScript = preload("res://addons/godot_dotnet_mcp/tools/script/gdscript_edit_helper.gd")
const CSharpEditHelperScript = preload("res://addons/godot_dotnet_mcp/tools/script/csharp_edit_helper.gd")
const MCPScriptParserScript = preload("res://addons/godot_dotnet_mcp/tools/mcp_script_parser.gd")

var _temp_paths: Array[String] = []
var _gd_service = null
var _cs_service = null


func run_case(_tree: SceneTree) -> Dictionary:
	_gd_service = GDScriptEditServiceScript.new()
	_cs_service = CSharpEditServiceScript.new()
	var cs_action_service = CSharpEditActionServiceScript.new()
	var gd_helper = GDScriptEditHelperScript.new()
	var cs_helper = CSharpEditHelperScript.new()

	var temp_dir := "res://tests_tmp/script_edit_service_contracts"
	_ensure_dir(temp_dir)

	var gd_path := "%s/sample_service_split.gd" % temp_dir
	var cs_path := "%s/SampleServiceSplit.cs" % temp_dir
	_temp_paths.append_array([gd_path, cs_path, temp_dir])
	_write_text(cs_path, "using Godot;\n\npublic partial class SampleServiceSplit : Node\n{\n}\n")

	var gd_create: Dictionary = _gd_service.execute("edit_gd", {
		"action": "create",
		"path": gd_path,
		"extends": "Node"
	})
	if not bool(gd_create.get("success", false)):
		return _failure("Split GDScript edit service failed to create a script.")

	var gd_add_function: Dictionary = _gd_service.execute("edit_gd", {
		"action": "add_function",
		"path": gd_path,
		"name": "ping",
		"body": "return 1",
		"return_type": "int"
	})
	if not bool(gd_add_function.get("success", false)):
		return _failure("Split GDScript action service failed to add a function.")

	var gd_functions: Dictionary = _gd_service.execute("edit_gd", {
		"action": "get_functions",
		"path": gd_path
	})
	if not bool(gd_functions.get("success", false)):
		return _failure("Split GDScript edit helper failed to list functions.")
	if int(gd_functions.get("data", {}).get("count", 0)) < 2:
		return _failure("GDScript edit helper should report both _ready and ping functions.")

	var gd_add_variable: Dictionary = _gd_service.execute("edit_gd", {
		"action": "add_variable",
		"path": gd_path,
		"name": "answer",
		"type": "int",
		"default_value": "7"
	})
	if not bool(gd_add_variable.get("success", false)):
		return _failure("Split GDScript action service failed to add a variable.")
	var gd_content := _read_text(gd_path)
	if gd_content.find("var answer: int = 7") == -1:
		return _failure("GDScript add_variable should preserve default_value in the script file.")
	var gd_variables: Dictionary = _gd_service.execute("edit_gd", {
		"action": "get_variables",
		"path": gd_path
	})
	if not bool(gd_variables.get("success", false)):
		return _failure("Split GDScript edit helper failed to list variables.")
	if int(gd_variables.get("data", {}).get("count", 0)) < 1:
		return _failure("GDScript edit helper should report the added variable.")
	var variable_items = gd_variables.get("data", {}).get("variables", [])
	if not (variable_items is Array) or (variable_items as Array).is_empty():
		return _failure("GDScript edit helper should return variable details.")
	var first_variable = (variable_items as Array)[0]
	if not (first_variable is Dictionary) or str((first_variable as Dictionary).get("default", "")) != "7":
		return _failure("GDScript edit helper should report the added variable default value.")
	var parser = MCPScriptParserScript.new()
	var parser_result: Dictionary = parser.parse_script_metadata(gd_path)
	if not bool(parser_result.get("success", false)):
		return _failure("MCPScriptParser should parse the edited GDScript file.")
	var parser_variables = parser_result.get("data", {}).get("variables", [])
	if not (parser_variables is Array) or (parser_variables as Array).is_empty():
		return _failure("MCPScriptParser should report ordinary GDScript variables for script_analyze.")
	var parsed_variable = (parser_variables as Array)[0]
	if not (parsed_variable is Dictionary) or str((parsed_variable as Dictionary).get("default", "")) != "7":
		return _failure("MCPScriptParser should preserve ordinary GDScript variable default values.")

	var fallback_method = cs_action_service.call("_build_method_code", {
		"name": "NeedsBody",
		"return_type": "int"
	})
	if not (fallback_method is String):
		return _failure("C# action service should build method code as text.")
	var fallback_method_text := str(fallback_method)
	if fallback_method_text.find("TODO: implement") != -1 or fallback_method_text.find("return default;") != -1:
		return _failure("C# fallback method generation should not emit ambiguous fallback bodies.")
	if fallback_method_text.find("throw new System.NotImplementedException") == -1:
		return _failure("C# fallback method generation should emit an explicit NotImplementedException.")

	var cs_missing_body_method: Dictionary = _cs_service.execute("edit_cs", {
		"action": "upsert_method",
		"path": cs_path,
		"type_name": "SampleServiceSplit",
		"member_name": "NeedsBody",
		"return_type": "int"
	})
	if not bool(cs_missing_body_method.get("success", false)):
		return _failure("C# upsert_method without a body should succeed through the Roslyn-backed split service.")
	if str(cs_missing_body_method.get("data", {}).get("engine", "")) != "roslyn":
		return _failure("C# upsert_method without a body should report engine=roslyn.")
	var cs_missing_body_content := _read_text(cs_path)
	if cs_missing_body_content.find("TODO: implement") != -1 or cs_missing_body_content.find("return default;") != -1:
		return _failure("C# Roslyn upsert_method without a body should not emit ambiguous fallback bodies.")
	if cs_missing_body_content.find("throw new System.NotImplementedException") == -1:
		return _failure("C# Roslyn upsert_method without a body should emit an explicit NotImplementedException.")

	var cs_upsert_method: Dictionary = _cs_service.execute("edit_cs", {
		"action": "upsert_method",
		"path": cs_path,
		"type_name": "SampleServiceSplit",
		"member_name": "Ping",
		"return_type": "int",
		"parameters": ["float delta"],
		"body": "return 1;"
	})
	if not bool(cs_upsert_method.get("success", false)):
		return _failure("C# upsert_method should succeed through the Roslyn-backed split service.")
	if str(cs_upsert_method.get("data", {}).get("engine", "")) != "roslyn":
		return _failure("C# upsert_method should report engine=roslyn.")
	if str(cs_upsert_method.get("data", {}).get("mode", "")) != "syntax":
		return _failure("C# upsert_method should report mode=syntax.")

	var cs_rename: Dictionary = _cs_service.execute("edit_cs", {
		"action": "rename_member",
		"path": cs_path,
		"type_name": "SampleServiceSplit",
		"member_name": "Ping",
		"new_name": "Pong",
		"parameters": ["float delta"]
	})
	if not bool(cs_rename.get("success", false)):
		return _failure("C# rename_member should succeed through the Roslyn-backed split service.")
	if str(cs_rename.get("data", {}).get("engine", "")) != "roslyn":
		return _failure("C# rename_member should report engine=roslyn.")
	if str(cs_rename.get("data", {}).get("mode", "")) != "syntax":
		return _failure("C# rename_member should report mode=syntax.")

	return {
		"name": "script_edit_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"gd_function_count": int(gd_functions.get("data", {}).get("count", 0)),
			"gd_variable_count": int(gd_variables.get("data", {}).get("count", 0)),
			"gd_service_path": gd_path
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _gd_service != null and _gd_service.has_method("clear"):
		_gd_service.clear()
	if _cs_service != null and _cs_service.has_method("clear"):
		_cs_service.clear()
	_gd_service = null
	_cs_service = null
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


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create script edit contract fixture: %s" % path)
		return
	file.store_string(content)
	file.close()


func _failure(message: String) -> Dictionary:
	return {
		"name": "script_edit_service_contracts",
		"success": false,
		"error": message
	}
