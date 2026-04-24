@tool
extends RefCounted

## System implementation: project_state, project_configure,
## project_run, project_stop, runtime_diagnose

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")

var bridge
var _runtime_context: Dictionary = {}
var _project_run_timeout_token := 0

const HANDLED_TOOLS := [
	"project_state", "editor_state", "project_configure",
	"project_run", "project_stop", "runtime_diagnose", "userdata_maintenance"
]


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "project_state",
			"description": "PROJECT STATE: Snapshot of current project health — file counts, runtime errors, compile errors, bridge status. Use first to orient before diagnosing. Returns: error_count, compile_error_count, recent_errors[], has_dotnet, running, runtime_bridge_status, scene_paths[], script_paths[]. Optional: error_limit (default 10).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"error_limit": {
						"type": "integer",
						"description": "Max errors to include (default: 10)"
					},
					"include_runtime_health": {
						"type": "boolean",
						"description": "Include lightweight plugin runtime health summary, including self_diagnostics, lsp_diagnostics, and tool_loader health (default: false)"
					}
				}
			}
		},
		{
			"name": "editor_state",
			"description": "EDITOR STATE: Unified read-only editor session snapshot. Aggregates current editor UI state, Inspector summary, FileSystem selection, project runtime summary, and runtime control status into one payload for agent orientation.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "project_configure",
			"description": "PROJECT CONFIGURE: Read or modify project settings, autoloads, and input actions. Read actions: get_settings (requires: setting), list_autoloads, list_input_actions. Write actions: set_setting (requires: setting, value), add_autoload (requires: name, path), remove_autoload (requires: name). Call get_settings to inspect a path before modifying.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_settings", "set_setting", "list_autoloads", "add_autoload", "remove_autoload", "list_input_actions"],
						"description": "Configuration action to perform"
					},
					"setting": {"type": "string", "description": "Setting path for get_settings/set_setting"},
					"value": {"description": "New value for set_setting"},
					"name": {"type": "string", "description": "Autoload name for add/remove_autoload"},
					"path": {"type": "string", "description": "Script path for add_autoload"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "userdata_maintenance",
			"description": "USERDATA MAINTENANCE: Manually inspect or clean legacy Godot MCP files in user://. Actions: ensure_layout creates the current layered directories; cleanup_legacy_cache finds or applies cleanup for old root-level MCP screenshots/logs/events. cleanup_legacy_cache defaults to dry_run=true and must be explicitly run by an Agent/user; plugin startup does not auto-clean.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["ensure_layout", "cleanup_legacy_cache"], "description": "Maintenance action"},
					"dry_run": {"type": "boolean", "description": "Preview cleanup without changing files (default: true)"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "project_run",
			"description": "PROJECT RUN: Launch the project in the Godot editor. Runs the main scene by default; provide scene (.tscn path) to run a specific scene. Recommend checking project_state for compile errors before running. Pair with project_stop. Optional timeout_ms schedules an automatic stop if the run stays open past the timeout.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene": {"type": "string", "description": "Custom scene to run (optional, runs main scene if omitted)"},
					"timeout_ms": {"type": "integer", "description": "Optional auto-stop timeout in milliseconds. If the run is still open when the timeout elapses, the project is stopped automatically."}
				}
			}
		},
		{
			"name": "project_stop",
			"description": "PROJECT STOP: Stop the currently running project in the editor. No parameters. Returns: stopped=true on success.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "runtime_diagnose",
			"description": "RUNTIME DIAGNOSE: Full error report with stacktraces — use when project_state shows error_count > 0 or compile_error_count > 0. Returns: has_errors, runtime_errors[]{message, script, line, stacktrace}, compile_errors[]{message, source_file, source_line}. Key options: tail (default 20, limits runtime error count), include_gd_errors=true adds GDScript Output panel errors (gd_errors[]{severity, message, file, line}), include_performance=true adds fps/memory snapshot.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"include_compile_errors": {
						"type": "boolean",
						"description": "Include .NET compile errors (default: true)"
					},
					"include_performance": {
						"type": "boolean",
						"description": "Include performance snapshot: FPS, memory, render info (default: false)"
					},
					"tail": {
						"type": "integer",
						"description": "Number of recent runtime errors to include (default: 20)"
					},
					"include_gd_errors": {
						"type": "boolean",
						"description": "Include GDScript errors/warnings from the editor Output panel (default: false)"
					}
				}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "tool: %s" % tool_name)
	match tool_name:
		"project_state":     return _execute_project_state(args)
		"editor_state":      return _execute_editor_state(args)
		"project_configure": return _execute_project_configure(args)
		"project_run":       return _execute_project_run(args)
		"project_stop":      return _execute_project_stop(args)
		"runtime_diagnose":  return _execute_runtime_diagnose(args)
		"userdata_maintenance": return _execute_userdata_maintenance(args)
		_: return bridge.error("Unknown tool: %s" % tool_name)


# --- private helpers ---


func _execute_userdata_maintenance(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"ensure_layout":
			return bridge.success(MCPUserDataPaths.initialize_layout(false), "User data layout ensured")
		"cleanup_legacy_cache":
			var dry_run := bool(args.get("dry_run", true))
			return bridge.success(MCPUserDataPaths.cleanup_legacy_cache(dry_run), "Legacy user data cleanup previewed" if dry_run else "Legacy user data cleanup applied")
		_:
			return bridge.error("Unknown userdata_maintenance action: %s" % action)

func _get_runtime_summary() -> Dictionary:
	return bridge.extract_data(bridge.call_atomic("debug_runtime_bridge", {"action": "get_summary"}))


func _safe_extract_data(result: Dictionary) -> Dictionary:
	if result is Dictionary and bool(result.get("success", false)):
		return bridge.extract_data(result)
	return {}


func _result_error_text(result: Dictionary, fallback: String) -> String:
	if result is Dictionary:
		var message := str(result.get("message", "")).strip_edges()
		if not message.is_empty():
			return message
		var error_code := str(result.get("error", "")).strip_edges()
		if not error_code.is_empty():
			return error_code
	return fallback


func _section_success(data: Dictionary) -> Dictionary:
	var out := {"available": true, "error": ""}
	for key in data.keys():
		out[key] = data[key]
	return out


func _section_failure(fallback: String, result: Dictionary = {}, data: Dictionary = {}) -> Dictionary:
	var out := {
		"available": false,
		"error": _result_error_text(result, fallback)
	}
	for key in data.keys():
		out[key] = data[key]
	return out


func _build_editor_state_section() -> Dictionary:
	var info_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_info"})
	var main_screen_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_main_screen"})
	var focus_context_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_focus_context"})
	var distraction_free_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_distraction_free"})
	var godot_path_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_godot_path"})
	var failed_result := {}
	for result in [info_result, main_screen_result, focus_context_result, distraction_free_result, godot_path_result]:
		if result is Dictionary and not bool(result.get("success", false)):
			failed_result = result
			break
	var info := _safe_extract_data(info_result)
	var main_screen := _safe_extract_data(main_screen_result)
	var focus_context := _safe_extract_data(focus_context_result)
	var distraction_free := _safe_extract_data(distraction_free_result)
	var godot_path := _safe_extract_data(godot_path_result)
	var payload := {
		"godot_version": str(info.get("godot_version", "")),
		"version_string": str(info.get("version_string", "")),
		"os": str(info.get("os", "")),
		"editor_scale": float(info.get("editor_scale", 0.0)),
		"main_screen": str(main_screen.get("current_screen", "")),
		"available_screens": main_screen.get("available", []),
		"focus_context": focus_context,
		"distraction_free": bool(distraction_free.get("enabled", false)),
		"godot_executable_path": str(godot_path.get("godot_executable_path", "")),
		"project_root_path": str(godot_path.get("project_root_path", ""))
	}
	if failed_result is Dictionary and not failed_result.is_empty():
		return _section_failure("Editor status is unavailable.", failed_result, payload)
	return _section_success(payload)


func _build_inspector_state_section() -> Dictionary:
	var edited_result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "get_edited"})
	var selected_property_result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "get_selected_property"})
	var edited := _safe_extract_data(edited_result)
	var selected_property := _safe_extract_data(selected_property_result)
	var payload := {
		"editing": edited.get("editing", null),
		"class": str(edited.get("class", "")),
		"path": str(edited.get("path", "")),
		"name": str(edited.get("name", "")),
		"resource_path": str(edited.get("resource_path", "")),
		"selected_property": str(selected_property.get("selected_path", ""))
	}
	if not bool(edited_result.get("success", false)):
		return _section_failure("Inspector state is unavailable.", edited_result, payload)
	if not bool(selected_property_result.get("success", false)):
		return _section_failure("Inspector property selection is unavailable.", selected_property_result, payload)
	return _section_success(payload)


func _build_filesystem_state_section() -> Dictionary:
	var selected_result: Dictionary = bridge.call_atomic("editor_filesystem", {"action": "get_selected"})
	var current_result: Dictionary = bridge.call_atomic("editor_filesystem", {"action": "get_current_path"})
	var selected := _safe_extract_data(selected_result)
	var current := _safe_extract_data(current_result)
	var payload := {
		"selected_count": int(selected.get("count", 0)),
		"selected_paths": selected.get("paths", []),
		"current_path": str(current.get("current_path", "")),
		"current_directory": str(current.get("current_directory", ""))
	}
	if not bool(selected_result.get("success", false)):
		return _section_failure("Editor filesystem selection is unavailable.", selected_result, payload)
	if not bool(current_result.get("success", false)):
		return _section_failure("Editor filesystem current path is unavailable.", current_result, payload)
	return _section_success(payload)


func _resolve_runtime_control_service():
	if _runtime_context.has("runtime_control_service"):
		return _runtime_context.get("runtime_control_service", null)
	var server = _runtime_context.get("server", null)
	if server != null and server.has_method("get_runtime_control_service"):
		return server.get_runtime_control_service()
	if bridge != null and bridge.has_method("get_runtime_control_service"):
		return bridge.get_runtime_control_service()
	return null


func _build_runtime_control_state_section() -> Dictionary:
	var service = _resolve_runtime_control_service()
	if service == null or not service.has_method("get_status"):
		return _section_failure("Runtime control service is unavailable.", {}, {
			"armed": false,
			"message": "Runtime control service is unavailable."
		})
	var status = service.get_status()
	if status is Dictionary:
		var copied: Dictionary = (status as Dictionary).duplicate(true)
		if not copied.has("available"):
			copied["available"] = true
		if not copied.has("error"):
			copied["error"] = ""
		return copied
	return _section_failure("Runtime control status is unavailable.", {}, {
		"armed": false,
		"message": "Runtime control status is unavailable."
	})


func _build_project_state_summary(args: Dictionary = {}) -> Dictionary:
	var project_info_result: Dictionary = bridge.call_atomic("project_info", {"action": "get_info"})
	var dotnet_result: Dictionary = bridge.call_atomic("project_dotnet", {})
	var runtime_summary_result: Dictionary = bridge.call_atomic("debug_runtime_bridge", {"action": "get_summary"})
	var scene_snapshot_result: Dictionary = bridge.call_atomic("debug_runtime_bridge", {"action": "get_scene_snapshot"})
	var dotnet_build_result: Dictionary = bridge.call_atomic("debug_dotnet", {"action": "build"})
	var failed_result := {}
	for result in [project_info_result, dotnet_result, runtime_summary_result, scene_snapshot_result, dotnet_build_result]:
		if result is Dictionary and not bool(result.get("success", false)):
			failed_result = result
			break
	var dotnet_data: Dictionary = bridge.extract_data(dotnet_result)
	var runtime_summary: Dictionary = bridge.extract_data(runtime_summary_result)
	var scene_snapshot: Dictionary = bridge.extract_data(scene_snapshot_result)
	var dotnet_build_data: Dictionary = bridge.extract_data(dotnet_build_result)
	var state_data := {
		"running": _is_runtime_running(runtime_summary),
		"runtime_bridge_status": str(runtime_summary.get("bridge_status", "unknown")),
		"error_count": int(runtime_summary.get("error_count", 0)),
		"compile_error_count": int(dotnet_build_data.get("error_count", 0)),
		"current_scene": str(scene_snapshot.get("current_scene", scene_snapshot.get("scene", ""))),
		"dotnet_project_count": int(dotnet_data.get("count", 0))
	}
	if failed_result is Dictionary and not failed_result.is_empty():
		return _section_failure("Project state is unavailable.", failed_result, state_data)
	return _section_success({
		"running": bool(state_data.get("running", false)),
		"runtime_bridge_status": str(state_data.get("runtime_bridge_status", "unknown")),
		"error_count": int(state_data.get("error_count", 0)),
		"compile_error_count": int(state_data.get("compile_error_count", 0)),
		"current_scene": str(state_data.get("current_scene", "")),
		"dotnet_project_count": int(state_data.get("dotnet_project_count", 0))
	})


func _get_runtime_errors(limit: int) -> Array:
	return bridge.extract_array(bridge.call_atomic("debug_runtime_bridge", {
		"action": "get_errors_context", "limit": limit
	}), "errors")


func _get_runtime_warnings(limit: int) -> Array:
	var result: Dictionary = bridge.call_atomic("debug_runtime_bridge", {
		"action": "get_recent_filtered",
		"level": "warning",
		"tail": limit,
		"limit": max(limit * 4, 20)
	})
	var events: Array = bridge.extract_array(result, "events")
	var warnings: Array = []
	for event in events:
		if not (event is Dictionary):
			continue
		var payload = event.get("payload", {})
		if not (payload is Dictionary):
			payload = {}
		warnings.append({
			"timestamp": str(event.get("timestamp_text", "")),
			"message": str((payload as Dictionary).get("message", "")),
			"source": str((payload as Dictionary).get("source", (payload as Dictionary).get("script", "")))
		})
	return warnings


func _get_lsp_runtime_health_summary() -> Dictionary:
	var summary: Dictionary = {
		"enabled": false,
		"available": false,
		"last_state": "unavailable",
		"last_error": ""
	}
	if bridge == null or not bridge.has_method("get_tool_loader"):
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	var loader = bridge.get_tool_loader()
	if loader == null:
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	summary["enabled"] = loader.has_method("get_gdscript_lsp_diagnostics_service")
	if not loader.has_method("get_lsp_diagnostics_debug_snapshot"):
		summary["last_error"] = "LSP diagnostics snapshot is unavailable"
		return summary
	var snapshot_raw = loader.get_lsp_diagnostics_debug_snapshot()
	if not (snapshot_raw is Dictionary):
		summary["last_error"] = "LSP diagnostics snapshot is unavailable"
		return summary
	var snapshot: Dictionary = snapshot_raw
	var service_snapshot_raw = snapshot.get("service", {})
	if not (service_snapshot_raw is Dictionary):
		summary["last_error"] = "LSP diagnostics service snapshot is unavailable"
		return summary
	var service_snapshot: Dictionary = service_snapshot_raw
	var current_status_raw = service_snapshot.get("status", {})
	var current_status: Dictionary = current_status_raw if current_status_raw is Dictionary else {}
	var last_completed_raw = service_snapshot.get("last_completed_status", {})
	var last_completed: Dictionary = last_completed_raw if last_completed_raw is Dictionary else {}
	var source_status := current_status if not current_status.is_empty() else last_completed
	summary["available"] = bool(snapshot.get("service_available", false))
	summary["last_state"] = str(source_status.get("phase", source_status.get("state", "idle")))
	summary["last_error"] = str(source_status.get("error", last_completed.get("error", "")))
	return summary


func _get_tool_loader_health_summary() -> Dictionary:
	var summary: Dictionary = {
		"enabled": false,
		"available": false,
		"status": "unavailable",
		"tool_count": 0,
		"exposed_tool_count": 0,
		"last_error": ""
	}
	if bridge == null or not bridge.has_method("get_tool_loader"):
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	var loader = bridge.get_tool_loader()
	if loader == null:
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	summary["enabled"] = loader.has_method("get_tool_loader_status")
	if not loader.has_method("get_tool_loader_status"):
		summary["last_error"] = "Tool loader status is unavailable"
		return summary
	var status_raw = loader.get_tool_loader_status()
	if not (status_raw is Dictionary):
		summary["last_error"] = "Tool loader status is unavailable"
		return summary
	var status: Dictionary = status_raw
	summary["available"] = true
	summary["status"] = str(status.get("status", "unknown"))
	summary["tool_count"] = int(status.get("tool_count", 0))
	summary["exposed_tool_count"] = int(status.get("exposed_tool_count", 0))
	summary["last_error"] = ""
	return summary


func _get_self_diagnostics_health_summary() -> Dictionary:
	return PluginSelfDiagnosticStore.get_health_snapshot({
		"tool_loader": _get_tool_loader_health_summary()
	}, 3)


func _is_runtime_running(summary: Dictionary) -> bool:
	var sessions = summary.get("sessions", {})
	if sessions is Dictionary:
		for session_id in (sessions as Dictionary).keys():
			var session = (sessions as Dictionary).get(session_id, {})
			if session is Dictionary and str((session as Dictionary).get("state", "")) in ["started", "running"]:
				return true
	elif sessions is Array:
		for session in sessions:
			if session is Dictionary and str((session as Dictionary).get("state", "")) in ["started", "running"]:
				return true
	return false


# --- tool implementations ---

func _execute_project_state(args: Dictionary) -> Dictionary:
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
			"self_diagnostics": _get_self_diagnostics_health_summary(),
			"lsp_diagnostics": _get_lsp_runtime_health_summary(),
			"tool_loader": _get_tool_loader_health_summary()
		}
	return bridge.success(result_data)


func _execute_editor_state(_args: Dictionary) -> Dictionary:
	var result_data := {
		"editor": _build_editor_state_section(),
		"inspector": _build_inspector_state_section(),
		"filesystem": _build_filesystem_state_section(),
		"project": _build_project_state_summary(),
		"runtime_control": _build_runtime_control_state_section()
	}
	return bridge.success(result_data, "Editor state snapshot fetched")


func _execute_project_configure(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	var setting := str(args.get("setting", "")).strip_edges()
	match action:
		"get_settings":
			if setting.is_empty():
				return bridge.error("setting path is required for get_settings")
			return bridge.call_atomic("project_info", {"action": "get_settings", "setting": setting})
		"set_setting":
			if setting.is_empty():
				return bridge.error("setting path is required for set_setting")
			return bridge.call_atomic("project_settings", {"action": "set", "setting": setting, "value": args.get("value", null)})
		"list_autoloads":
			return bridge.call_atomic("project_autoload", {"action": "list"})
		"add_autoload":
			return bridge.call_atomic("project_autoload", {
				"action": "add",
				"name": str(args.get("name", "")),
				"path": str(args.get("path", ""))
			})
		"remove_autoload":
			return bridge.call_atomic("project_autoload", {
				"action": "remove",
				"name": str(args.get("name", ""))
			})
		"list_input_actions":
			return bridge.call_atomic("project_input", {"action": "list_actions"})
		_:
			return bridge.error("Unknown action: %s. Valid: get_settings, set_setting, list_autoloads, add_autoload, remove_autoload, list_input_actions" % action)


func _execute_project_run(args: Dictionary) -> Dictionary:
	var custom_scene := str(args.get("scene", "")).strip_edges()
	var timeout_ms := int(args.get("timeout_ms", 0))
	MCPDebugBuffer.record("debug", "system",
		"project_run: scene=%s" % (custom_scene if not custom_scene.is_empty() else "main"))
	var run_result: Dictionary
	if custom_scene.is_empty():
		run_result = bridge.call_atomic("scene_run", {"action": "play_main"})
	else:
		run_result = bridge.call_atomic("scene_run", {"action": "play_custom", "path": custom_scene})
	if not bool(run_result.get("success", false)):
		MCPDebugBuffer.record("warning", "system",
			"project_run failed: %s" % str(run_result.get("error", "unknown")))
		return bridge.error("Failed to start project: %s" % str(run_result.get("error", "unknown")))
	var auto_stop_enabled := timeout_ms > 0
	if auto_stop_enabled:
		_schedule_project_auto_stop(timeout_ms, custom_scene if not custom_scene.is_empty() else "main")
	else:
		_project_run_timeout_token += 1
	return bridge.success({
		"started": true,
		"scene": custom_scene if not custom_scene.is_empty() else "main",
		"auto_stop_scheduled": auto_stop_enabled,
		"timeout_ms": timeout_ms if auto_stop_enabled else 0
	}, str(run_result.get("message", "Project started")))


func _execute_project_stop(_args: Dictionary) -> Dictionary:
	_project_run_timeout_token += 1
	MCPDebugBuffer.record("debug", "system", "project_stop: stopping project")
	var stop_result: Dictionary = bridge.call_atomic("scene_run", {"action": "stop"})
	if not bool(stop_result.get("success", false)):
		MCPDebugBuffer.record("warning", "system",
			"project_stop failed: %s" % str(stop_result.get("error", "unknown")))
		return bridge.error("Failed to stop project: %s" % str(stop_result.get("error", "unknown")))
	return bridge.success({"stopped": true}, "Project stopped")


func _execute_runtime_diagnose(args: Dictionary) -> Dictionary:
	var include_compile_errors := bool(args.get("include_compile_errors", true))
	var include_performance := bool(args.get("include_performance", false))
	var include_gd_errors := bool(args.get("include_gd_errors", false))
	var tail := max(int(args.get("tail", 20)), 1)

	var runtime_errors_raw: Array = bridge.extract_array(
		bridge.call_atomic("debug_runtime_bridge", {"action": "get_errors_context", "limit": tail}),
		"errors"
	)
	var runtime_errors: Array = []
	for raw in runtime_errors_raw:
		if not (raw is Dictionary):
			continue
		runtime_errors.append({
			"timestamp": str((raw as Dictionary).get("timestamp_text", (raw as Dictionary).get("timestamp", ""))),
			"error_type": str((raw as Dictionary).get("error_type", "error")),
			"message": str((raw as Dictionary).get("message", "")),
			"script": str((raw as Dictionary).get("script", "")),
			"line": int((raw as Dictionary).get("line", 0)),
			"node": str((raw as Dictionary).get("node", "")),
			"stacktrace": (raw as Dictionary).get("stacktrace", [])
		})

	var compile_errors: Array = []
	var compile_error_count := 0
	if include_compile_errors:
		var dotnet_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_dotnet", {"action": "build"}))
		compile_error_count = int(dotnet_data.get("error_count", 0))
		for raw in dotnet_data.get("errors", []):
			if not (raw is Dictionary):
				continue
			compile_errors.append({
				"severity": str((raw as Dictionary).get("severity", "error")),
				"code": str((raw as Dictionary).get("code", "")),
				"message": str((raw as Dictionary).get("message", "")),
				"source_file": str((raw as Dictionary).get("source_file", "")),
				"source_path": str((raw as Dictionary).get("source_path", "")),
				"source_line": int((raw as Dictionary).get("source_line", 0))
			})

	var performance: Dictionary = {}
	if include_performance:
		var fps_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_performance", {"action": "get_fps"}))
		var mem_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_performance", {"action": "get_memory"}))
		var render_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_performance", {"action": "get_render_info"}))
		performance = {"fps": fps_data, "memory": mem_data, "render": render_data}

	var gd_errors: Array = []
	var gd_error_count := 0
	if include_gd_errors:
		var el_result: Dictionary = bridge.call_atomic("debug_editor_log", {"action": "get_errors", "limit": 50})
		if bool(el_result.get("success", false)):
			var el_data: Dictionary = bridge.extract_data(el_result)
			gd_error_count = int(el_data.get("error_count", 0))
			for raw in el_data.get("errors", []):
				if raw is Dictionary:
					gd_errors.append(raw)

	var result_data: Dictionary = {
		"has_errors": not runtime_errors.is_empty() or compile_error_count > 0 or gd_error_count > 0,
		"runtime_error_count": runtime_errors.size(),
		"runtime_errors": runtime_errors,
		"compile_error_count": compile_error_count,
		"compile_errors": compile_errors,
		"performance": performance
	}
	if include_gd_errors:
		result_data["gd_error_count"] = gd_error_count
		result_data["gd_errors"] = gd_errors
	return bridge.success(result_data)


func _schedule_project_auto_stop(timeout_ms: int, scene_label: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		MCPDebugBuffer.record("warning", "system", "project_run auto-stop skipped: SceneTree unavailable")
		return
	_project_run_timeout_token += 1
	var token := _project_run_timeout_token
	var timer: SceneTreeTimer = tree.create_timer(float(timeout_ms) / 1000.0)
	timer.timeout.connect(Callable(self, "_on_project_run_timeout").bind(token, scene_label, timeout_ms), CONNECT_ONE_SHOT)


func _on_project_run_timeout(token: int, scene_label: String, timeout_ms: int) -> void:
	if token != _project_run_timeout_token:
		return
	if bridge == null:
		return
	MCPDebugBuffer.record("info", "system", "project_run auto-stop: scene=%s timeout_ms=%d" % [scene_label, timeout_ms])
	bridge.call_atomic("scene_run", {"action": "stop"})
