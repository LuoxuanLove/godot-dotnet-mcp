@tool
extends RefCounted
class_name MCPEditorLifecycleEndpoint

var _build_state := Callable()
var _execute_close := Callable()
var _execute_restart := Callable()
var _success := Callable()
var _error := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_build_state = callbacks.get("build_state", Callable())
	_execute_close = callbacks.get("execute_close", Callable())
	_execute_restart = callbacks.get("execute_restart", Callable())
	_success = callbacks.get("success", Callable())
	_error = callbacks.get("error", Callable())


func handle_post_request(body: String) -> Dictionary:
	var parsed = JSON.parse_string(body)
	if not (parsed is Dictionary):
		return _call_error(
			"invalid_argument",
			"Editor lifecycle request body must be a JSON object."
		)

	var args: Dictionary = (parsed as Dictionary).duplicate(true)
	var action := str(args.get("action", "")).strip_edges()
	if action.is_empty():
		return _call_error(
			"invalid_argument",
			"Editor lifecycle action is required."
		)
	args.erase("action")
	return handle_request(action, args)


func handle_request(action: String, args: Dictionary) -> Dictionary:
	match action:
		"status":
			return _call_success(_build_state_safe(), "Editor lifecycle status fetched")
		"close":
			return _call_handler(_execute_close, [args], "Editor close handler is unavailable.")
		"restart":
			return _call_handler(_execute_restart, [args], "Editor restart handler is unavailable.")
		_:
			return _call_error("invalid_argument", "Unknown editor lifecycle action: %s" % action, {
				"hint": "Use action=status|close|restart."
			})


func _build_state_safe() -> Dictionary:
	if _build_state.is_valid():
		var state = _build_state.call()
		if state is Dictionary:
			return (state as Dictionary).duplicate(true)
	return {}


func _call_handler(handler: Callable, args: Array, fallback_message: String) -> Dictionary:
	if handler.is_valid():
		var result = handler.callv(args)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return _call_error("editor_lifecycle_unavailable", fallback_message)


func _call_success(data, message: String) -> Dictionary:
	if _success.is_valid():
		var result = _success.call(data, message)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _call_error(error: String, message: String, data: Dictionary = {}) -> Dictionary:
	if _error.is_valid():
		var result = _error.call(error, message, data)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	var payload := {
		"success": false,
		"error": error,
		"message": message,
		"status": 400
	}
	if not data.is_empty():
		payload["data"] = data.duplicate(true)
	return payload
