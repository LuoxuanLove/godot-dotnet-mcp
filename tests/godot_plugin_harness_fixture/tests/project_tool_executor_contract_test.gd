extends RefCounted

const ProjectExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/project/executor.gd")

const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_project_contracts"
const TEMP_ACTION := "mcp_contract_project_jump"
const TEMP_SETTING := "application/config/mcp_contract_marker"
const TEMP_CSPROJ := "res://Tmp/godot_dotnet_mcp_project_contracts/Sample.Game.csproj"

var _original_setting_value = null
var _had_original_setting := false


func run_case(_tree: SceneTree) -> Dictionary:
	var executor = ProjectExecutorScript.new()

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/project_tools.gd"):
		return _failure("project_tools.gd should be removed once the split executor becomes the only stable entry.")

	_prepare_temp_root()
	_capture_setting_snapshot()
	_remove_input_action_if_present(TEMP_ACTION)

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 5:
		return _failure("Project executor should expose 5 tool definitions after the split.")

	var expected_names := ["info", "dotnet", "settings", "input", "autoload"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Project executor is missing tool definition '%s'." % expected_name)

	var info_result: Dictionary = executor.execute("info", {"action": "get_info"})
	if not bool(info_result.get("success", false)):
		return _failure("Project info service failed through the split executor.")

	var settings_set_result: Dictionary = executor.execute("settings", {
		"action": "set",
		"setting": TEMP_SETTING,
		"value": "future-architecture"
	})
	if not bool(settings_set_result.get("success", false)):
		return _failure("Project settings set failed through the split settings service.")

	var settings_get_result: Dictionary = executor.execute("info", {
		"action": "get_settings",
		"setting": TEMP_SETTING
	})
	if not bool(settings_get_result.get("success", false)):
		return _failure("Project info get_settings failed after split.")
	if str(settings_get_result.get("data", {}).get("value", "")) != "future-architecture":
		return _failure("Project info get_settings returned unexpected value after split.")

	var input_add_result: Dictionary = executor.execute("input", {
		"action": "add_action",
		"name": TEMP_ACTION
	})
	if not bool(input_add_result.get("success", false)):
		return _failure("Project input add_action failed through the split input service.")

	var input_binding_result: Dictionary = executor.execute("input", {
		"action": "add_binding",
		"name": TEMP_ACTION,
		"type": "key",
		"key": "Space"
	})
	if not bool(input_binding_result.get("success", false)):
		return _failure("Project input add_binding failed through the split input service.")

	var input_get_result: Dictionary = executor.execute("input", {
		"action": "get_action",
		"name": TEMP_ACTION
	})
	if not bool(input_get_result.get("success", false)):
		return _failure("Project input get_action failed after split.")
	if int(input_get_result.get("data", {}).get("events", []).size()) != 1:
		return _failure("Project input get_action did not report the expected binding count.")

	var autoload_result: Dictionary = executor.execute("autoload", {"action": "list"})
	if not bool(autoload_result.get("success", false)):
		return _failure("Project autoload list failed through the split autoload service.")

	var autoload_add_result: Dictionary = executor.execute("autoload", {
		"action": "add",
		"name": "TempAutoload",
		"path": "res://temp_autoload.gd"
	})
	if bool(autoload_add_result.get("success", false)):
		return _failure("Project autoload add should stay disabled for safety.")

	var csproj_write_result = _write_sample_csproj(TEMP_CSPROJ)
	if not bool(csproj_write_result.get("success", false)):
		return csproj_write_result

	var dotnet_result: Dictionary = executor.execute("dotnet", {
		"path": TEMP_CSPROJ
	})
	if not bool(dotnet_result.get("success", false)):
		return _failure("Project dotnet parsing failed through the split dotnet service.")
	var projects: Array = dotnet_result.get("data", {}).get("projects", [])
	if projects.is_empty():
		return _failure("Project dotnet parsing returned no projects after split.")
	var first_project: Dictionary = projects[0]
	if str(first_project.get("assembly_name", "")) != "Sample.Game":
		return _failure("Project dotnet parsing returned unexpected assembly name.")
	if int(first_project.get("package_reference_count", 0)) != 1:
		return _failure("Project dotnet parsing returned unexpected package reference count.")

	return {
		"name": "project_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"autoload_count": int(autoload_result.get("data", {}).get("count", 0)),
			"project_count": projects.size(),
			"assembly_name": str(first_project.get("assembly_name", "")),
			"binding_count": int(input_get_result.get("data", {}).get("events", []).size())
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_remove_input_action_if_present(TEMP_ACTION)
	_restore_setting_snapshot()
	_remove_tree(TEMP_ROOT)


func _prepare_temp_root() -> void:
	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func _capture_setting_snapshot() -> void:
	_had_original_setting = ProjectSettings.has_setting(TEMP_SETTING)
	if _had_original_setting:
		_original_setting_value = ProjectSettings.get_setting(TEMP_SETTING)
	else:
		_original_setting_value = null


func _restore_setting_snapshot() -> void:
	if _had_original_setting:
		ProjectSettings.set_setting(TEMP_SETTING, _original_setting_value)
	else:
		ProjectSettings.set_setting(TEMP_SETTING, null)
	ProjectSettings.save()


func _remove_input_action_if_present(action_name: String) -> void:
	var setting_path := "input/" + action_name
	if ProjectSettings.has_setting(setting_path):
		ProjectSettings.set_setting(setting_path, null)
		ProjectSettings.save()


func _write_sample_csproj(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("Failed to create temporary .csproj file for project contract test.")
	file.store_string("""<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <AssemblyName>Sample.Game</AssemblyName>
    <RootNamespace>Sample.Game</RootNamespace>
    <DefineConstants>DEBUG;TRACE</DefineConstants>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="GodotSharp" Version="4.6.0" />
  </ItemGroup>
</Project>
""")
	file.close()
	return {"success": true}


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_tree_absolute(absolute_path)


func _remove_tree_absolute(absolute_path: String) -> void:
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree_absolute(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "project_tool_executor_contracts",
		"success": false,
		"error": message
	}
