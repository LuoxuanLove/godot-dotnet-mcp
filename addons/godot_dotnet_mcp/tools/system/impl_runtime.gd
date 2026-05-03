@tool
extends RefCounted

## System implementation: runtime_control, runtime_step

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var bridge

const HANDLED_TOOLS := ["runtime_control", "runtime_step"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(context: Dictionary) -> void:
	MCPDebugBuffer.record("info", "system", "impl_runtime configure_runtime context_keys=%d" % context.keys().size())


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "runtime_control",
			"description": "RUNTIME CONTROL: Inspect or arm the running project debugger session. ACTIONS: status, enable, disable. status returns the current runtime control state. enable waits for a commandable session and arms it. disable clears the armed session. Use timeout_ms to bound enable waiting.",
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
			"name": "runtime_step",
			"description": "RUNTIME STEP: Unified runtime automation I/O entry. ACTIONS: step (default) applies optional inputs, waits, and optionally captures one frame; capture captures single or multiple frames; input sends scripted inputs only. Use runtime_control first to arm the current runtime session.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["step", "capture", "input"], "description": "Runtime automation action (default: step)"},
					"inputs": {"type": "array", "items": {"type": "object"}, "description": "Optional runtime input entries"},
					"wait_frames": {"type": "integer", "description": "Frames to wait before capture (default: 1)"},
					"frame_count": {"type": "integer", "description": "Number of frames for action=capture (default: 1)"},
					"interval_frames": {"type": "integer", "description": "Frames to wait between captures for action=capture (default: 1)"},
					"capture": {"type": "boolean", "description": "Capture a frame after waiting (default: true)"},
					"capture_dir": {"type": "string", "description": "Optional output directory. Defaults to the fixed runtime capture cache directory."},
					"capture_label": {"type": "string", "description": "Optional capture label"},
					"include_runtime_state": {"type": "boolean", "description": "Include runtime state snapshot in the response (default: true)"},
					"timeout_ms": {"type": "integer", "description": "Optional timeout in milliseconds"}
				}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "tool: %s" % tool_name)
	match tool_name:
		"runtime_control":
			return bridge.call_atomic("runtime_control", args)
		"runtime_step":
			return _async_required_error(tool_name)
		_:
			return _unknown_tool_error(tool_name)


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "tool_async: %s" % tool_name)
	match tool_name:
		"runtime_control":
			return await bridge.call_atomic_async("runtime_control", args)
		"runtime_step":
			return await _execute_runtime_step(args)
		_:
			return _unknown_tool_error(tool_name)


func _error(error_code: String, message: String, data: Dictionary = {}) -> Dictionary:
	var out := {
		"success": false,
		"error": error_code,
		"message": message
	}
	if not data.is_empty():
		out["data"] = data.duplicate(true)
	return out


func _execute_runtime_step(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "step")).strip_edges()
	match action:
		"step":
			return await bridge.call_atomic_async("runtime_step", args)
		"capture":
			return await bridge.call_atomic_async("runtime_capture", args)
		"input":
			return await bridge.call_atomic_async("runtime_input", args)
		_:
			return _error("invalid_argument", "Unknown runtime_step action: %s" % action, {
				"hint": "Valid actions: step, capture, input"
			})


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
