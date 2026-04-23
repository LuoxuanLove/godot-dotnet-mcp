extends RefCounted

const SystemEditorImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_editor.gd")


class FakeBridge extends RefCounted:
	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		match tool_name:
			"debug_editor_log":
				match str(args.get("action", "")):
					"get_output":
						return success({"line_count": int(args.get("limit", 0)), "lines": ["a", "b"]})
					"get_errors":
						return success({"error_count": 1, "errors": [{"severity": "warning", "message": "warn"}], "include_warnings": bool(args.get("include_warnings", true))})
					"clear":
						return success({"cleared": true})
					_:
						return error("Unsupported editor_log action")
			_:
				return success({})

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String) -> Dictionary:
		return {"success": false, "error": "bridge_error", "message": message}


func run_case(_tree: SceneTree) -> Dictionary:
	var impl = SystemEditorImplScript.new()
	impl.bridge = FakeBridge.new()

	var tool_defs: Array[Dictionary] = impl.get_tools()
	var tool_names: Array[String] = []
	for tool_def in tool_defs:
		tool_names.append(str(tool_def.get("name", "")))
	if not tool_names.has("editor_log"):
		return _failure("impl_editor.gd should expose the high-level editor_log system tool.")

	var output_result: Dictionary = impl.execute("editor_log", {"action": "get_output", "limit": 12})
	if not bool(output_result.get("success", false)):
		return _failure("system editor_log should delegate get_output.")
	if int(output_result.get("data", {}).get("line_count", 0)) != 12:
		return _failure("system editor_log should preserve the requested output limit payload.")

	var errors_result: Dictionary = impl.execute("editor_log", {"action": "get_errors", "limit": 5, "include_warnings": false})
	if not bool(errors_result.get("success", false)):
		return _failure("system editor_log should delegate get_errors.")
	if bool(errors_result.get("data", {}).get("include_warnings", true)):
		return _failure("system editor_log should forward include_warnings to the atomic editor_log tool.")

	var clear_result: Dictionary = impl.execute("editor_log", {"action": "clear_output"})
	if not bool(clear_result.get("success", false)):
		return _failure("system editor_log should delegate clear_output.")
	if not bool(clear_result.get("data", {}).get("cleared", false)):
		return _failure("system editor_log should preserve the cleared flag from the atomic editor_log tool.")

	return {
		"name": "system_editor_log_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"line_count": int(output_result.get("data", {}).get("line_count", 0)),
			"error_count": int(errors_result.get("data", {}).get("error_count", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_editor_log_contracts",
		"success": false,
		"error": message
	}
