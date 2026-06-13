@tool
extends RefCounted
class_name MCPStdioJsonRpcService

## Stdio adapter for the shared JSON-RPC request/router/method stack.
## The stdio transport owns framing and response emission; method dispatch is
## intentionally shared with HTTP to keep protocol behavior in one place.

var _json_rpc_request_service = null
var _json_rpc_router = null
var _json_rpc_method_service = null
var _json_rpc_response_service = null
var _log := Callable()


func configure(context: Dictionary) -> void:
	_json_rpc_request_service = context.get("json_rpc_request_service", null)
	_json_rpc_router = context.get("json_rpc_router", null)
	_json_rpc_method_service = context.get("json_rpc_method_service", null)
	_json_rpc_response_service = context.get("json_rpc_response_service", null)
	_log = context.get("log", Callable())


func dispose() -> void:
	_json_rpc_request_service = null
	_json_rpc_router = null
	_json_rpc_method_service = null
	_json_rpc_response_service = null
	_log = Callable()


func handle_request_async(body: String) -> Dictionary:
	if _json_rpc_request_service == null:
		return _response(_create_json_rpc_error(-32603, "JSON-RPC request service is unavailable", null))
	var response: Dictionary = await _json_rpc_request_service.handle_request_async(body)
	if bool(response.get("_no_body", false)) or int(response.get("status", 0)) == 202:
		return _no_response()
	return _response(response)


func handle_tools_list(id) -> Dictionary:
	if _json_rpc_method_service == null:
		return _create_json_rpc_error(-32603, "JSON-RPC method service is unavailable", id)
	return _json_rpc_method_service.handle_tools_list({}, id)


func handle_tools_call(params, id) -> Dictionary:
	return await handle_tools_call_async(params, id)


func handle_tools_call_async(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	if _json_rpc_router == null:
		return _create_json_rpc_error(-32603, "JSON-RPC router is unavailable", id)
	return await _json_rpc_router.route_request_async("tools/call", params as Dictionary, id, true)


func handle_resources_list(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	if _json_rpc_method_service == null:
		return _create_json_rpc_error(-32603, "JSON-RPC method service is unavailable", id)
	return _json_rpc_method_service.handle_resources_list(params as Dictionary, id)


func handle_resources_templates_list(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	if _json_rpc_method_service == null:
		return _create_json_rpc_error(-32603, "JSON-RPC method service is unavailable", id)
	return _json_rpc_method_service.handle_resources_templates_list(params as Dictionary, id)


func handle_resources_read(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	if _json_rpc_method_service == null:
		return _create_json_rpc_error(-32603, "JSON-RPC method service is unavailable", id)
	return _json_rpc_method_service.handle_resources_read(params as Dictionary, id)


func handle_prompts_list(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	if _json_rpc_method_service == null:
		return _create_json_rpc_error(-32603, "JSON-RPC method service is unavailable", id)
	return _json_rpc_method_service.handle_prompts_list(params as Dictionary, id)


func handle_prompts_get(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	if _json_rpc_method_service == null:
		return _create_json_rpc_error(-32603, "JSON-RPC method service is unavailable", id)
	return _json_rpc_method_service.handle_prompts_get(params as Dictionary, id)


func _response(response: Dictionary) -> Dictionary:
	return {"respond": true, "response": response}


func _no_response() -> Dictionary:
	return {"respond": false, "response": {}}


func _create_json_rpc_error(code: int, message: String, id) -> Dictionary:
	if _json_rpc_response_service != null and _json_rpc_response_service.has_method("build_json_rpc_error"):
		return _json_rpc_response_service.build_json_rpc_error(code, message, id)
	return {"jsonrpc": "2.0", "error": {"code": code, "message": message}, "id": id}


func _log_message(message: String, level: String = "debug") -> void:
	if _log.is_valid():
		_log.call(message, level)
