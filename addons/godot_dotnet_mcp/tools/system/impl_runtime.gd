@tool
extends RefCounted

## System implementation: runtime_control, runtime_capture,
## runtime_input, runtime_step

var bridge
var _runtime_context: Dictionary = {}

const HANDLED_TOOLS := [
	"runtime_control",
	"runtime_capture",
	"runtime_input",
	"runtime_step"
]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "runtime_control",
			"description": "RUNTIME CONTROL: Inspect or change the session-scoped runtime control safety gate. Actions: status, enable, disable. The gate is disabled by default, only applies to the current running editor debugger session, and automatically resets when the runtime session stops or the plugin reloads.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["status", "enable", "disable"],
						"description": "Runtime control action to perform"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "runtime_capture",
			"description": "RUNTIME CAPTURE: Capture one or more PNG frames from the current running project viewport. frame_count defaults to 1, which captures a single frame. When frame_count is greater than 1, interval_frames controls the process-frame gap between captures. Requires runtime control to be enabled first.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"frame_count": {
						"type": "integer",
						"description": "How many frames to capture (default: 1)"
					},
					"interval_frames": {
						"type": "integer",
						"description": "How many process frames to wait between captures when frame_count > 1 (default: 1)"
					}
				}
			}
		},
		{
			"name": "runtime_input",
			"description": "RUNTIME INPUT: Inject action-based or raw key input into the currently running project. Requires runtime control to be enabled first. Each inputs[] entry uses kind=action|key, target, op=press|release|tap|hold, duration_ms?.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"inputs": {
						"type": "array",
						"description": "Input operations to inject into the running project",
						"items": {
							"type": "object",
							"properties": {
								"kind": {
									"type": "string",
									"enum": ["action", "key"],
									"description": "Whether to inject an InputMap action or a raw key event"
								},
								"target": {
									"type": "string",
									"description": "InputMap action name or a Godot key name"
								},
								"op": {
									"type": "string",
									"enum": ["press", "release", "tap", "hold"],
									"description": "Input operation to apply"
								},
								"duration_ms": {
									"type": "integer",
									"description": "Optional hold/tap duration in milliseconds"
								}
							},
							"required": ["kind", "target", "op"]
						}
					}
				},
				"required": ["inputs"]
			}
		},
		{
			"name": "runtime_step",
			"description": "RUNTIME STEP: Closed-loop helper that injects inputs, waits a fixed number of frames, optionally captures a frame, and returns the latest runtime_state. Requires runtime control to be enabled first.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"inputs": {
						"type": "array",
						"description": "Optional input operations to inject before waiting",
						"items": {
							"type": "object",
							"properties": {
								"kind": {
									"type": "string",
									"enum": ["action", "key"],
									"description": "Whether to inject an InputMap action or a raw key event"
								},
								"target": {
									"type": "string",
									"description": "InputMap action name or a Godot key name"
								},
								"op": {
									"type": "string",
									"enum": ["press", "release", "tap", "hold"],
									"description": "Input operation to apply"
								},
								"duration_ms": {
									"type": "integer",
									"description": "Optional hold/tap duration in milliseconds"
								}
							},
							"required": ["kind", "target", "op"]
						}
					},
					"wait_frames": {
						"type": "integer",
						"description": "How many process frames to wait after input injection"
					},
					"capture": {
						"type": "boolean",
						"description": "Whether to capture a frame after the wait (default: true)"
					}
				},
				"required": ["wait_frames"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"runtime_control":
			var action := str(args.get("action", "status")).strip_edges().to_lower()
			if action == "status":
				return _build_status_response()
			if action == "disable":
				var service = _get_runtime_control_service()
				if service == null:
					return _failure("runtime_control_unavailable", "Runtime control service is unavailable.")
				return service.disable_control()
			return _failure("async_required", "Runtime tool requires async execution.", {
				"tool_name": "system_runtime_control",
				"action": action
			})
		"runtime_capture":
			return _failure("async_required", "Runtime tool requires async execution.", {
				"tool_name": "system_runtime_capture"
			})
		_:
			return _failure("async_required", "Runtime tool requires async execution.", {
				"tool_name": "system_%s" % tool_name
			})


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	var service = _get_runtime_control_service()
	if service == null:
		return _failure("runtime_control_unavailable", "Runtime control service is unavailable.", {}, "system_%s" % tool_name)

	match tool_name:
		"runtime_control":
			var action := str(args.get("action", "status")).strip_edges().to_lower()
			match action:
				"status":
					return _build_status_response()
				"enable":
					return await service.enable_control(args)
				"disable":
					return service.disable_control()
				_:
					return _failure("invalid_argument", "Unknown runtime control action: %s" % action, {}, "system_runtime_control")
		"runtime_capture":
			return await _execute_runtime_capture(service, args)
		"runtime_input":
			return await service.send_inputs(args)
		"runtime_step":
			return await service.step(args)
		_:
			return _failure("invalid_argument", "Unknown runtime tool: %s" % tool_name, {}, "system_%s" % tool_name)


func _get_runtime_control_service():
	var server = _runtime_context.get("server", null)
	if server != null and server.has_method("get_runtime_control_service"):
		return server.get_runtime_control_service()
	return null


func _build_status_response() -> Dictionary:
	var service = _get_runtime_control_service()
	if service == null:
		return _failure("runtime_control_unavailable", "Runtime control service is unavailable.", {}, "system_runtime_control")
	var status = service.get_status()
	return bridge.success(status, str(status.get("message", "Runtime control status")))


func _execute_runtime_capture(service, args: Dictionary) -> Dictionary:
	var frame_count := int(args.get("frame_count", 1))
	var interval_frames := int(args.get("interval_frames", 1))
	if frame_count <= 0:
		return _failure("invalid_argument", "frame_count must be greater than 0", {}, "system_runtime_capture")
	if interval_frames < 0:
		return _failure("invalid_argument", "interval_frames must be 0 or greater", {}, "system_runtime_capture")
	var capture_args := {
		"frame_count": frame_count,
		"interval_frames": interval_frames,
		"capture_label": str(args.get("capture_label", "")),
		"include_runtime_state": bool(args.get("include_runtime_state", true))
	}
	if args.has("timeout_ms"):
		capture_args["timeout_ms"] = int(args.get("timeout_ms", 0))
	var capture_result: Dictionary = await service.capture(capture_args)
	if not bool(capture_result.get("success", false)):
		return capture_result
	var capture_mode := "single" if frame_count <= 1 else "sequence"
	return _annotate_capture_result(capture_result, capture_mode, frame_count, interval_frames)


func _annotate_capture_result(result: Dictionary, capture_mode: String, frame_count: int, interval_frames: int) -> Dictionary:
	var normalized: Dictionary = result.duplicate(true)
	var data = normalized.get("data", {})
	if not (data is Dictionary):
		data = {}
	var payload: Dictionary = (data as Dictionary).duplicate(true)
	payload["capture_mode"] = capture_mode
	payload["requested_frame_count"] = frame_count
	payload["interval_frames"] = interval_frames
	normalized["data"] = payload
	return normalized


func _build_tool_error_hint(error_type: String, tool_name: String) -> String:
	if error_type == "invalid_argument" and tool_name == "system_runtime_capture":
		return "Check frame_count / interval_frames before retrying system_runtime_capture."
	if error_type == "invalid_argument" and tool_name == "system_runtime_control":
		return "Check the action value. Allowed values are status, enable, disable."
	if error_type == "runtime_control_unavailable":
		return "Ensure the editor plugin runtime services are loaded before retrying the runtime tool."
	return ""


func _failure(error_type: String, message: String, data = {}, tool_name: String = "") -> Dictionary:
	var payload := {}
	if data is Dictionary:
		payload = (data as Dictionary).duplicate(true)
	elif data != null:
		payload = {"details": data}
	if not tool_name.is_empty():
		payload["tool_name"] = tool_name
	if not payload.has("hint"):
		var hint := _build_tool_error_hint(error_type, tool_name)
		if not hint.is_empty():
			payload["hint"] = hint
	var result := {
		"success": false,
		"error": error_type,
		"message": message
	}
	if not payload.is_empty():
		result["data"] = payload
	return result
