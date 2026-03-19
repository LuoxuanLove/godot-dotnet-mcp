@tool
extends RefCounted

## Intelligence implementation: project_state, project_advise, project_configure,
## project_run, project_stop, runtime_diagnose

var bridge

const HANDLED_TOOLS := [
	"project_state", "project_advise", "project_configure",
	"project_run", "project_stop", "runtime_diagnose"
]


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
						"description": "Include lightweight plugin runtime health summary, including lsp_diagnostics and tool_loader health (default: false)"
					}
				}
			}
		},
		{
			"name": "project_advise",
			"description": "PROJECT ADVISE: Actionable suggestions and next-tool recommendations based on live project state. Use when you need prioritized action items rather than raw data. Returns: suggestions[]{category, severity, message, tool_hint}, next_tools[]. Optional: goal (e.g. \"fix errors\", \"explore scene\") to refine recommendations.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"goal": {
						"type": "string",
						"description": "Goal context for workflow recommendations (default: general)"
					},
					"include_suggestions": {
						"type": "boolean",
						"description": "Include diagnostic suggestions (default: true)"
					},
					"include_workflow": {
						"type": "boolean",
						"description": "Include workflow next_tools recommendations (default: true)"
					}
				}
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
			"name": "project_run",
			"description": "PROJECT RUN: Launch the project in the Godot editor. Runs the main scene by default; provide scene (.tscn path) to run a specific scene. Recommend checking project_state for compile errors before running. Pair with project_stop.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene": {"type": "string", "description": "Custom scene to run (optional, runs main scene if omitted)"}
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
	MCPDebugBuffer.record("debug", "intelligence", "tool: %s" % tool_name)
	match tool_name:
		"project_state":     return _execute_project_state(args)
		"project_advise":    return _execute_project_advise(args)
		"project_configure": return _execute_project_configure(args)
		"project_run":       return _execute_project_run(args)
		"project_stop":      return _execute_project_stop(args)
		"runtime_diagnose":  return _execute_runtime_diagnose(args)
		_: return bridge.error("Unknown tool: %s" % tool_name)


# --- private helpers ---

func _get_runtime_summary() -> Dictionary:
	return bridge.extract_data(bridge.call_atomic("debug_runtime_bridge", {"action": "get_summary"}))


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


func _goal_contains(goal: String, keywords: Array) -> bool:
	var lowered := goal.to_lower()
	for keyword in keywords:
		if lowered.find(str(keyword).to_lower()) != -1:
			return true
	return false


# --- tool implementations ---

func _execute_project_state(args: Dictionary) -> Dictionary:
	var error_limit := max(int(args.get("error_limit", 10)), 0)
	var include_runtime_health := bool(args.get("include_runtime_health", false))
	MCPDebugBuffer.record("debug", "intelligence", "project_state: collecting stats (error_limit=%d)" % error_limit)
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


func _execute_project_advise(args: Dictionary) -> Dictionary:
	var goal := str(args.get("goal", "general")).strip_edges()
	MCPDebugBuffer.record("debug", "intelligence", "project_advise: goal=%s" % goal)
	var include_suggestions := bool(args.get("include_suggestions", true))
	var include_workflow := bool(args.get("include_workflow", true))
	if goal.is_empty():
		goal = "general"

	var project_info: Dictionary = bridge.extract_data(bridge.call_atomic("project_info", {"action": "get_info"}))
	var dotnet_result: Dictionary = bridge.call_atomic("project_dotnet", {})
	var runtime_summary := _get_runtime_summary()
	var compile_error_count := 0
	if bool(dotnet_result.get("success", false)):
		var de: Dictionary = bridge.extract_data(bridge.call_atomic("debug_dotnet", {"action": "build"}))
		compile_error_count = int(de.get("error_count", 0))

	var gd_count: int = (bridge.collect_files("*.gd") as Array).size()
	var cs_count: int = (bridge.collect_files("*.cs") as Array).size()
	var scene_count_val: int = (bridge.collect_files("*.tscn") as Array).size()

	var error_count := int(runtime_summary.get("error_count", 0))
	var warning_count := int(runtime_summary.get("warning_count", 0))
	var main_scene := str(project_info.get("main_scene", ""))

	var suggestions: Array = []
	var next_tools: Array = []

	if include_suggestions:
		if main_scene.is_empty():
			suggestions.append({"category": "structure", "severity": "error",
				"message": "Project has no configured main scene.", "tool_hint": "project_state"})
		elif not FileAccess.file_exists(main_scene):
			suggestions.append({"category": "structure", "severity": "error",
				"message": "Configured main scene does not exist: %s" % main_scene,
				"tool_hint": "scene_validate"})
		if error_count > 0:
			suggestions.append({"category": "runtime", "severity": "error",
				"message": "Recent runtime errors detected. Diagnose bindings or scene integrity.",
				"tool_hint": "bindings_audit"})
		if cs_count > 0:
			suggestions.append({"category": "dotnet", "severity": "info",
				"message": "Project contains C# scripts. Run bindings_audit to verify consistency.",
				"tool_hint": "bindings_audit"})
		if scene_count_val > 0:
			suggestions.append({"category": "index", "severity": "info",
				"message": "Build the project index to unlock symbol search and dependency navigation.",
				"tool_hint": "project_index_build"})
		if warning_count > 0 and error_count == 0:
			suggestions.append({"category": "runtime", "severity": "warning",
				"message": "Recent runtime warnings detected. Review scene setup before patching.",
				"tool_hint": "scene_validate"})
		if compile_error_count > 0:
			suggestions.append({"category": "dotnet", "severity": "error",
				"message": "C# compile errors detected (%d). Fix before running." % compile_error_count,
				"tool_hint": "runtime_diagnose"})

	if include_workflow:
		next_tools.append("project_state")
		if error_count > 0 or compile_error_count > 0:
			next_tools.append("runtime_diagnose")
			next_tools.append("bindings_audit")
			next_tools.append("scene_validate")
		if _goal_contains(goal, ["symbol", "index", "search", "class"]):
			if not ("project_index_build" in next_tools):
				next_tools.append("project_index_build")
			if not ("project_symbol_search" in next_tools):
				next_tools.append("project_symbol_search")
		if _goal_contains(goal, ["scene", "dependency"]):
			if not ("scene_dependency_graph" in next_tools):
				next_tools.append("scene_dependency_graph")
		if cs_count > 0 and not _goal_contains(goal, ["symbol", "index", "search"]):
			if not ("bindings_audit" in next_tools):
				next_tools.append("bindings_audit")
		if not ("project_advise" in next_tools):
			next_tools.append("project_advise")

	var has_issues := false
	for s in suggestions:
		if s is Dictionary and str((s as Dictionary).get("severity", "")) in ["error", "warning"]:
			has_issues = true
			break

	return bridge.success({
		"goal": goal,
		"has_issues": has_issues,
		"suggestion_count": suggestions.size(),
		"suggestions": suggestions,
		"next_tools": next_tools
	})


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
	MCPDebugBuffer.record("debug", "intelligence",
		"project_run: scene=%s" % (custom_scene if not custom_scene.is_empty() else "main"))
	var run_result: Dictionary
	if custom_scene.is_empty():
		run_result = bridge.call_atomic("scene_run", {"action": "play_main"})
	else:
		run_result = bridge.call_atomic("scene_run", {"action": "play_custom", "path": custom_scene})
	if not bool(run_result.get("success", false)):
		MCPDebugBuffer.record("warning", "intelligence",
			"project_run failed: %s" % str(run_result.get("error", "unknown")))
		return bridge.error("Failed to start project: %s" % str(run_result.get("error", "unknown")))
	return bridge.success({
		"started": true,
		"scene": custom_scene if not custom_scene.is_empty() else "main"
	}, str(run_result.get("message", "Project started")))


func _execute_project_stop(_args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "intelligence", "project_stop: stopping project")
	var stop_result: Dictionary = bridge.call_atomic("scene_run", {"action": "stop"})
	if not bool(stop_result.get("success", false)):
		MCPDebugBuffer.record("warning", "intelligence",
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
