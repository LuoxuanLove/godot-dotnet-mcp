@tool
extends RefCounted
class_name MCPStdioJsonRpcService

const MCPJsonRpcEnvelopeValidator = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_envelope_validator.gd")
const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")

var _tool_rpc_router = null
var _resources_service = null
var _prompts_service = null
var _get_tool_loader := Callable()
var _emit_request_received := Callable()
var _log := Callable()


func configure(context: Dictionary) -> void:
	_tool_rpc_router = context.get("tool_rpc_router", null)
	_resources_service = context.get("resources_service", null)
	_prompts_service = context.get("prompts_service", null)
	_get_tool_loader = context.get("get_tool_loader", Callable())
	_emit_request_received = context.get("emit_request_received", Callable())
	_log = context.get("log", Callable())


func dispose() -> void:
	_tool_rpc_router = null
	_resources_service = null
	_prompts_service = null
	_get_tool_loader = Callable()
	_emit_request_received = Callable()
	_log = Callable()


func handle_request_async(body: String) -> Dictionary:
	_log_message("Parsing request (%d bytes)" % body.length(), "debug")
	var json := JSON.new()
	if json.parse(body) != OK:
		return _response(_create_json_rpc_error(-32700, "Parse error: %s" % json.get_error_message(), null))

	var request: Variant = json.get_data()
	if not request is Dictionary:
		return _response(_create_json_rpc_error(-32600, "Invalid Request", null))

	var request_dict: Dictionary = request
	if _is_json_rpc_response_envelope(request_dict):
		_log_message("Ignoring JSON-RPC response envelope on stdio input.", "debug")
		return _no_response()
	var envelope_validation := MCPJsonRpcEnvelopeValidator.validate_request_envelope(request_dict)
	var has_id: bool = bool(envelope_validation.get("has_id", false))
	var id: Variant = envelope_validation.get("id")
	if not bool(envelope_validation.get("success", false)):
		return _response(_create_json_rpc_error(
			int(envelope_validation.get("code", -32600)),
			str(envelope_validation.get("message", "Invalid Request")),
			id
		))

	var method: String = str(envelope_validation.get("method", ""))
	var params: Variant = request_dict.get("params", {})
	if not (params is Dictionary):
		if not has_id:
			return _no_response()
		return _response(_create_json_rpc_error(-32602, "Invalid params: expected object", id))
	var params_dict := params as Dictionary

	_log_message("Method: %s" % method, "debug")
	if _emit_request_received.is_valid():
		_emit_request_received.call(method, params_dict)

	if not has_id:
		return _no_response()

	var response: Dictionary
	match method:
		"initialize":
			response = _create_json_rpc_response({
				"protocolVersion": MCPProtocolFacts.get_protocol_version(),
				"toolSchemaVersion": MCPProtocolFacts.get_tool_schema_version(),
				"capabilities": _resources_service.build_server_capabilities(),
				"serverInfo": MCPProtocolFacts.build_server_info()
			}, id)
		"initialized", "notifications/initialized":
			response = _create_json_rpc_response({}, id)
		"tools/list":
			response = handle_tools_list(id)
		"tools/call":
			response = await handle_tools_call_async(params_dict, id)
		"resources/list":
			response = handle_resources_list(params_dict, id)
		"resources/templates/list":
			response = handle_resources_templates_list(params_dict, id)
		"resources/read":
			response = handle_resources_read(params_dict, id)
		"prompts/list":
			response = handle_prompts_list(params_dict, id)
		"prompts/get":
			response = handle_prompts_get(params_dict, id)
		"ping":
			response = _create_json_rpc_response({}, id)
		_:
			response = _create_json_rpc_error(-32601, "Method not found: %s" % method, id)

	return _response(response)


func handle_tools_list(id) -> Dictionary:
	if _get_loader() == null:
		return _create_json_rpc_error(-32603, "Tool loader not initialized", id)
	return _create_json_rpc_response(_tool_rpc_router.build_tools_list_result(), id)


func handle_tools_call(params, id) -> Dictionary:
	return await handle_tools_call_async(params, id)


func handle_tools_call_async(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	var params_dict := params as Dictionary
	if params_dict.has("arguments") and not (params_dict.get("arguments") is Dictionary):
		return _create_json_rpc_response(await _tool_rpc_router.build_tool_call_result_async(params_dict), id)
	if _get_loader() == null:
		return _create_json_rpc_error(-32603, "Tool loader not initialized", id)
	return _create_json_rpc_response(await _tool_rpc_router.build_tool_call_result_async(params_dict), id)


func handle_resources_list(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	return _create_json_rpc_response(_resources_service.build_resources_list_result(params), id)


func handle_resources_templates_list(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	return _create_json_rpc_response(_resources_service.build_resource_templates_list_result(params), id)


func handle_resources_read(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	var result: Dictionary = _resources_service.build_resources_read_result(params)
	if not bool(result.get("success", true)):
		return _create_json_rpc_error(-32602, str(result.get("error", "Resource not found")), id)
	return _create_json_rpc_response(result, id)


func handle_prompts_list(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	return _create_json_rpc_response(_prompts_service.build_prompts_list_result(params), id)


func handle_prompts_get(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	var result: Dictionary = _prompts_service.build_prompts_get_result(params)
	if not bool(result.get("success", true)):
		return _create_json_rpc_error(-32602, str(result.get("error", "Prompt not found")), id)
	return _create_json_rpc_response(result, id)


func _get_loader():
	if _get_tool_loader.is_valid():
		return _get_tool_loader.call()
	return null


func _response(response: Dictionary) -> Dictionary:
	return {"respond": true, "response": response}


func _no_response() -> Dictionary:
	return {"respond": false, "response": {}}


func _create_json_rpc_response(result, id) -> Dictionary:
	return {"jsonrpc": "2.0", "result": result, "id": id}


func _create_json_rpc_error(code: int, message: String, id) -> Dictionary:
	return {"jsonrpc": "2.0", "error": {"code": code, "message": message}, "id": id}


func _is_json_rpc_response_envelope(message: Dictionary) -> bool:
	return str(message.get("jsonrpc", "")) == "2.0" and message.has("id") and (message.has("result") or message.has("error")) and not message.has("method")


func _log_message(message: String, level: String = "debug") -> void:
	if _log.is_valid():
		_log.call(message, level)
