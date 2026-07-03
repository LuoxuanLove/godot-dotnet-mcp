extends RefCounted

const DebugExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/debug/executor.gd")
const DebugCompatibilityScript = preload("res://addons/godot_dotnet_mcp/tools/debug_tools.gd")
const TEMP_ROOT := "res://tests_tmp/godot_dotnet_mcp_debug_contracts"
const TEMP_USER_DOTNET_BRIDGE_CSPROJ := "res://tests_tmp/godot_dotnet_mcp_debug_contracts/UserDotnetBridge/DotnetBridge.csproj"
const PLUGIN_BRIDGE_DIR := "res://addons/godot_dotnet_mcp/dotnet_bridge"
const PLUGIN_BRIDGE_CSPROJ := "res://addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj"

var _created_plugin_bridge_fixture := false


func run_case(_tree: SceneTree) -> Dictionary:
	if not ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/debug_tools.gd"):
		return _failure("debug_tools.gd compatibility entry should remain loadable for existing references.")
	var executor_base_script = DebugExecutorScript.new().get_script().get_base_script()
	if executor_base_script == null or str(executor_base_script.resource_path) != "res://addons/godot_dotnet_mcp/tools/base_tools.gd":
		return _failure("debug/executor.gd should own the debug implementation and extend base_tools.gd directly.")
	var compatibility_base_script = DebugCompatibilityScript.new().get_script().get_base_script()
	if compatibility_base_script == null or str(compatibility_base_script.resource_path) != "res://addons/godot_dotnet_mcp/tools/debug/executor.gd":
		return _failure("debug_tools.gd should remain only as a compatibility wrapper around debug/executor.gd.")

	var executor = DebugExecutorScript.new()
	_prepare_temp_root()
	var user_bridge_write_result := _write_sample_csproj(TEMP_USER_DOTNET_BRIDGE_CSPROJ, "UserDotnetBridge")
	if not bool(user_bridge_write_result.get("success", false)):
		return user_bridge_write_result
	var plugin_bridge_result := _ensure_plugin_bridge_fixture()
	if not bool(plugin_bridge_result.get("success", false)):
		return plugin_bridge_result

	if not bool(executor.call("_is_plugin_bridge_csproj", PLUGIN_BRIDGE_CSPROJ)):
		return _failure("Debug dotnet project discovery should identify the plugin-owned DotnetBridge.csproj.")
	if bool(executor.call("_is_plugin_bridge_csproj", TEMP_USER_DOTNET_BRIDGE_CSPROJ)):
		return _failure("Debug dotnet project discovery should not reject user projects named DotnetBridge.csproj.")
	var plugin_bridge_projects: Array = executor.call("_find_csproj_files", PLUGIN_BRIDGE_DIR)
	if not plugin_bridge_projects.is_empty():
		return _failure("Debug dotnet automatic project discovery should skip plugin-owned DotnetBridge.csproj.")
	if str(executor.call("_resolve_csproj_path", PLUGIN_BRIDGE_CSPROJ)) != PLUGIN_BRIDGE_CSPROJ:
		return _failure("Debug dotnet explicit project resolution should still accept the requested plugin bridge project path.")
	var build_server_guard := _assert_dotnet_build_disables_build_servers()
	if not build_server_guard.is_empty():
		return _failure(build_server_guard)

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 8:
		return _failure("Debug executor should expose 8 canonical tool definitions without the compatibility log alias.")

	var expected_names := ["log_write", "log_buffer", "runtime_bridge", "dotnet", "performance", "profiler", "editor_log", "class_db"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	if actual_names.has("log"):
		return _failure("Debug executor should not expose the removed compatibility log alias.")
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Debug executor is missing tool definition '%s'." % expected_name)
	var removed_log_result: Dictionary = executor.execute("log", {"action": "print", "message": "removed debug_log"})
	if bool(removed_log_result.get("success", true)):
		return _failure("Debug executor should not execute the removed compatibility log alias.")

	var clear_buffer_result: Dictionary = executor.execute("log_buffer", {"action": "clear_buffer"})
	if not bool(clear_buffer_result.get("success", false)):
		return _failure("Debug log_buffer clear_buffer failed through the split service path.")

	var write_result: Dictionary = executor.execute("log_write", {
		"action": "print",
		"message": "debug executor contract"
	})
	if not bool(write_result.get("success", false)):
		return _failure("Debug log_write print failed through the split service path.")

	var recent_result: Dictionary = executor.execute("log_buffer", {"action": "get_recent", "limit": 10})
	if not bool(recent_result.get("success", false)):
		return _failure("Debug log_buffer get_recent failed through the split service path.")
	if int(recent_result.get("data", {}).get("count", 0)) < 1:
		return _failure("Debug log_buffer get_recent should report at least one buffered event.")

	var runtime_summary_result: Dictionary = executor.execute("runtime_bridge", {"action": "get_summary"})
	if not bool(runtime_summary_result.get("success", false)):
		return _failure("Debug runtime_bridge get_summary failed through the split service path.")

	var dotnet_result: Dictionary = executor.execute("dotnet", {
		"action": "build",
		"path": "res://tests_tmp/does_not_exist.csproj"
	})
	if bool(dotnet_result.get("success", false)):
		return _failure("Debug dotnet build should fail gracefully when the requested project path does not exist.")

	var fps_result: Dictionary = executor.execute("performance", {"action": "get_fps"})
	if not bool(fps_result.get("success", false)):
		return _failure("Debug performance get_fps failed through the split service path.")

	var class_exists_result: Dictionary = executor.execute("class_db", {
		"action": "class_exists",
		"class_name": "Node"
	})
	if not bool(class_exists_result.get("success", false)):
		return _failure("Debug class_db class_exists failed through the split service path.")
	if not bool(class_exists_result.get("data", {}).get("exists", false)):
		return _failure("Debug class_db class_exists should report that Node exists.")

	var editor_log_result: Dictionary = executor.execute("editor_log", {"action": "get_output"})
	if bool(editor_log_result.get("success", false)):
		return _failure("Debug editor_log get_output should report that EditorLog is unavailable in headless mode.")

	return {
		"name": "debug_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"buffered_event_count": int(recent_result.get("data", {}).get("count", 0)),
			"runtime_summary_keys": (runtime_summary_result.get("data", {}) as Dictionary).keys().size(),
			"fps": fps_result.get("data", {}).get("fps", 0)
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_remove_tree(TEMP_ROOT)
	if _created_plugin_bridge_fixture:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PLUGIN_BRIDGE_CSPROJ))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PLUGIN_BRIDGE_DIR))
		_created_plugin_bridge_fixture = false


func _prepare_temp_root() -> void:
	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func _assert_dotnet_build_disables_build_servers() -> String:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/debug/executor.gd")
	if source.find('args.append("--disable-build-servers")') == -1:
		return "Debug dotnet build should disable build servers so headless harness and editor sessions can exit cleanly."
	return ""


func _ensure_plugin_bridge_fixture() -> Dictionary:
	if FileAccess.file_exists(PLUGIN_BRIDGE_CSPROJ):
		return {"success": true}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PLUGIN_BRIDGE_DIR))
	var write_result := _write_sample_csproj(PLUGIN_BRIDGE_CSPROJ, "DotnetBridge")
	if bool(write_result.get("success", false)):
		_created_plugin_bridge_fixture = true
	return write_result


func _write_sample_csproj(path: String, assembly_name: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("Failed to create temporary .csproj file for debug contract test.")
	file.store_string("""<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <AssemblyName>%s</AssemblyName>
  </PropertyGroup>
</Project>
""" % assembly_name)
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
		"name": "debug_tool_executor_contracts",
		"success": false,
		"error": message
	}
