@tool
extends RefCounted
class_name MCPRuntimeControlReplyResolver

var _get_recent_runtime_events := Callable()
var _build_error := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_get_recent_runtime_events = callbacks.get("get_recent_runtime_events", Callable())
	_build_error = callbacks.get("build_error", Callable())


func reset() -> void:
	_get_recent_runtime_events = Callable()
	_build_error = Callable()


func resolve_fallback_reply(request_id: String, pending: Dictionary) -> Dictionary:
	var recent_events := _get_recent_runtime_events_safe()
	var expected_session_id := int(pending.get("session_id", -1))
	var action := str(pending.get("action", ""))
	for index in range(recent_events.size() - 1, -1, -1):
		var event = recent_events[index]
		if not (event is Dictionary):
			continue
		var payload = (event as Dictionary).get("payload", {})
		if not (payload is Dictionary):
			continue
		var payload_dict: Dictionary = payload
		if str(payload_dict.get("request_id", "")) != request_id:
			continue
		var payload_session_id := int(payload_dict.get("session_id", expected_session_id))
		if expected_session_id >= 0 and payload_session_id != expected_session_id:
			continue
		if not payload_dict.has("ok") and not payload_dict.has("error"):
			continue
		return build_reply_from_runtime_payload(payload_dict, action)
	return {}


func build_reply_from_runtime_payload(payload: Dictionary, action: String) -> Dictionary:
	var reply := {
		"success": bool(payload.get("ok", false)),
		"data": payload.get("data", {}),
		"message": str(payload.get("message", "Runtime command completed"))
	}
	if bool(payload.get("ok", false)):
		return reply
	if _build_error.is_valid():
		var result = _build_error.call(
			str(payload.get("error", "runtime_command_failed")),
			str(payload.get("message", "Runtime command failed")),
			payload.get("data", {}),
			action
		)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {
		"success": false,
		"error": str(payload.get("error", "runtime_command_failed")),
		"message": str(payload.get("message", "Runtime command failed")),
		"data": payload.get("data", {})
	}


func _get_recent_runtime_events_safe() -> Array[Dictionary]:
	if _get_recent_runtime_events.is_valid():
		var events = _get_recent_runtime_events.call()
		if events is Array:
			var result: Array[Dictionary] = []
			for item in events:
				if item is Dictionary:
					result.append((item as Dictionary).duplicate(true))
			return result
	return []
