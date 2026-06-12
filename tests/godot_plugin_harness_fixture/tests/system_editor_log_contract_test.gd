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
		return _failure("impl_editor.gd should keep the legacy editor_log definition so removed-tool calls can return migration guidance.")
	var editor_control_def := _find_tool_def(tool_defs, "editor_control")
	if editor_control_def.is_empty():
		return _failure("impl_editor.gd should expose editor_control.")
	if not _tool_action_enum(editor_control_def).has("clear_output"):
		return _failure("system editor_control should expose clear_output as the public Output-clearing replacement.")

	var output_result: Dictionary = impl.execute("editor_log", {"action": "get_output", "limit": 12})
	if bool(output_result.get("success", true)):
		return _failure("system editor_log legacy get_output should return removed_public_tool guidance.")
	if not _is_removed_editor_log(output_result):
		return _failure("system editor_log get_output removal guidance should point to editor log resources.")

	var errors_result: Dictionary = impl.execute("editor_log", {"action": "get_errors", "limit": 5, "include_warnings": false})
	if bool(errors_result.get("success", true)):
		return _failure("system editor_log legacy get_errors should return removed_public_tool guidance.")
	if not _is_removed_editor_log(errors_result):
		return _failure("system editor_log get_errors removal guidance should point to editor log resources.")

	var clear_result: Dictionary = impl.execute("editor_log", {"action": "clear_output"})
	if bool(clear_result.get("success", true)):
		return _failure("system editor_log legacy clear_output should return removed_public_tool guidance.")
	if not _is_removed_editor_log(clear_result):
		return _failure("system editor_log clear_output removal guidance should point to editor log resources.")
	var replacement_tools = ((clear_result.get("data", {}) as Dictionary).get("replacement_tools", []) as Array)
	if replacement_tools.is_empty() or str((replacement_tools[0] as Dictionary).get("name", "")) != "system_editor_control":
		return _failure("system editor_log clear_output guidance should point to system_editor_control.")
	var replacement_args: Dictionary = (replacement_tools[0] as Dictionary).get("arguments", {})
	if str(replacement_args.get("action", "")) != "clear_output":
		return _failure("system editor_log clear_output guidance should preserve the clear_output replacement action.")
	var clear_replacement_result: Dictionary = impl.execute("editor_control", {"action": "clear_output"})
	if not bool(clear_replacement_result.get("success", false)):
		return _failure("system editor_control clear_output should delegate to the atomic editor log clear action.")
	if not bool(clear_replacement_result.get("data", {}).get("cleared", false)):
		return _failure("system editor_control clear_output should preserve the cleared flag from the atomic editor_log tool.")

	return {
		"name": "system_editor_log_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"removed_tool": "system_editor_log",
			"replacement_tool": "system_editor_control"
		}
	}


func _find_tool_def(tool_defs: Array[Dictionary], name: String) -> Dictionary:
	for tool_def in tool_defs:
		if str(tool_def.get("name", "")) == name:
			return tool_def
	return {}


func _tool_action_enum(tool_def: Dictionary) -> Array:
	var schema: Dictionary = tool_def.get("inputSchema", {})
	var properties: Dictionary = schema.get("properties", {})
	var action_schema: Dictionary = properties.get("action", {})
	var action_enum = action_schema.get("enum", [])
	return action_enum if action_enum is Array else []


func _is_removed_editor_log(result: Dictionary) -> bool:
	var data = result.get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != "system_editor_log":
		return false
	var replacement_resources = data_dict.get("replacement_resources", [])
	return replacement_resources is Array \
		and (replacement_resources as Array).has("godot-dotnet-mcp://logs/editor/output") \
		and (replacement_resources as Array).has("godot-dotnet-mcp://logs/editor/errors")


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_editor_log_contracts",
		"success": false,
		"error": message
	}
