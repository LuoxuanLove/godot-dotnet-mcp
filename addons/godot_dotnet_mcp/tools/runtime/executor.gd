@tool
extends RefCounted

## Atomic runtime tools used by high-level system runtime commands.

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _runtime_context: Dictionary = {}
var _runtime_control_service = null


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)
	_runtime_control_service = _resolve_runtime_control_service()
	MCPDebugBuffer.record("info", "runtime", "executor configure_runtime runtime_service=%s" % str(_runtime_control_service != null))


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "control",
			"description": "RUNTIME CONTROL ATOMIC: Inspect or arm the running project debugger session. Actions: status, enable, disable.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["status", "enable", "disable"], "description": "Runtime control action"},
					"timeout_ms": {"type": "integer", "description": "Optional timeout in milliseconds for enable"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "capture",
			"description": "RUNTIME CAPTURE ATOMIC: Capture the running game's viewport as PNG through the armed runtime session.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"frame_count": {"type": "integer", "description": "Number of frames to capture (default: 1)"},
					"interval_frames": {"type": "integer", "description": "Frames to wait between captures (default: 1)"},
					"capture_dir": {"type": "string", "description": "Optional output directory. Defaults to the fixed runtime capture cache directory."},
					"capture_label": {"type": "string", "description": "Optional file name prefix"},
					"include_runtime_state": {"type": "boolean", "description": "Include runtime state snapshot in the response (default: true)"},
					"timeout_ms": {"type": "integer", "description": "Optional timeout in milliseconds"}
				}
			}
		},
		{
			"name": "input",
			"description": "RUNTIME INPUT ATOMIC: Send a scripted batch of runtime inputs through the armed runtime session.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"inputs": {"type": "array", "items": {"type": "object"}, "description": "Runtime input entries"},
					"timeout_ms": {"type": "integer", "description": "Optional timeout in milliseconds"}
				},
				"required": ["inputs"]
			}
		},
		{
			"name": "step",
			"description": "RUNTIME STEP ATOMIC: Apply optional runtime inputs, wait frames, and optionally capture a frame through the armed runtime session.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"inputs": {"type": "array", "items": {"type": "object"}, "description": "Optional runtime input entries"},
					"wait_frames": {"type": "integer", "description": "Frames to wait before capture (default: 1)"},
					"capture": {"type": "boolean", "description": "Capture a frame after waiting (default: true)"},
					"capture_dir": {"type": "string", "description": "Optional output directory when capture=true. Defaults to the fixed runtime capture cache directory."},
					"capture_label": {"type": "string", "description": "Optional capture label"},
					"include_runtime_state": {"type": "boolean", "description": "Include runtime state snapshot in the response (default: true)"},
					"timeout_ms": {"type": "integer", "description": "Optional timeout in milliseconds"}
				}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "runtime", "tool: %s" % tool_name)
	match tool_name:
		"control":
			return _execute_control_sync(args)
		"capture", "input", "step":
			return _async_required_error("runtime_%s" % tool_name)
		_:
			return _unknown_tool_error(tool_name)


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "runtime", "tool_async: %s" % tool_name)
	match tool_name:
		"control":
			return await _execute_control_async(args)
		"capture":
			return await _execute_capture(args)
		"input":
			return await _execute_input(args)
		"step":
			return await _execute_step(args)
		_:
			return _unknown_tool_error(tool_name)


func _execute_control_sync(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"status":
			return _success(_build_runtime_status(), "Runtime control status fetched")
		"disable":
			var service = _get_runtime_control_service()
			if service == null or not service.has_method("disable_control"):
				return _service_unavailable_error("disable")
			var result = service.disable_control()
			return _normalize_service_result(result, "Runtime control disabled")
		"enable":
			return _async_required_error("runtime_control", "enable")
		_:
			return _invalid_action_error(action)


func _execute_control_async(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"status":
			return _success(_build_runtime_status(), "Runtime control status fetched")
		"enable":
			var service = _get_runtime_control_service()
			if service == null or not service.has_method("enable_control"):
				return _service_unavailable_error("enable")
			var enable_result = await service.enable_control(args.duplicate(true))
			return _normalize_service_result(enable_result, "Runtime control enabled")
		"disable":
			var service = _get_runtime_control_service()
			if service == null or not service.has_method("disable_control"):
				return _service_unavailable_error("disable")
			var disable_result = service.disable_control()
			return _normalize_service_result(disable_result, "Runtime control disabled")
		_:
			return _invalid_action_error(action)


func _execute_capture(args: Dictionary) -> Dictionary:
	var frame_count := int(args.get("frame_count", 1))
	if frame_count <= 0:
		return _invalid_argument_error("runtime_capture", "frame_count must be greater than 0")
	var interval_frames := int(args.get("interval_frames", 1))
	if interval_frames < 0:
		return _invalid_argument_error("runtime_capture", "interval_frames must be 0 or greater")
	var service = _get_runtime_control_service()
	if service == null or not service.has_method("capture"):
		return _service_unavailable_error("capture")
	var result = await service.capture(args.duplicate(true))
	if not _is_success_result(result):
		return _duplicate_result(result)
	var forwarded := _duplicate_result(result)
	var data := _result_data(forwarded)
	data["capture_mode"] = "sequence" if frame_count > 1 else "single"
	data["requested_frame_count"] = frame_count
	data["requested_interval_frames"] = interval_frames
	forwarded["data"] = data
	return forwarded


func _execute_input(args: Dictionary) -> Dictionary:
	var inputs = args.get("inputs", [])
	if not (inputs is Array) or (inputs as Array).is_empty():
		return _invalid_argument_error("runtime_input", "inputs must be a non-empty array")
	var service = _get_runtime_control_service()
	if service == null or not service.has_method("send_inputs"):
		return _service_unavailable_error("input")
	var result = await service.send_inputs(args.duplicate(true))
	return _normalize_service_result(result, "Runtime inputs applied")


func _execute_step(args: Dictionary) -> Dictionary:
	var inputs = args.get("inputs", [])
	if inputs != null and not (inputs is Array):
		return _invalid_argument_error("runtime_step", "inputs must be an array when provided")
	var wait_frames := int(args.get("wait_frames", 1))
	if wait_frames < 0:
		return _invalid_argument_error("runtime_step", "wait_frames must be 0 or greater")
	var service = _get_runtime_control_service()
	if service == null or not service.has_method("step"):
		return _service_unavailable_error("step")
	var result = await service.step(args.duplicate(true))
	return _normalize_service_result(result, "Runtime step completed")


func _resolve_runtime_control_service():
	var server = _runtime_context.get("server", null)
	if server != null and server.has_method("get_runtime_control_service"):
		var service = server.get_runtime_control_service()
		if service != null:
			return service
	if _runtime_context.has("runtime_control_service"):
		return _runtime_context.get("runtime_control_service", null)
	return null


func _get_runtime_control_service():
	if _runtime_control_service != null and is_instance_valid(_runtime_control_service):
		return _runtime_control_service
	_runtime_control_service = _resolve_runtime_control_service()
	return _runtime_control_service


func _build_runtime_status() -> Dictionary:
	var service = _get_runtime_control_service()
	if service == null or not service.has_method("get_status"):
		return {
			"available": false,
			"armed": false,
			"message": "Runtime control service is unavailable."
		}
	var status = service.get_status()
	if status is Dictionary:
		return (status as Dictionary).duplicate(true)
	return {
		"available": false,
		"armed": false,
		"message": "Runtime control status is unavailable."
	}


func _normalize_service_result(result, fallback_message: String) -> Dictionary:
	if result is Dictionary:
		var copied: Dictionary = (result as Dictionary).duplicate(true)
		if not copied.has("message") or str(copied.get("message", "")).is_empty():
			copied["message"] = fallback_message
		return copied
	return _error("runtime_service_unavailable", fallback_message)


func _result_data(result: Dictionary) -> Dictionary:
	var data = result.get("data", {})
	if data is Dictionary:
		return (data as Dictionary).duplicate(true)
	return {}


func _duplicate_result(result) -> Dictionary:
	if result is Dictionary:
		return (result as Dictionary).duplicate(true)
	return _error("runtime_service_unavailable", "Runtime control service returned an invalid response")


func _is_success_result(result) -> bool:
	return result is Dictionary and bool((result as Dictionary).get("success", false))


func _success(data, message: String = "") -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _error(error_code: String, message: String, data: Dictionary = {}) -> Dictionary:
	var out := {
		"success": false,
		"error": error_code,
		"message": message
	}
	if not data.is_empty():
		out["data"] = data.duplicate(true)
	return out


func _invalid_action_error(action: String) -> Dictionary:
	return _error("invalid_argument", "Unknown runtime_control action: %s" % action, {
		"hint": "Valid actions: status, enable, disable"
	})


func _invalid_argument_error(action: String, message: String) -> Dictionary:
	return _error("invalid_argument", message, {
		"action": action
	})


func _service_unavailable_error(action: String) -> Dictionary:
	return _error("runtime_service_unavailable", "Runtime control service is unavailable for action '%s'" % action, {
		"action": action
	})


func _async_required_error(tool_name: String, action: String = "") -> Dictionary:
	var data := {"tool_name": tool_name}
	if not action.is_empty():
		data["action"] = action
	return _error("runtime_async_required", "Runtime tool '%s' requires asynchronous execution" % tool_name, data)


func _unknown_tool_error(tool_name: String) -> Dictionary:
	return _error("invalid_argument", "Unknown tool: %s" % tool_name, {"tool_name": tool_name})
