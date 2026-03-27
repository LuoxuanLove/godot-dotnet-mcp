@tool
extends "res://addons/godot_dotnet_mcp/tools/system/project/service_base.gd"


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"project_run":
			return _execute_project_run(args)
		"project_stop":
			return _execute_project_stop(args)
		"runtime_diagnose":
			return _execute_runtime_diagnose(args)
		_:
			return bridge.error("Unknown tool: %s" % tool_name)


func _execute_project_run(args: Dictionary) -> Dictionary:
	var custom_scene := str(args.get("scene", "")).strip_edges()
	MCPDebugBuffer.record("debug", "system", "project_run: scene=%s" % (custom_scene if not custom_scene.is_empty() else "main"))
	var run_result: Dictionary
	if custom_scene.is_empty():
		run_result = bridge.call_atomic("scene_run", {"action": "play_main"})
	else:
		run_result = bridge.call_atomic("scene_run", {"action": "play_custom", "path": custom_scene})
	if not bool(run_result.get("success", false)):
		MCPDebugBuffer.record("warning", "system", "project_run failed: %s" % str(run_result.get("error", "unknown")))
		return bridge.error("Failed to start project: %s" % str(run_result.get("error", "unknown")))
	return bridge.success({
		"started": true,
		"scene": custom_scene if not custom_scene.is_empty() else "main"
	}, str(run_result.get("message", "Project started")))


func _execute_project_stop(_args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "project_stop: stopping project")
	var stop_result: Dictionary = bridge.call_atomic("scene_run", {"action": "stop"})
	if not bool(stop_result.get("success", false)):
		MCPDebugBuffer.record("warning", "system", "project_stop failed: %s" % str(stop_result.get("error", "unknown")))
		return bridge.error("Failed to stop project: %s" % str(stop_result.get("error", "unknown")))
	return bridge.success({"stopped": true}, "Project stopped")


func _execute_runtime_diagnose(args: Dictionary) -> Dictionary:
	var include_compile_errors := bool(args.get("include_compile_errors", true))
	var include_performance := bool(args.get("include_performance", false))
	var include_gd_errors := bool(args.get("include_gd_errors", false))
	var tail := max(int(args.get("tail", 20)), 1)
	var runtime_errors_raw: Array = bridge.extract_array(bridge.call_atomic("debug_runtime_bridge", {
		"action": "get_errors_context",
		"limit": tail
	}), "errors")
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
		var editor_log_result: Dictionary = bridge.call_atomic("debug_editor_log", {"action": "get_errors", "limit": 50})
		if bool(editor_log_result.get("success", false)):
			var editor_log_data: Dictionary = bridge.extract_data(editor_log_result)
			gd_error_count = int(editor_log_data.get("error_count", 0))
			for raw in editor_log_data.get("errors", []):
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
