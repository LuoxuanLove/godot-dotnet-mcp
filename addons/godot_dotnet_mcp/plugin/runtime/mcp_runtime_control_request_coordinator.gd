@tool
extends RefCounted
class_name MCPRuntimeControlRequestCoordinator

var _send_runtime_command := Callable()
var _resolve_fallback_reply := Callable()
var _build_reply_from_runtime_payload := Callable()
var _build_error := Callable()
var _get_scene_tree := Callable()
var _last_reply_at_unix := 0
var _pending_requests: Dictionary = {}


func configure(callbacks: Dictionary = {}) -> void:
	_send_runtime_command = callbacks.get("send_runtime_command", Callable())
	_resolve_fallback_reply = callbacks.get("resolve_fallback_reply", Callable())
	_build_reply_from_runtime_payload = callbacks.get("build_reply_from_runtime_payload", Callable())
	_build_error = callbacks.get("build_error", Callable())
	_get_scene_tree = callbacks.get("get_scene_tree", Callable())


func reset() -> void:
	_pending_requests.clear()
	_last_reply_at_unix = 0
	_send_runtime_command = Callable()
	_resolve_fallback_reply = Callable()
	_build_reply_from_runtime_payload = Callable()
	_build_error = Callable()
	_get_scene_tree = Callable()


func get_pending_request_count() -> int:
	return _pending_requests.size()


func get_last_reply_at_unix() -> int:
	return _last_reply_at_unix


func request_runtime_command(session_id: int, action: String, payload: Dictionary, timeout_ms: int) -> Dictionary:
	var request_id := _build_request_id(action)
	var command_payload := {
		"request_id": request_id,
		"action": action,
		"session_id": session_id,
		"payload": payload.duplicate(true)
	}
	_pending_requests[request_id] = {
		"action": action,
		"session_id": session_id,
		"completed": false,
		"reply": {}
	}

	var send_result = _dispatch_runtime_command(session_id, command_payload, action)
	if not bool(send_result.get("success", false)):
		_pending_requests.erase(request_id)
		return send_result

	var wait_result: Dictionary = await _await_runtime_reply(request_id, timeout_ms)
	if not bool(wait_result.get("success", false)):
		return wait_result

	var response_data = wait_result.get("data", {})
	if not (response_data is Dictionary):
		response_data = {}
	return {
		"success": true,
		"data": response_data,
		"message": str(wait_result.get("message", "Runtime command completed"))
	}


func handle_runtime_reply(session_id: int, payload: Dictionary) -> void:
	var request_id := str(payload.get("request_id", ""))
	if request_id.is_empty():
		return
	if not _pending_requests.has(request_id):
		return
	var pending: Dictionary = _pending_requests.get(request_id, {})
	if int(pending.get("session_id", -1)) != session_id:
		return

	var reply = _build_reply_from_runtime_payload.call(payload, str(pending.get("action", ""))) if _build_reply_from_runtime_payload.is_valid() else {}
	if not (reply is Dictionary) or (reply as Dictionary).is_empty():
		return

	pending["completed"] = true
	pending["reply"] = (reply as Dictionary).duplicate(true)
	_pending_requests[request_id] = pending
	_last_reply_at_unix = int(Time.get_unix_time_from_system())


func mark_all_pending_requests(error_type: String, message: String) -> void:
	for request_id in _pending_requests.keys():
		var pending: Dictionary = _pending_requests.get(request_id, {})
		pending["completed"] = true
		pending["reply"] = _error(error_type, message, {}, str(pending.get("action", "")))
		_pending_requests[request_id] = pending


func mark_pending_requests_for_session(session_id: int, error_type: String, message: String) -> void:
	for request_id in _pending_requests.keys():
		var pending: Dictionary = _pending_requests.get(request_id, {})
		if int(pending.get("session_id", -1)) != session_id:
			continue
		pending["completed"] = true
		pending["reply"] = _error(error_type, message, {
			"session_id": session_id
		}, str(pending.get("action", "")))
		_pending_requests[request_id] = pending


func _await_runtime_reply(request_id: String, timeout_ms: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + maxi(timeout_ms, 1)
	while Time.get_ticks_msec() <= deadline:
		var pending = _pending_requests.get(request_id, null)
		if pending is Dictionary and bool((pending as Dictionary).get("completed", false)):
			var reply: Dictionary = ((pending as Dictionary).get("reply", {}) as Dictionary).duplicate(true)
			_pending_requests.erase(request_id)
			return reply
		if pending is Dictionary and _resolve_fallback_reply.is_valid():
			var fallback_reply = _resolve_fallback_reply.call(request_id, pending as Dictionary)
			if fallback_reply is Dictionary and not (fallback_reply as Dictionary).is_empty():
				_pending_requests.erase(request_id)
				_last_reply_at_unix = int(Time.get_unix_time_from_system())
				return (fallback_reply as Dictionary).duplicate(true)
		var tree = _get_scene_tree.call() if _get_scene_tree.is_valid() else null
		if tree == null:
			break
		await tree.process_frame

	var pending_timeout = _pending_requests.get(request_id, {})
	_pending_requests.erase(request_id)
	return _error("runtime_command_timeout", "Timed out waiting for the runtime command reply.", {
		"request_id": request_id,
		"timeout_ms": timeout_ms
	}, str((pending_timeout as Dictionary).get("action", "")))


func _dispatch_runtime_command(session_id: int, payload: Dictionary, action: String) -> Dictionary:
	if not _send_runtime_command.is_valid():
		return _error("runtime_bridge_unavailable", "Runtime command dispatch failed", {}, action)
	var result = _send_runtime_command.call(session_id, payload)
	if result is Dictionary:
		return (result as Dictionary).duplicate(true)
	return _error("runtime_bridge_unavailable", "Runtime command dispatch failed", {}, action)


func _build_request_id(action: String) -> String:
	return "runtime-%s-%d" % [action, Time.get_ticks_usec()]


func _error(error_type: String, message: String, data = {}, action: String = "") -> Dictionary:
	if _build_error.is_valid():
		var result = _build_error.call(error_type, message, data, action)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {
		"success": false,
		"error": error_type,
		"message": message,
		"data": data,
		"action": action
	}
