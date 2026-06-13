@tool
extends RefCounted
class_name MCPStdioServiceBundle

const MCPResourcesServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service.gd")
const MCPPromptsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service.gd")
const MCPToolActivityRegistry = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")
const MCPToolRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router.gd")
const MCPStdioJsonRpcServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_json_rpc_service.gd")
const MCPStdioServiceContextBuilderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_service_context_builder.gd")

var _server = null
var _context_builder = MCPStdioServiceContextBuilderScript.new()
var _resources_service = null
var _prompts_service = null
var _tool_rpc_router = null
var _tool_activity_registry = MCPToolActivityRegistry.new()
var _json_rpc_service = null


func configure(server) -> void:
	_server = server
	ensure_initialized()


func ensure_initialized() -> void:
	_ensure_tool_activity_registry()
	_ensure_tool_rpc_router()
	_ensure_resources_service()
	_ensure_prompts_service()
	_ensure_json_rpc_service()


func dispose() -> void:
	_dispose_helper(_resources_service)
	_dispose_helper(_prompts_service)
	_dispose_helper(_tool_rpc_router)
	_dispose_helper(_json_rpc_service)
	_resources_service = null
	_prompts_service = null
	_tool_rpc_router = null
	_json_rpc_service = null
	_tool_activity_registry = null
	_context_builder = null
	_server = null


func handle_request_async(body: String) -> Dictionary:
	_ensure_json_rpc_service()
	return await _json_rpc_service.handle_request_async(body)


func handle_tools_list(id) -> Dictionary:
	_ensure_json_rpc_service()
	return _json_rpc_service.handle_tools_list(id)


func handle_tools_call(params, id) -> Dictionary:
	return await handle_tools_call_async(params, id)


func handle_tools_call_async(params, id) -> Dictionary:
	_ensure_json_rpc_service()
	return await _json_rpc_service.handle_tools_call_async(params, id)


func handle_resources_list(params, id) -> Dictionary:
	_ensure_json_rpc_service()
	return _json_rpc_service.handle_resources_list(params, id)


func handle_resources_templates_list(params, id) -> Dictionary:
	_ensure_json_rpc_service()
	return _json_rpc_service.handle_resources_templates_list(params, id)


func handle_resources_read(params, id) -> Dictionary:
	_ensure_json_rpc_service()
	return _json_rpc_service.handle_resources_read(params, id)


func handle_prompts_list(params, id) -> Dictionary:
	_ensure_json_rpc_service()
	return _json_rpc_service.handle_prompts_list(params, id)


func handle_prompts_get(params, id) -> Dictionary:
	_ensure_json_rpc_service()
	return _json_rpc_service.handle_prompts_get(params, id)


func get_stdio_tool_activity_registry():
	var loader = _get_tool_loader()
	if loader != null and loader.has_method("get_tool_activity_registry"):
		var registry = loader.get_tool_activity_registry()
		if registry != null:
			return registry
	return _tool_activity_registry


func get_stdio_tool_loader_status() -> Dictionary:
	var loader = _get_tool_loader()
	if loader == null:
		return {"initialized": false, "healthy": false, "status": "unavailable", "tool_count": 0, "exposed_tool_count": 0}
	var tool_count := 0
	if loader.has_method("get_tool_definitions"):
		tool_count = loader.get_tool_definitions().size()
	var exposed_tool_count := 0
	if loader.has_method("get_exposed_tool_definitions"):
		exposed_tool_count = loader.get_exposed_tool_definitions().size()
	return {"initialized": true, "healthy": true, "status": "ready", "tool_count": tool_count, "exposed_tool_count": exposed_tool_count}


func is_tool_enabled(tool_name: String) -> bool:
	if _server != null and _server.has_method("_is_stdio_tool_disabled") and bool(_server.call("_is_stdio_tool_disabled", tool_name)):
		return false
	var loader = _get_tool_loader()
	if loader != null and loader.has_method("is_tool_enabled"):
		return bool(loader.is_tool_enabled(tool_name))
	return true


func is_tool_exposed(tool_name: String) -> bool:
	var loader = _get_tool_loader()
	if loader != null and loader.has_method("is_tool_exposed"):
		return bool(loader.is_tool_exposed(tool_name))
	return false


func normalize_tool_result(result) -> Dictionary:
	_ensure_tool_rpc_router()
	return _tool_rpc_router.call("_normalize_tool_result", result)


func _ensure_tool_activity_registry() -> void:
	if _tool_activity_registry == null:
		_tool_activity_registry = MCPToolActivityRegistry.new()
	var loader = _get_tool_loader()
	if loader == null or not loader.has_method("set_tool_activity_registry"):
		return
	if loader.has_method("get_tool_activity_registry") and loader.get_tool_activity_registry() != null:
		return
	loader.set_tool_activity_registry(_tool_activity_registry)


func _ensure_tool_rpc_router() -> void:
	if _tool_rpc_router == null:
		_tool_rpc_router = MCPToolRpcRouterScript.new()
	if _context_builder == null:
		_context_builder = MCPStdioServiceContextBuilderScript.new()
	_ensure_tool_activity_registry()
	_tool_rpc_router.configure(_context_builder.build_tool_rpc_router_context(_server, get_stdio_tool_activity_registry()))


func _ensure_resources_service() -> void:
	if _resources_service == null:
		_resources_service = MCPResourcesServiceScript.new()
	if _context_builder == null:
		_context_builder = MCPStdioServiceContextBuilderScript.new()
	_ensure_tool_activity_registry()
	_resources_service.configure(_context_builder.build_resources_service_context(_server))


func _ensure_prompts_service() -> void:
	if _prompts_service == null:
		_prompts_service = MCPPromptsServiceScript.new()
	if _context_builder == null:
		_context_builder = MCPStdioServiceContextBuilderScript.new()
	_prompts_service.configure(_context_builder.build_prompts_service_context(_server))


func _ensure_json_rpc_service() -> void:
	if _json_rpc_service == null:
		_json_rpc_service = MCPStdioJsonRpcServiceScript.new()
	_ensure_tool_rpc_router()
	_ensure_resources_service()
	_ensure_prompts_service()
	var get_tool_loader_callback := func(): return _get_tool_loader()
	var emit_request_received_callback := func(method: String, params: Dictionary) -> void:
		if _server != null:
			_server.call_deferred("emit_signal", "request_received", method, params)
	var log_callback := func(message: String, level: String = "debug") -> void:
		if _server != null:
			_server.call("_log", message, level)
	_json_rpc_service.configure({
		"tool_rpc_router": _tool_rpc_router,
		"resources_service": _resources_service,
		"prompts_service": _prompts_service,
		"get_tool_loader": get_tool_loader_callback,
		"emit_request_received": emit_request_received_callback,
		"log": log_callback
	})


func _get_tool_loader():
	if _server != null:
		return _server.get("_tool_loader")
	return null


func _dispose_helper(service) -> void:
	if service != null and service.has_method("dispose"):
		service.dispose()
