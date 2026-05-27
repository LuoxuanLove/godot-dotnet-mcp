@tool
extends RefCounted
class_name MCPJsonRpcMethodService

const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")

var _tool_rpc_router = null
var _resources_service = null
var _prompts_service = null
var _response_service = null
var _log := Callable()


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_tool_rpc_router = context.tool_rpc_router
	_resources_service = context.resources_service
	_prompts_service = context.prompts_service
	_response_service = context.response_service
	_log = context.log


func dispose() -> void:
	_tool_rpc_router = null
	_resources_service = null
	_prompts_service = null
	_response_service = null
	_log = Callable()


func handle_initialize(_params: Dictionary, id) -> Dictionary:
	var result = {
		"protocolVersion": MCPProtocolFacts.get_protocol_version(),
		"toolSchemaVersion": MCPProtocolFacts.get_tool_schema_version(),
		"capabilities": _build_capabilities(),
		"serverInfo": MCPProtocolFacts.build_server_info()
	}
	return _build_response(result, id)


func handle_tools_list(_params: Dictionary, id) -> Dictionary:
	if _tool_rpc_router == null:
		return _build_error(-32603, "tools/list handler is unavailable", id)
	return _build_response(_tool_rpc_router.build_tools_list_result(), id)


func handle_tools_call_async(params: Dictionary, id) -> Dictionary:
	if _tool_rpc_router == null:
		return _build_error(-32603, "tools/call handler is unavailable", id)
	return _build_response(await _tool_rpc_router.build_tool_call_result_async(params), id)



func handle_resources_list(params: Dictionary, id) -> Dictionary:
	if _resources_service == null:
		return _build_error(-32603, "resources/list handler is unavailable", id)
	return _build_response(_resources_service.build_resources_list_result(params), id)


func handle_resources_templates_list(params: Dictionary, id) -> Dictionary:
	if _resources_service == null:
		return _build_error(-32603, "resources/templates/list handler is unavailable", id)
	return _build_response(_resources_service.build_resource_templates_list_result(params), id)


func handle_resources_read(params: Dictionary, id) -> Dictionary:
	if _resources_service == null:
		return _build_error(-32603, "resources/read handler is unavailable", id)
	var result: Dictionary = _resources_service.build_resources_read_result(params)
	if not bool(result.get("success", true)):
		return _build_error(-32602, str(result.get("error", "Resource not found")), id)
	return _build_response(result, id)

func handle_prompts_list(params: Dictionary, id) -> Dictionary:
	if _prompts_service == null:
		return _build_error(-32603, "prompts/list handler is unavailable", id)
	return _build_response(_prompts_service.build_prompts_list_result(params), id)


func handle_prompts_get(params: Dictionary, id) -> Dictionary:
	if _prompts_service == null:
		return _build_error(-32603, "prompts/get handler is unavailable", id)
	var result: Dictionary = _prompts_service.build_prompts_get_result(params)
	if not bool(result.get("success", true)):
		return _build_error(-32602, str(result.get("error", "Prompt not found")), id)
	return _build_response(result, id)


func _build_capabilities() -> Dictionary:
	if _resources_service != null and _resources_service.has_method("build_server_capabilities"):
		return _resources_service.build_server_capabilities()
	return {
		"tools": {"listChanged": false},
		"resources": {"subscribe": false, "listChanged": false},
		"prompts": {"listChanged": false}
	}

func handle_notification(method: String, _params: Dictionary) -> void:
	match method:
		"initialized", "notifications/initialized":
			_log_message("Client initialized", "info")
		"notifications/cancelled":
			_log_message("Request cancelled by client", "debug")
		_:
			_log_message("Notification received: %s" % method, "debug")


func _build_response(result, id) -> Dictionary:
	if _response_service != null and _response_service.has_method("build_json_rpc_response"):
		return _response_service.build_json_rpc_response(result, id)
	return {
		"jsonrpc": "2.0",
		"result": result,
		"id": id
	}


func _build_error(code: int, message: String, id) -> Dictionary:
	if _response_service != null and _response_service.has_method("build_json_rpc_error"):
		return _response_service.build_json_rpc_error(code, message, id)
	return {
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message
		},
		"id": id
	}


func _log_message(message: String, level: String) -> void:
	if _log.is_valid():
		_log.call(message, level)
