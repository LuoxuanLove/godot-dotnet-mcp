@tool
extends RefCounted
class_name MCPJsonRpcRouter

var _handle_initialize := Callable()
var _handle_tools_list := Callable()
var _handle_tools_call_async := Callable()
var _handle_notification := Callable()
var _build_json_rpc_response := Callable()
var _build_json_rpc_error := Callable()
var _log := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_handle_initialize = callbacks.get("handle_initialize", Callable())
	_handle_tools_list = callbacks.get("handle_tools_list", Callable())
	_handle_tools_call_async = callbacks.get("handle_tools_call_async", Callable())
	_handle_notification = callbacks.get("handle_notification", Callable())
	_build_json_rpc_response = callbacks.get("build_json_rpc_response", Callable())
	_build_json_rpc_error = callbacks.get("build_json_rpc_error", Callable())
	_log = callbacks.get("log", Callable())


func route_request_async(method: String, params: Dictionary, id, has_id: bool) -> Dictionary:
	if not has_id:
		_call_notification(method, params)
		return {"status": 202, "_no_body": true}

	var response: Dictionary = {}
	match method:
		"initialize":
			response = _call_dict(_handle_initialize, [params, id], _method_unavailable("initialize", id))
		"initialized", "notifications/initialized":
			response = _build_empty_response(id)
		"tools/list":
			response = _call_dict(_handle_tools_list, [params, id], _method_unavailable("tools/list", id))
		"tools/call":
			response = await _call_async(_handle_tools_call_async, [params, id], _method_unavailable("tools/call", id))
		"ping":
			response = _build_empty_response(id)
		_:
			response = _build_error_response(-32601, "Method not found: %s" % method, id)

	_log_message("Response ready for method: %s" % method, "debug")
	return response


func _build_empty_response(id) -> Dictionary:
	return _build_response({}, id)


func _build_response(result, id) -> Dictionary:
	if _build_json_rpc_response.is_valid():
		var response = _build_json_rpc_response.call(result, id)
		if response is Dictionary:
			return (response as Dictionary).duplicate(true)
	return {
		"jsonrpc": "2.0",
		"result": result,
		"id": id
	}


func _build_error_response(code: int, message: String, id) -> Dictionary:
	if _build_json_rpc_error.is_valid():
		var response = _build_json_rpc_error.call(code, message, id)
		if response is Dictionary:
			return (response as Dictionary).duplicate(true)
	return {
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message
		},
		"id": id
	}


func _call_dict(callable_obj: Callable, args: Array, fallback: Dictionary) -> Dictionary:
	if callable_obj.is_valid():
		var result = callable_obj.callv(args)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return fallback.duplicate(true)


func _call_async(callable_obj: Callable, args: Array, fallback: Dictionary) -> Dictionary:
	if callable_obj.is_valid():
		var result = callable_obj.callv(args)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
		if result != null:
			result = await result
			if result is Dictionary:
				return (result as Dictionary).duplicate(true)
	return fallback.duplicate(true)


func _call_notification(method: String, params: Dictionary) -> void:
	if _handle_notification.is_valid():
		_handle_notification.call(method, params)


func _method_unavailable(method_name: String, id) -> Dictionary:
	return _build_error_response(-32603, "%s handler is unavailable" % method_name, id)


func _log_message(message: String, level: String) -> void:
	if _log.is_valid():
		_log.call(message, level)
