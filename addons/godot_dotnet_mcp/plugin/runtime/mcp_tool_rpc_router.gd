@tool
extends RefCounted
class_name MCPToolRpcRouter

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _get_tool_loader := Callable()
var _is_tool_enabled := Callable()
var _is_tool_exposed := Callable()
var _log := Callable()
var _sanitize_for_json := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_get_tool_loader = callbacks.get("get_tool_loader", Callable())
	_is_tool_enabled = callbacks.get("is_tool_enabled", Callable())
	_is_tool_exposed = callbacks.get("is_tool_exposed", Callable())
	_log = callbacks.get("log", Callable())
	_sanitize_for_json = callbacks.get("sanitize_for_json", Callable())


func build_tools_list_result() -> Dictionary:
	var tools_list: Array[Dictionary] = []
	var loader = _get_loader()
	if loader == null:
		return {"tools": tools_list}

	for tool_def in loader.get_exposed_tool_definitions():
		tools_list.append({
			"name": tool_def["name"],
			"description": tool_def.get("description", ""),
			"category": tool_def.get("category", ""),
			"domainKey": tool_def.get("domain_key", "other"),
			"loadState": tool_def.get("load_state", "definitions_only"),
			"source": tool_def.get("source", "builtin"),
			"enabled": bool(tool_def.get("enabled", true)),
			"inputSchema": tool_def.get("inputSchema", {
				"type": "object",
				"properties": {}
			})
		})

	return {"tools": tools_list}


func build_tool_call_result(params: Dictionary) -> Dictionary:
	var tool_name = params.get("name", "")
	var arguments = params.get("arguments", {})

	_log_message("Tool call: %s" % tool_name, "debug")

	if tool_name.is_empty():
		return _create_tool_result_payload({"success": false, "error": "Missing tool name"})

	if not _call_bool(_is_tool_enabled, [tool_name], false):
		return _create_tool_result_payload({"success": false, "error": "Tool '%s' is disabled" % tool_name})
	if not _call_bool(_is_tool_exposed, [tool_name], false):
		return _create_tool_result_payload({"success": false, "error": "Tool '%s' is not exposed" % tool_name})

	var resolved = _resolve_tool_call_name(tool_name)
	if not bool(resolved.get("success", false)):
		return _create_tool_result_payload({"success": false, "error": "Invalid tool name format: %s" % tool_name})

	var category = str(resolved.get("category", ""))
	var actual_tool_name = str(resolved.get("tool", ""))
	_log_message("Category: %s, Tool: %s" % [category, actual_tool_name], "debug")

	var loader = _get_loader()
	if loader == null:
		return _create_tool_result_payload({"success": false, "error": "Tool loader is unavailable"})

	var result: Dictionary = loader.execute_tool(category, actual_tool_name, arguments)
	result = _normalize_tool_result(result)
	if not result.get("success", false):
		MCPDebugBuffer.record(
			"warning",
			"server",
			"Tool failed: %s — %s" % [tool_name, str(result.get("error", "execution failed"))],
			tool_name,
			{"arguments": _sanitize(arguments)}
		)
	elif tool_name.begins_with("scene_run_"):
		MCPDebugBuffer.record(
			"info",
			"scene_run",
			str(result.get("message", "Scene run action completed")),
			tool_name
		)

	return _create_tool_result_payload(result)


func _resolve_tool_call_name(tool_name: String) -> Dictionary:
	var loader = _get_loader()
	if loader == null:
		return {"success": false}
	for tool_def in loader.get_tool_definitions():
		if str(tool_def.get("name", "")) != tool_name:
			continue
		var exact_category = str(tool_def.get("category", ""))
		if exact_category.is_empty():
			break
		var resolved_tool = tool_name
		var exact_prefix = "%s_" % exact_category
		if tool_name.begins_with(exact_prefix):
			resolved_tool = tool_name.substr(exact_prefix.length())
		return {
			"success": true,
			"category": exact_category,
			"tool": resolved_tool
		}

	var matched_category := ""
	for state in loader.get_domain_states():
		var category = str(state.get("category", ""))
		if category.is_empty():
			continue
		var prefix = "%s_" % category
		if tool_name.begins_with(prefix) and prefix.length() > matched_category.length():
			matched_category = category

	if matched_category.is_empty():
		var parts = tool_name.split("_", true, 1)
		if parts.size() < 2:
			return {"success": false}
		return {
			"success": true,
			"category": parts[0],
			"tool": parts[1]
		}

	return {
		"success": true,
		"category": matched_category,
		"tool": tool_name.substr(matched_category.length() + 1)
	}


func _create_tool_result_payload(result: Dictionary) -> Dictionary:
	var normalized_result = _normalize_tool_result(result)
	var sanitized_result = _sanitize(normalized_result)
	var result_text = JSON.stringify(sanitized_result)
	var is_error = not normalized_result.get("success", false)

	_log_message("Tool response text length: %d, is_error=%s" % [result_text.length(), is_error], "trace")

	return {
		"content": [{
			"type": "text",
			"text": result_text
		}],
		"isError": is_error
	}


func _normalize_tool_result(result) -> Dictionary:
	if not (result is Dictionary):
		return {
			"success": true,
			"data": result,
			"message": ""
		}

	var normalized: Dictionary = result.duplicate(true)
	var is_success = bool(normalized.get("success", true))
	normalized["success"] = is_success

	var reserved_keys = {
		"success": true,
		"data": true,
		"message": true,
		"error": true,
		"hints": true
	}
	var extra_data := {}
	for key in normalized.keys():
		if reserved_keys.has(str(key)):
			continue
		extra_data[str(key)] = normalized[key]

	if is_success:
		if not normalized.has("data"):
			normalized["data"] = extra_data if not extra_data.is_empty() else null
		if not normalized.has("message"):
			normalized["message"] = ""
		normalized.erase("error")
		if normalized.has("hints") and normalized.get("hints", []).is_empty():
			normalized.erase("hints")
	else:
		if not normalized.has("error"):
			normalized["error"] = str(normalized.get("message", "Tool execution failed"))
		normalized.erase("message")
		if not normalized.has("data") and not extra_data.is_empty():
			normalized["data"] = extra_data

	for key in extra_data.keys():
		normalized.erase(key)

	return normalized


func _get_loader():
	if _get_tool_loader.is_valid():
		return _get_tool_loader.call()
	return null


func _sanitize(value):
	if _sanitize_for_json.is_valid():
		return _sanitize_for_json.call(value)
	return value


func _call_bool(callable_obj: Callable, args: Array, default_value: bool) -> bool:
	if callable_obj.is_valid():
		return bool(callable_obj.callv(args))
	return default_value


func _log_message(message: String, level: String) -> void:
	if _log.is_valid():
		_log.call(message, level)
