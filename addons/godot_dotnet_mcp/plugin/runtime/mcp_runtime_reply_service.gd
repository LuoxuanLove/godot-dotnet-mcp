@tool
extends RefCounted
class_name MCPRuntimeReplyService

var _send_reply := Callable()
var _get_current_scene_path := Callable()
var _build_runtime_state := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_send_reply = callbacks.get("send_reply", Callable())
	_get_current_scene_path = callbacks.get("get_current_scene_path", Callable())
	_build_runtime_state = callbacks.get("build_runtime_state", Callable())


func dispose() -> void:
	_send_reply = Callable()
	_get_current_scene_path = Callable()
	_build_runtime_state = Callable()


func send_result(request_id: String, session_id: int, result: Dictionary, action: String = "") -> void:
	if bool(result.get("success", false)):
		_send_reply_safe({
			"request_id": request_id,
			"ok": true,
			"message": str(result.get("message", "Runtime command completed")),
			"data": result.get("data", {}),
			"session_id": session_id
		})
		return
	send_error(
		request_id,
		session_id,
		str(result.get("error", "runtime_command_failed")),
		str(result.get("message", result.get("error", "Runtime command failed"))),
		result.get("data", {}),
		action
	)


func send_error(request_id: String, session_id: int, error_type: String, message: String, data = {}, action: String = "") -> void:
	var payload_data := {}
	if data is Dictionary:
		payload_data = (data as Dictionary).duplicate(true)
	elif data != null:
		payload_data = {"details": data}
	if not payload_data.has("runtime_context"):
		payload_data["runtime_context"] = _build_runtime_error_context(session_id, action)
	if not payload_data.has("runtime_state"):
		payload_data["runtime_state"] = _build_runtime_state_safe(session_id)
	if not payload_data.has("hint"):
		var hint := _build_runtime_error_hint(error_type, action)
		if not hint.is_empty():
			payload_data["hint"] = hint
	_send_reply_safe({
		"request_id": request_id,
		"ok": false,
		"error": error_type,
		"message": message,
		"data": payload_data,
		"session_id": session_id
	})


func _send_reply_safe(payload: Dictionary) -> void:
	if _send_reply.is_valid():
		_send_reply.call(payload.duplicate(true))


func _build_runtime_error_context(session_id: int, action: String = "") -> Dictionary:
	return {
		"layer": "runtime_bridge",
		"action": action,
		"session_id": session_id,
		"scene": _get_current_scene_path_safe()
	}


func _build_runtime_error_hint(error_type: String, action: String = "") -> String:
	match error_type:
		"runtime_capture_failed":
			return "Ensure the game viewport is rendering normally, then retry the runtime capture command."
		"invalid_argument":
			if action == "capture":
				return "Check frame_count / interval_frames and retry the runtime capture command."
			if action == "input":
				return "Check kind, target, op, and duration_ms for each runtime input entry."
			if action == "step":
				return "Check wait_frames and the optional inputs array before retrying the runtime step."
			return "Fix the runtime command arguments and retry."
		_:
			return ""


func _get_current_scene_path_safe() -> String:
	if _get_current_scene_path.is_valid():
		return str(_get_current_scene_path.call())
	return ""


func _build_runtime_state_safe(session_id: int) -> Dictionary:
	if _build_runtime_state.is_valid():
		var state = _build_runtime_state.call(session_id)
		if state is Dictionary:
			return (state as Dictionary).duplicate(true)
	return {
		"running": true,
		"scene": _get_current_scene_path_safe(),
		"session_id": session_id
	}
