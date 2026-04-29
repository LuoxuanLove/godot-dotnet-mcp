extends RefCounted

const DebugExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/debug/executor.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/debug_tools.gd"):
		return _failure("debug_tools.gd should be removed once the split executor becomes the only stable entry.")

	var executor = DebugExecutorScript.new()
	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 8:
		return _failure("Debug executor should expose 8 tool definitions after the split.")

	var expected_names := ["log_write", "log_buffer", "runtime_bridge", "dotnet", "performance", "profiler", "editor_log", "class_db"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Debug executor is missing tool definition '%s'." % expected_name)

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


func _failure(message: String) -> Dictionary:
	return {
		"name": "debug_tool_executor_contracts",
		"success": false,
		"error": message
	}
