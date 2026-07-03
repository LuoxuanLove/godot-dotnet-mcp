@tool
extends RefCounted
class_name MCPToolRpcRouter

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPToolActivityRegistry = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")
const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")
const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")

const SERIAL_EDITOR_AUTOMATION_TOOLS := [
	"system_editor_state",
	"system_editor_control",
	"system_editor_evidence",
	"system_inspector",
	"system_settings_dialog"
]
const DEFAULT_EDITOR_AUTOMATION_STALE_TIMEOUT_MS := 10000
const DEFAULT_TOOL_CALL_TIMEOUT_MS := 60000
const MIN_TOOL_CALL_TIMEOUT_MS := 100
const ENV_TOOL_CALL_TIMEOUT_MS := "GODOT_DOTNET_MCP_TOOL_CALL_TIMEOUT_MS"
const ENV_EDITOR_AUTOMATION_STALE_TIMEOUT_MS := "GODOT_DOTNET_MCP_EDITOR_AUTOMATION_STALE_TIMEOUT_MS"


class ToolCallTask:
	extends RefCounted

	var _loader = null
	var _category := ""
	var _tool_name := ""
	var _arguments: Dictionary = {}
	var _owner_id := 0
	var _task_id := 0
	var completed := false
	var result = null

	func start(owner, task_id: int, loader, category: String, tool_name: String, arguments: Dictionary) -> void:
		_owner_id = owner.get_instance_id() if owner != null and is_instance_valid(owner) else 0
		_task_id = task_id
		_loader = loader
		_category = category
		_tool_name = tool_name
		_arguments = arguments.duplicate(true)
		call_deferred("_run")

	func _run() -> void:
		if _loader == null:
			result = {"success": false, "error": "Tool loader is unavailable"}
			completed = true
			_notify_owner()
			return
		result = await _loader.execute_tool_async(_category, _tool_name, _arguments)
		completed = true
		_notify_owner()

	func _notify_owner() -> void:
		var owner = instance_from_id(_owner_id) if _owner_id != 0 else null
		_owner_id = 0
		_loader = null
		if owner != null and owner.has_method("_complete_tool_call_task"):
			owner._complete_tool_call_task(_task_id)

	func release_owner() -> void:
		_owner_id = 0
		_loader = null


var _get_tool_loader := Callable()
var _is_tool_enabled := Callable()
var _is_tool_exposed := Callable()
var _log := Callable()
var _sanitize_for_json := Callable()
var _ensure_initialized := Callable()
var _active_editor_automation_tool := ""
var _active_editor_automation_started_msec := 0
var _active_editor_automation_token := 0
var _editor_automation_generation := 0
var _tool_call_timeout_ms := DEFAULT_TOOL_CALL_TIMEOUT_MS
var _editor_automation_stale_timeout_ms := DEFAULT_EDITOR_AUTOMATION_STALE_TIMEOUT_MS
var _active_tool_call_tasks: Dictionary = {}
var _tool_call_task_sequence := 0


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_get_tool_loader = context.get_tool_loader
	_is_tool_enabled = context.is_tool_enabled
	_is_tool_exposed = context.is_tool_exposed
	_log = context.log
	_sanitize_for_json = context.sanitize_for_json
	_ensure_initialized = context.ensure_initialized
	_tool_call_timeout_ms = _resolve_timeout_ms(context.tool_call_timeout_ms, ENV_TOOL_CALL_TIMEOUT_MS, DEFAULT_TOOL_CALL_TIMEOUT_MS, MIN_TOOL_CALL_TIMEOUT_MS)
	_editor_automation_stale_timeout_ms = _resolve_timeout_ms(-1, ENV_EDITOR_AUTOMATION_STALE_TIMEOUT_MS, DEFAULT_EDITOR_AUTOMATION_STALE_TIMEOUT_MS, MIN_TOOL_CALL_TIMEOUT_MS)


func dispose() -> void:
	_get_tool_loader = Callable()
	_is_tool_enabled = Callable()
	_is_tool_exposed = Callable()
	_log = Callable()
	_sanitize_for_json = Callable()
	_ensure_initialized = Callable()
	_active_editor_automation_tool = ""
	_active_editor_automation_started_msec = 0
	_active_editor_automation_token = 0
	_editor_automation_generation = 0
	_tool_call_timeout_ms = DEFAULT_TOOL_CALL_TIMEOUT_MS
	_editor_automation_stale_timeout_ms = DEFAULT_EDITOR_AUTOMATION_STALE_TIMEOUT_MS
	_release_tool_call_tasks()
	_tool_call_task_sequence = 0


func build_tools_list_result() -> Dictionary:
	_ensure_tool_runtime_initialized()
	var loader = _get_loader()
	if loader == null:
		return {"tools": []}

	var exposed_tools = loader.get_exposed_tool_definitions()
	return {
		"tools": ToolPresentationService.build_mcp_tool_list(exposed_tools)
	}


func build_tool_call_result(params: Dictionary) -> Dictionary:
	return await build_tool_call_result_async(params)


func build_tool_call_result_async(params: Dictionary) -> Dictionary:
	var raw_tool_name = params.get("name", "")
	var tool_name_type := typeof(raw_tool_name)
	if tool_name_type != TYPE_STRING and tool_name_type != TYPE_STRING_NAME:
		return _create_tool_result_payload({"success": false, "error": "Tool name must be a string"})
	var tool_name := str(raw_tool_name)
	var arguments = params.get("arguments", {})
	if params.has("arguments") and not (arguments is Dictionary):
		return _create_tool_result_payload({"success": false, "error": "Tool arguments must be an object"})
	arguments = (arguments as Dictionary).duplicate(true)
	_merge_agent_context(params, arguments)

	_log_message("Tool call: %s" % tool_name, "debug")

	if tool_name.is_empty():
		return _create_tool_result_payload({"success": false, "error": "Missing tool name"})
	if not ToolCatalogManifest.is_valid_mcp_tool_name(tool_name):
		return _create_tool_result_payload({
			"success": false,
			"error": "Invalid tool name format: %s" % tool_name,
			"data": {
				"error_type": "invalid_tool_name",
				"tool_name": tool_name
			}
		})

	_ensure_tool_runtime_initialized()
	var loader = _get_loader()
	if loader == null:
		return _create_tool_result_payload({"success": false, "error": "Tool loader is unavailable"})
	var include_structured_content := _tool_has_output_schema(loader, tool_name)
	if loader.has_method("is_public_removed_tool") and bool(loader.is_public_removed_tool(tool_name)):
		if loader.has_method("build_removed_public_tool_result"):
			var removed_tool_result = loader.build_removed_public_tool_result(tool_name, arguments)
			if removed_tool_result is Dictionary and not (removed_tool_result as Dictionary).is_empty():
				return _create_tool_result_payload(removed_tool_result, include_structured_content)

	if not _call_bool(_is_tool_enabled, [tool_name], false):
		return _create_tool_result_payload({"success": false, "error": "Tool '%s' is disabled" % tool_name}, include_structured_content)
	if not _call_bool(_is_tool_exposed, [tool_name], false):
		return _create_tool_result_payload({"success": false, "error": "Tool '%s' is not exposed" % tool_name}, include_structured_content)

	var resolved = _resolve_tool_call_name(tool_name)
	if not bool(resolved.get("success", false)):
		return _create_tool_result_payload({"success": false, "error": "Invalid tool name format: %s" % tool_name}, include_structured_content)

	var category = str(resolved.get("category", ""))
	var actual_tool_name = str(resolved.get("tool", ""))
	_log_message("Category: %s, Tool: %s" % [category, actual_tool_name], "debug")

	var automation_guard := _begin_editor_automation_call(tool_name)
	if not bool(automation_guard.get("success", false)):
		return _create_tool_result_payload(automation_guard, include_structured_content)

	var raw_result = await _execute_tool_with_timeout_async(loader, category, actual_tool_name, arguments, tool_name, automation_guard)
	_end_editor_automation_call(automation_guard)
	var result: Dictionary = _normalize_tool_result(raw_result)
	if not result.get("success", false):
		var logged_arguments: Dictionary = arguments.duplicate(true)
		logged_arguments.erase("_mcp_context")
		MCPDebugBuffer.record(
			"warning",
			"server",
			"Tool failed: %s — %s" % [tool_name, str(result.get("error", "execution failed"))],
			tool_name,
			{"arguments": _sanitize(logged_arguments)}
		)
	elif tool_name.begins_with("scene_run_"):
		MCPDebugBuffer.record(
			"info",
			"scene_run",
			str(result.get("message", "Scene run action completed")),
			tool_name
		)

	return _create_tool_result_payload(result, include_structured_content)


func _execute_tool_with_timeout_async(loader, category: String, actual_tool_name: String, arguments: Dictionary, public_tool_name: String, automation_guard: Dictionary):
	if _tool_call_timeout_ms <= 0 or _is_editor_automation_guard_acquired(automation_guard):
		return await loader.execute_tool_async(category, actual_tool_name, arguments)
	var tree = Engine.get_main_loop()
	if not (tree is SceneTree):
		return await loader.execute_tool_async(category, actual_tool_name, arguments)
	var task := ToolCallTask.new()
	_tool_call_task_sequence += 1
	var task_id := _tool_call_task_sequence
	_active_tool_call_tasks[task_id] = task
	task.start(self, task_id, loader, category, actual_tool_name, arguments)
	var started_msec := Time.get_ticks_msec()
	while not task.completed:
		if Time.get_ticks_msec() - started_msec >= _tool_call_timeout_ms:
			return {
				"success": false,
				"error": "Tool '%s' timed out after %dms" % [public_tool_name, _tool_call_timeout_ms],
				"data": {
					"error_type": "tool_call_timeout",
					"tool_name": public_tool_name,
					"timeout_ms": _tool_call_timeout_ms
				}
			}
		await (tree as SceneTree).process_frame
	_active_tool_call_tasks.erase(task_id)
	return task.result


func _begin_editor_automation_call(tool_name: String) -> Dictionary:
	if not SERIAL_EDITOR_AUTOMATION_TOOLS.has(tool_name):
		return {"success": true, "acquired": false}

	_clear_stale_editor_automation_if_needed()
	if not _active_editor_automation_tool.is_empty():
		var elapsed_ms := Time.get_ticks_msec() - _active_editor_automation_started_msec
		return {
			"success": false,
			"error": "Editor automation is already processing %s; retry after it completes." % _active_editor_automation_tool,
			"data": {
				"error_type": "editor_automation_busy",
				"active_tool": _active_editor_automation_tool,
				"requested_tool": tool_name,
				"elapsed_ms": elapsed_ms,
				"retry_after_ms": 250,
				"stale_timeout_ms": _editor_automation_stale_timeout_ms
			},
			"hints": [
				"Editor UI automation is serialized to keep the Godot editor responsive.",
				"Retry the request after the active editor automation call finishes."
			]
		}

	_editor_automation_generation += 1
	_active_editor_automation_tool = tool_name
	_active_editor_automation_started_msec = Time.get_ticks_msec()
	_active_editor_automation_token = _editor_automation_generation
	call_deferred("_watch_editor_automation_guard", _active_editor_automation_token, tool_name)
	return {
		"success": true,
		"acquired": true,
		"tool": tool_name,
		"token": _active_editor_automation_token
	}


func _end_editor_automation_call(guard: Dictionary) -> void:
	if not bool(guard.get("acquired", false)):
		return
	var token := int(guard.get("token", 0))
	if token != _active_editor_automation_token:
		return
	_clear_editor_automation_guard()


func _watch_editor_automation_guard(token: int, tool_name: String) -> void:
	var tree = Engine.get_main_loop()
	if not (tree is SceneTree):
		return
	var started_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec < _editor_automation_stale_timeout_ms:
		if token != _active_editor_automation_token:
			return
		if _active_editor_automation_tool != tool_name:
			return
		await (tree as SceneTree).process_frame
	if token != _active_editor_automation_token:
		return
	if _active_editor_automation_tool != tool_name:
		return
	MCPDebugBuffer.record(
		"warning",
		"server",
		"Cleared stale editor automation guard for %s after watchdog timeout %dms" % [tool_name, _editor_automation_stale_timeout_ms],
		tool_name
	)
	_clear_editor_automation_guard()


func _clear_stale_editor_automation_if_needed() -> void:
	if _active_editor_automation_tool.is_empty():
		return
	var elapsed_ms := Time.get_ticks_msec() - _active_editor_automation_started_msec
	if elapsed_ms < _editor_automation_stale_timeout_ms:
		return
	MCPDebugBuffer.record(
		"warning",
		"server",
		"Cleared stale editor automation guard for %s after %dms" % [_active_editor_automation_tool, elapsed_ms],
		_active_editor_automation_tool
	)
	_clear_editor_automation_guard()


func _clear_editor_automation_guard() -> void:
	_active_editor_automation_tool = ""
	_active_editor_automation_started_msec = 0
	_active_editor_automation_token = 0


func _is_editor_automation_guard_acquired(guard: Dictionary) -> bool:
	return bool(guard.get("acquired", false))


func _merge_agent_context(params: Dictionary, arguments: Dictionary) -> void:
	if arguments.has("_mcp_context"):
		return
	if params.get("_mcp_context", null) is Dictionary:
		arguments["_mcp_context"] = (params.get("_mcp_context", {}) as Dictionary).duplicate(true)


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


func _create_tool_result_payload(result: Dictionary, include_structured_content: bool = false) -> Dictionary:
	var normalized_result = _normalize_tool_result(result)
	var sanitized_result = _sanitize(normalized_result)
	var result_text = JSON.stringify(sanitized_result)
	var is_error = not normalized_result.get("success", false)

	_log_message("Tool response text length: %d, is_error=%s" % [result_text.length(), is_error], "debug")

	var payload := {
		"content": [{
			"type": "text",
			"text": result_text
		}],
		"isError": is_error
	}
	if include_structured_content:
		payload["structuredContent"] = sanitized_result
	return payload


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
	if MCPToolActivityRegistry.is_protocol_activity_summary(normalized.get("activity", null)):
		reserved_keys["activity"] = true
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


func _ensure_tool_runtime_initialized() -> void:
	if _ensure_initialized.is_valid():
		_ensure_initialized.call()


func _sanitize(value):
	if _sanitize_for_json.is_valid():
		return _sanitize_for_json.call(value)
	return value


func _call_bool(callable_obj: Callable, args: Array, default_value: bool) -> bool:
	if callable_obj.is_valid():
		return bool(callable_obj.callv(args))
	return default_value


func _tool_has_output_schema(loader, tool_name: String) -> bool:
	if loader == null or not loader.has_method("get_tool_definitions"):
		return false
	for tool_def in loader.get_tool_definitions():
		if not (tool_def is Dictionary):
			continue
		var def_dict := tool_def as Dictionary
		var full_name := str(def_dict.get("full_name", def_dict.get("name", "")))
		if full_name != tool_name:
			continue
		var output_schema = def_dict.get("outputSchema", null)
		return output_schema is Dictionary and not (output_schema as Dictionary).is_empty()
	return false


func _resolve_timeout_ms(context_value, environment_name: String, default_value: int, minimum_value: int) -> int:
	if context_value is int or context_value is float:
		var numeric_value := int(context_value)
		if numeric_value >= minimum_value:
			return numeric_value
	if OS.has_environment(environment_name):
		var raw_value := OS.get_environment(environment_name).strip_edges()
		if raw_value.is_valid_int():
			var parsed_value := int(raw_value)
			if parsed_value >= minimum_value:
				return parsed_value
	return default_value


func _release_tool_call_tasks() -> void:
	var task_ids: Array = []
	for task_id in _active_tool_call_tasks:
		var task = _active_tool_call_tasks[task_id]
		if task is ToolCallTask:
			task.release_owner()
		task_ids.append(task_id)
	for task_id in task_ids:
		_active_tool_call_tasks.erase(task_id)


func _complete_tool_call_task(task_id: int) -> void:
	_active_tool_call_tasks.erase(task_id)


func _log_message(message: String, level: String) -> void:
	if _log.is_valid():
		_log.call(message, level)
