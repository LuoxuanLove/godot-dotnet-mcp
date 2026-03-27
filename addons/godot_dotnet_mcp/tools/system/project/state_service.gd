@tool
extends "res://addons/godot_dotnet_mcp/tools/system/project/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var error_limit := max(int(args.get("error_limit", 10)), 0)
	var include_runtime_health := bool(args.get("include_runtime_health", false))
	MCPDebugBuffer.record("debug", "system", "project_state: collecting stats (error_limit=%d)" % error_limit)
	var project_info: Dictionary = bridge.extract_data(bridge.call_atomic("project_info", {"action": "get_info"}))
	var dotnet_result: Dictionary = bridge.call_atomic("project_dotnet", {})
	var dotnet_data: Dictionary = bridge.extract_data(dotnet_result)
	var runtime_summary := _get_runtime_summary()
	var recent_errors := _get_runtime_errors(error_limit)
	var recent_warnings := _get_runtime_warnings(min(error_limit, 10))
	var gd_scripts: Array = bridge.collect_files("*.gd")
	var cs_scripts: Array = bridge.collect_files("*.cs")
	var scene_paths: Array = bridge.collect_files("*.tscn")
	var resources_tres: Array = bridge.collect_files("*.tres")
	var resources_res: Array = bridge.collect_files("*.res")
	var all_resources: Array = []
	all_resources.append_array(resources_tres)
	all_resources.append_array(resources_res)
	all_resources.sort()

	var compile_error_count := 0
	if bool(dotnet_result.get("success", false)):
		var dotnet_errors_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_dotnet", {"action": "build"}))
		compile_error_count = int(dotnet_errors_data.get("error_count", 0))

	var current_scene := ""
	var scene_snapshot: Dictionary = bridge.extract_data(bridge.call_atomic("debug_runtime_bridge", {"action": "get_scene_snapshot"}))
	if not scene_snapshot.is_empty():
		current_scene = str(scene_snapshot.get("current_scene", scene_snapshot.get("scene", "")))

	var main_scene := str(project_info.get("main_scene", ""))
	var result_data := {
		"project_name": str(project_info.get("name", "Untitled")),
		"project_description": str(project_info.get("description", "")),
		"project_version": str(project_info.get("version", "")),
		"project_path": str(project_info.get("project_path", ProjectSettings.globalize_path("res://"))),
		"godot_version": str(project_info.get("godot_version", "")),
		"godot_version_string": str(project_info.get("godot_version_string", "")),
		"main_scene": main_scene,
		"main_scene_exists": not main_scene.is_empty() and FileAccess.file_exists(main_scene),
		"current_scene": current_scene,
		"scripts": gd_scripts.size() + cs_scripts.size(),
		"gd_scripts": gd_scripts.size(),
		"cs_scripts": cs_scripts.size(),
		"scenes": scene_paths.size(),
		"resources": all_resources.size(),
		"scene_paths": scene_paths,
		"script_paths": gd_scripts + cs_scripts,
		"resource_paths": all_resources,
		"has_dotnet": bool(dotnet_result.get("success", false)),
		"dotnet_project_count": int(dotnet_data.get("count", 0)),
		"dotnet_projects": dotnet_data.get("projects", []),
		"compile_error_count": compile_error_count,
		"running": _is_runtime_running(runtime_summary),
		"runtime_bridge_status": str(runtime_summary.get("bridge_status", "unknown")),
		"session_count": int(runtime_summary.get("session_count", 0)),
		"recent_errors": recent_errors,
		"recent_warnings": recent_warnings,
		"error_count": recent_errors.size(),
		"warning_count": recent_warnings.size()
	}
	if include_runtime_health:
		result_data["runtime_health"] = {
			"lsp_diagnostics": _get_lsp_runtime_health_summary(),
			"tool_loader": _get_tool_loader_health_summary()
		}
	return bridge.success(result_data)
