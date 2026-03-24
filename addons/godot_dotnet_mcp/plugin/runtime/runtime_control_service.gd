@tool
extends RefCounted
class_name MCPRuntimeControlService

const DEFAULT_COMMAND_TIMEOUT_MS := 5000
const DEFAULT_SEQUENCE_TIMEOUT_MS := 15000
const DEFAULT_ENABLE_TIMEOUT_MS := 5000
const RUNTIME_COMMAND_MESSAGE := "godot_mcp/runtime_command:call"

var _plugin: EditorPlugin
var _debugger_bridge: EditorDebuggerPlugin
var _log := Callable()
var _armed_session_id := -1
var _armed_at_unix := 0
var _last_reply_at_unix := 0
var _pending_requests: Dictionary = {}


func configure(plugin: EditorPlugin, debugger_bridge: EditorDebuggerPlugin, callbacks: Dictionary = {}) -> void:
	_plugin = plugin
	if _debugger_bridge != debugger_bridge:
		if _debugger_bridge != null:
			_mark_all_pending_requests("runtime_session_lost", "Runtime control bridge changed before the command completed")
		_disconnect_debugger_bridge()
		_debugger_bridge = debugger_bridge
		_connect_debugger_bridge()
	_log = callbacks.get("log", Callable())
	_validate_armed_session()


func reset() -> void:
	_mark_all_pending_requests("runtime_session_lost", "Runtime control service reset before the command completed")
	_armed_session_id = -1
	_armed_at_unix = 0
	_last_reply_at_unix = 0
	_disconnect_debugger_bridge()
	_debugger_bridge = null
	_plugin = null
	_log = Callable()


func get_status() -> Dictionary:
	_validate_armed_session()
	var active_session_id := _get_preferred_session_id()
	var available := active_session_id >= 0
	var armed := _armed_session_id >= 0
	var message := ""
	if not available:
		message = "No active runtime debugger session is available. Run the project first."
	elif not armed:
		message = "Runtime control is disabled for the current session."
	else:
		message = "Runtime control is enabled for the current session."

	return {
		"available": available,
		"armed": armed,
		"active_session_id": active_session_id,
		"armed_session_id": _armed_session_id,
		"armed_at_unix": _armed_at_unix,
		"last_reply_at_unix": _last_reply_at_unix,
		"pending_request_count": _pending_requests.size(),
		"message": message
	}


func enable_control(args: Dictionary = {}) -> Dictionary:
	var wait_timeout_ms := _resolve_timeout_ms(args, DEFAULT_ENABLE_TIMEOUT_MS)
	var session_id := await _await_commandable_session(wait_timeout_ms)
	if session_id < 0:
		return _error("runtime_not_running", "Runtime control requires an active running project session. Call system_project_run first.", {
			"timeout_ms": wait_timeout_ms
		})
	_armed_session_id = session_id
	_armed_at_unix = int(Time.get_unix_time_from_system())
	_log_message("Runtime control armed for debugger session %d" % session_id, "info")
	return _success({
		"armed": true,
		"session_id": session_id,
		"armed_at_unix": _armed_at_unix
	}, "Runtime control enabled")


func disable_control() -> Dictionary:
	var previous_session_id := _armed_session_id
	_armed_session_id = -1
	_armed_at_unix = 0
	_mark_all_pending_requests("runtime_control_disabled", "Runtime control was disabled before the command completed")
	return _success({
		"armed": false,
		"session_id": previous_session_id
	}, "Runtime control disabled")


func capture_frame(args: Dictionary) -> Dictionary:
	var payload := {
		"capture_label": str(args.get("capture_label", "")),
		"include_runtime_state": bool(args.get("include_runtime_state", true))
	}
	var timeout_ms := _resolve_timeout_ms(args, DEFAULT_COMMAND_TIMEOUT_MS)
	return await _request_runtime_command("capture_frame", payload, timeout_ms)


func capture_sequence(args: Dictionary) -> Dictionary:
	var frame_count := int(args.get("frame_count", 1))
	var interval_frames := int(args.get("interval_frames", 1))
	if frame_count <= 0:
		return _error("invalid_argument", "frame_count must be greater than 0")
	if interval_frames < 0:
		return _error("invalid_argument", "interval_frames must be 0 or greater")
	var payload := {
		"frame_count": frame_count,
		"interval_frames": interval_frames,
		"capture_label": str(args.get("capture_label", "")),
		"include_runtime_state": bool(args.get("include_runtime_state", true))
	}
	var timeout_ms := _resolve_timeout_ms(args, DEFAULT_SEQUENCE_TIMEOUT_MS)
	return await _request_runtime_command("capture_sequence", payload, timeout_ms)


func send_inputs(args: Dictionary) -> Dictionary:
	var inputs = args.get("inputs", [])
	if not (inputs is Array) or (inputs as Array).is_empty():
		return _error("invalid_argument", "system_runtime_input requires a non-empty inputs array")
	var timeout_ms := _resolve_timeout_ms(args, DEFAULT_COMMAND_TIMEOUT_MS)
	return await _request_runtime_command("input", {
		"inputs": (inputs as Array).duplicate(true)
	}, timeout_ms)


func step(args: Dictionary) -> Dictionary:
	var inputs = args.get("inputs", [])
	if inputs != null and not (inputs is Array):
		return _error("invalid_argument", "inputs must be an array when provided")
	var wait_frames := int(args.get("wait_frames", 1))
	if wait_frames < 0:
		return _error("invalid_argument", "wait_frames must be 0 or greater")
	var timeout_ms := _resolve_timeout_ms(args, DEFAULT_SEQUENCE_TIMEOUT_MS)
	var payload := {
		"inputs": (inputs as Array).duplicate(true) if inputs is Array else [],
		"wait_frames": wait_frames,
		"capture": bool(args.get("capture", true)),
		"capture_label": str(args.get("capture_label", "")),
		"include_runtime_state": bool(args.get("include_runtime_state", true))
	}
	return await _request_runtime_command("step", payload, timeout_ms)


func _request_runtime_command(action: String, payload: Dictionary, timeout_ms: int) -> Dictionary:
	_validate_armed_session()
	if _armed_session_id < 0:
		return _error("runtime_control_disabled", "Runtime control is disabled. Call system_runtime_control with action=enable first.")
	if not _is_session_commandable(_armed_session_id):
		var previous_session_id := _armed_session_id
		_armed_session_id = -1
		_armed_at_unix = 0
		return _error("runtime_session_lost", "The armed runtime debugger session is no longer available.", {
			"session_id": previous_session_id
		})

	var request_id := _build_request_id(action)
	var command_payload := {
		"request_id": request_id,
		"action": action,
		"session_id": _armed_session_id,
		"payload": payload.duplicate(true)
	}
	_pending_requests[request_id] = {
		"session_id": _armed_session_id,
		"completed": false,
		"reply": {}
	}

	var send_result := _send_runtime_command(_armed_session_id, command_payload)
	if not bool(send_result.get("success", false)):
		_pending_requests.erase(request_id)
		return send_result

	var wait_result: Dictionary = await _await_runtime_reply(request_id, timeout_ms)
	if not bool(wait_result.get("success", false)):
		return wait_result

	var response_data = wait_result.get("data", {})
	if not (response_data is Dictionary):
		response_data = {}
	return _success(response_data, str(wait_result.get("message", "Runtime command completed")))


func _await_runtime_reply(request_id: String, timeout_ms: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + maxi(timeout_ms, 1)
	while Time.get_ticks_msec() <= deadline:
		var pending = _pending_requests.get(request_id, null)
		if pending is Dictionary and bool((pending as Dictionary).get("completed", false)):
			var reply: Dictionary = ((pending as Dictionary).get("reply", {}) as Dictionary).duplicate(true)
			_pending_requests.erase(request_id)
			return reply
		var tree := _get_scene_tree()
		if tree == null:
			break
		await tree.process_frame

	_pending_requests.erase(request_id)
	return _error("runtime_command_timeout", "Timed out waiting for the runtime command reply.", {
		"request_id": request_id,
		"timeout_ms": timeout_ms
	})


func _connect_debugger_bridge() -> void:
	if _debugger_bridge == null:
		return
	if _debugger_bridge.has_signal("runtime_reply_received") and not _debugger_bridge.runtime_reply_received.is_connected(_on_runtime_reply_received):
		_debugger_bridge.runtime_reply_received.connect(_on_runtime_reply_received)
	if _debugger_bridge.has_signal("session_state_changed") and not _debugger_bridge.session_state_changed.is_connected(_on_session_state_changed):
		_debugger_bridge.session_state_changed.connect(_on_session_state_changed)


func _disconnect_debugger_bridge() -> void:
	if _debugger_bridge == null:
		return
	if _debugger_bridge.has_signal("runtime_reply_received") and _debugger_bridge.runtime_reply_received.is_connected(_on_runtime_reply_received):
		_debugger_bridge.runtime_reply_received.disconnect(_on_runtime_reply_received)
	if _debugger_bridge.has_signal("session_state_changed") and _debugger_bridge.session_state_changed.is_connected(_on_session_state_changed):
		_debugger_bridge.session_state_changed.disconnect(_on_session_state_changed)


func _on_runtime_reply_received(session_id: int, payload: Dictionary) -> void:
	var request_id := str(payload.get("request_id", ""))
	if request_id.is_empty():
		return
	if not _pending_requests.has(request_id):
		return
	var pending: Dictionary = _pending_requests.get(request_id, {})
	if int(pending.get("session_id", -1)) != session_id:
		return

	var reply := {
		"success": bool(payload.get("ok", false)),
		"data": payload.get("data", {}),
		"message": str(payload.get("message", "Runtime command completed"))
	}
	if not bool(payload.get("ok", false)):
		reply = _error(str(payload.get("error", "runtime_command_failed")), str(payload.get("message", "Runtime command failed")), payload.get("data", {}))

	pending["completed"] = true
	pending["reply"] = reply
	_pending_requests[request_id] = pending
	_last_reply_at_unix = int(Time.get_unix_time_from_system())


func _on_session_state_changed(session_id: int, state: String, _metadata: Dictionary) -> void:
	if state in ["stopped"]:
		if _armed_session_id == session_id:
			_armed_session_id = -1
			_armed_at_unix = 0
		_mark_pending_requests_for_session(session_id, "runtime_session_lost", "The runtime debugger session stopped before the command completed.")
	elif state in ["started", "continued", "breaked", "attached"]:
		_validate_armed_session()


func _validate_armed_session() -> void:
	if _armed_session_id >= 0 and not _is_session_commandable(_armed_session_id):
		_armed_session_id = -1
		_armed_at_unix = 0


func _mark_all_pending_requests(error_type: String, message: String) -> void:
	for request_id in _pending_requests.keys():
		var pending: Dictionary = _pending_requests.get(request_id, {})
		pending["completed"] = true
		pending["reply"] = _error(error_type, message)
		_pending_requests[request_id] = pending


func _mark_pending_requests_for_session(session_id: int, error_type: String, message: String) -> void:
	for request_id in _pending_requests.keys():
		var pending: Dictionary = _pending_requests.get(request_id, {})
		if int(pending.get("session_id", -1)) != session_id:
			continue
		pending["completed"] = true
		pending["reply"] = _error(error_type, message, {
			"session_id": session_id
		})
		_pending_requests[request_id] = pending


func _send_runtime_command(session_id: int, payload: Dictionary) -> Dictionary:
	if _debugger_bridge == null or not is_instance_valid(_debugger_bridge):
		return _error("runtime_bridge_unavailable", "Editor debugger bridge is unavailable")
	if not _debugger_bridge.has_method("send_runtime_command"):
		return _error("runtime_bridge_unavailable", "Editor debugger bridge cannot send runtime commands")
	var result = _debugger_bridge.send_runtime_command(session_id, payload)
	if result is Dictionary:
		return result
	return _error("runtime_bridge_unavailable", "Runtime command dispatch failed")


func _get_preferred_session_id() -> int:
	if _debugger_bridge == null or not is_instance_valid(_debugger_bridge):
		return -1
	if _debugger_bridge.has_method("get_preferred_runtime_session_id"):
		return int(_debugger_bridge.get_preferred_runtime_session_id())
	return -1


func _is_session_commandable(session_id: int) -> bool:
	if _debugger_bridge == null or not is_instance_valid(_debugger_bridge):
		return false
	if _debugger_bridge.has_method("is_session_commandable"):
		return bool(_debugger_bridge.is_session_commandable(session_id))
	return false


func _get_scene_tree() -> SceneTree:
	if _plugin == null or not is_instance_valid(_plugin):
		return null
	return _plugin.get_tree()


func _build_request_id(action: String) -> String:
	return "runtime-%s-%d" % [action, Time.get_ticks_usec()]


func _await_commandable_session(timeout_ms: int) -> int:
	var session_id := _get_preferred_session_id()
	if session_id >= 0:
		return session_id

	var deadline := Time.get_ticks_msec() + maxi(timeout_ms, 1)
	while Time.get_ticks_msec() <= deadline:
		session_id = _get_preferred_session_id()
		if session_id >= 0:
			return session_id
		var tree := _get_scene_tree()
		if tree == null:
			break
		await tree.process_frame
	return -1


func _resolve_timeout_ms(args: Dictionary, default_value: int) -> int:
	var timeout_ms := int(args.get("timeout_ms", default_value))
	if timeout_ms <= 0:
		return default_value
	return timeout_ms


func _log_message(message: String, level: String = "debug") -> void:
	if _log.is_valid():
		_log.call(message, level)


func _success(data, message: String) -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _error(error_type: String, message: String, data = {}) -> Dictionary:
	var result := {
		"success": false,
		"error": error_type,
		"message": message
	}
	if data is Dictionary and not (data as Dictionary).is_empty():
		result["data"] = data
	return result
