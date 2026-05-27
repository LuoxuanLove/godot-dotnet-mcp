@tool
extends RefCounted
class_name MCPHttpServiceBundle

const MCPHttpServiceContextBuilderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_service_context_builder.gd")
const MCPToolLoaderSupervisorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_loader_supervisor.gd")
const MCPToolRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router.gd")
const MCPEditorLifecycleEndpointScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_endpoint.gd")
const MCPEditorLifecycleActionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_action_service.gd")
const MCPEditorLifecycleStateBuilderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_state_builder.gd")
const MCPEditorLifecycleResponseBuilderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_response_builder.gd")
const MCPHttpRequestRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router.gd")
const MCPHttpRequestDecoderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_decoder.gd")
const MCPJsonRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_router.gd")
const MCPJsonRpcMethodServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_method_service.gd")
const MCPResourcesServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service.gd")
const MCPPromptsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service.gd")
const MCPJsonRpcRequestServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_request_service.gd")
const MCPToolsApiServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service.gd")
const MCPHttpResponseServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_response_service.gd")
const MCPHttpTransportServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_transport_service.gd")
const MCPRuntimeControlServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/runtime_control_service.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _server = null
var _connection_state = null
var _context_builder = MCPHttpServiceContextBuilderScript.new()
var _tool_loader_supervisor = null
var _tool_rpc_router = null
var _editor_lifecycle_endpoint = null
var _editor_lifecycle_action_service = null
var _editor_lifecycle_state_builder = null
var _editor_lifecycle_response_builder = null
var _http_request_router = null
var _http_request_decoder = null
var _json_rpc_router = null
var _json_rpc_method_service = null
var _resources_service = null
var _prompts_service = null
var _json_rpc_request_service = null
var _tools_api_service = null
var _http_response_service = null
var _http_transport_service = null
var _runtime_control_service = null


func configure(server, connection_state) -> void:
	_server = server
	_connection_state = connection_state


func ensure_initialized() -> void:
	_ensure_tool_loader_supervisor()
	_ensure_http_response_service()
	_ensure_http_request_router()
	_ensure_http_request_decoder()
	_ensure_tools_api_service()
	_ensure_editor_lifecycle_endpoint()
	_ensure_runtime_control_service()


func get_tool_loader_supervisor():
	_ensure_tool_loader_supervisor()
	return _tool_loader_supervisor


func get_editor_lifecycle_endpoint():
	_ensure_editor_lifecycle_endpoint()
	return _editor_lifecycle_endpoint


func get_editor_lifecycle_action_service():
	_ensure_editor_lifecycle_action_service()
	return _editor_lifecycle_action_service


func get_json_rpc_request_service():
	_ensure_json_rpc_request_service()
	return _json_rpc_request_service


func get_tools_api_service():
	_ensure_tools_api_service()
	return _tools_api_service


func get_http_transport_service():
	_ensure_http_transport_service()
	return _http_transport_service


func get_runtime_control_service():
	_ensure_runtime_control_service()
	return _runtime_control_service


func dispose() -> void:
	if _runtime_control_service != null and _runtime_control_service.has_method("reset"):
		_runtime_control_service.reset()
	if _tool_loader_supervisor != null and _tool_loader_supervisor.has_method("dispose"):
		_tool_loader_supervisor.dispose()
	_dispose_helper(_tool_rpc_router)
	_dispose_helper(_editor_lifecycle_endpoint)
	_dispose_helper(_editor_lifecycle_action_service)
	_dispose_helper(_editor_lifecycle_state_builder)
	_dispose_helper(_editor_lifecycle_response_builder)
	_dispose_helper(_http_request_router)
	_dispose_helper(_http_request_decoder)
	_dispose_helper(_json_rpc_router)
	_dispose_helper(_json_rpc_method_service)
	_dispose_helper(_resources_service)
	_dispose_helper(_prompts_service)
	_dispose_helper(_json_rpc_request_service)
	_dispose_helper(_tools_api_service)
	_dispose_helper(_http_response_service)
	_dispose_helper(_http_transport_service)
	_tool_loader_supervisor = null
	_tool_rpc_router = null
	_editor_lifecycle_endpoint = null
	_editor_lifecycle_action_service = null
	_editor_lifecycle_state_builder = null
	_editor_lifecycle_response_builder = null
	_http_request_router = null
	_http_request_decoder = null
	_json_rpc_router = null
	_json_rpc_method_service = null
	_resources_service = null
	_prompts_service = null
	_json_rpc_request_service = null
	_tools_api_service = null
	_http_response_service = null
	_http_transport_service = null
	_runtime_control_service = null
	_connection_state = null
	_server = null


func _ensure_tool_loader_supervisor() -> void:
	if _tool_loader_supervisor == null:
		_tool_loader_supervisor = MCPToolLoaderSupervisorScript.new()
	_tool_loader_supervisor.configure(_server, _context_builder.build_tool_loader_supervisor_context(_server))


func _ensure_runtime_control_service() -> void:
	if _runtime_control_service == null:
		_runtime_control_service = MCPRuntimeControlServiceScript.new()
	var plugin = _server.get_parent()
	var debugger_bridge = null
	if plugin != null and plugin.has_method("get_editor_debugger_bridge"):
		debugger_bridge = plugin.get_editor_debugger_bridge()
	_runtime_control_service.configure(plugin, debugger_bridge, func(message: String, level: String = "debug") -> void:
		MCPDebugBuffer.record(level, "server", message)
		if _server != null and bool(_server.get("_debug_mode")):
			print("[MCP] " + message)
	)


func _ensure_tool_rpc_router() -> void:
	if _tool_rpc_router == null:
		_tool_rpc_router = MCPToolRpcRouterScript.new()
	_ensure_tool_loader_supervisor()
	_ensure_http_response_service()
	_tool_rpc_router.configure(_context_builder.build_tool_rpc_router_context(_server, _tool_loader_supervisor, _http_response_service))


func _ensure_http_request_router() -> void:
	if _http_request_router == null:
		_http_request_router = MCPHttpRequestRouterScript.new()
	_ensure_json_rpc_request_service()
	_ensure_tools_api_service()
	_ensure_editor_lifecycle_endpoint()
	_ensure_http_response_service()
	_http_request_router.configure(
		_context_builder.build_http_request_router_context(
			_json_rpc_request_service,
			_http_response_service,
			_tools_api_service,
			_editor_lifecycle_endpoint
		)
	)
	if _server != null and _http_request_router.has_method("set_allowed_hosts"):
		_http_request_router.set_allowed_hosts([str(_server.get("_host"))])


func _ensure_http_request_decoder() -> void:
	if _http_request_decoder == null:
		_http_request_decoder = MCPHttpRequestDecoderScript.new()


func _ensure_http_transport_service() -> void:
	if _http_transport_service == null:
		_http_transport_service = MCPHttpTransportServiceScript.new()
	_ensure_tool_loader_supervisor()
	_ensure_http_request_router()
	_ensure_http_response_service()
	_ensure_http_request_decoder()
	_http_transport_service.configure(
		_connection_state,
		_http_request_decoder,
		_context_builder.build_http_transport_context(
			_server,
			_tool_loader_supervisor,
			_http_request_router,
			_http_response_service
		)
	)


func _ensure_json_rpc_router() -> void:
	if _json_rpc_router == null:
		_json_rpc_router = MCPJsonRpcRouterScript.new()
	_ensure_json_rpc_method_service()
	_ensure_http_response_service()
	_json_rpc_router.configure(_context_builder.build_json_rpc_router_context(_server, _json_rpc_method_service, _http_response_service))


func _ensure_json_rpc_method_service() -> void:
	if _json_rpc_method_service == null:
		_json_rpc_method_service = MCPJsonRpcMethodServiceScript.new()
	_ensure_tool_rpc_router()
	_ensure_resources_service()
	_ensure_prompts_service()
	_ensure_http_response_service()
	_json_rpc_method_service.configure(_context_builder.build_json_rpc_method_context(_server, _tool_rpc_router, _resources_service, _prompts_service, _http_response_service))


func _ensure_resources_service() -> void:
	if _resources_service == null:
		_resources_service = MCPResourcesServiceScript.new()
	_ensure_tool_loader_supervisor()
	_ensure_http_response_service()
	_resources_service.configure(_context_builder.build_resources_service_context(_tool_loader_supervisor, _http_response_service))


func _ensure_prompts_service() -> void:
	if _prompts_service == null:
		_prompts_service = MCPPromptsServiceScript.new()
	_ensure_tool_loader_supervisor()
	_prompts_service.configure(_context_builder.build_prompts_service_context(_tool_loader_supervisor))


func _ensure_json_rpc_request_service() -> void:
	if _json_rpc_request_service == null:
		_json_rpc_request_service = MCPJsonRpcRequestServiceScript.new()
	_ensure_json_rpc_router()
	_ensure_http_response_service()
	_json_rpc_request_service.configure(_context_builder.build_json_rpc_request_context(_server, _json_rpc_router, _http_response_service))


func _ensure_editor_lifecycle_endpoint() -> void:
	if _editor_lifecycle_endpoint == null:
		_editor_lifecycle_endpoint = MCPEditorLifecycleEndpointScript.new()
	_ensure_editor_lifecycle_action_service()
	_ensure_editor_lifecycle_state_builder()
	_ensure_editor_lifecycle_response_builder()
	_editor_lifecycle_endpoint.configure(
		_context_builder.build_editor_lifecycle_endpoint_context(
			_editor_lifecycle_state_builder,
			_editor_lifecycle_action_service,
			_editor_lifecycle_response_builder
		)
	)


func _ensure_tools_api_service() -> void:
	if _tools_api_service == null:
		_tools_api_service = MCPToolsApiServiceScript.new()
	_ensure_tool_loader_supervisor()
	_tools_api_service.configure(_context_builder.build_tools_api_service_context(_tool_loader_supervisor))


func _ensure_editor_lifecycle_state_builder() -> void:
	if _editor_lifecycle_state_builder == null:
		_editor_lifecycle_state_builder = MCPEditorLifecycleStateBuilderScript.new()
	_editor_lifecycle_state_builder.configure(_context_builder.build_editor_lifecycle_state_builder_context(_server))


func _ensure_editor_lifecycle_response_builder() -> void:
	if _editor_lifecycle_response_builder == null:
		_editor_lifecycle_response_builder = MCPEditorLifecycleResponseBuilderScript.new()


func _ensure_editor_lifecycle_action_service() -> void:
	if _editor_lifecycle_action_service == null:
		_editor_lifecycle_action_service = MCPEditorLifecycleActionServiceScript.new()
	_ensure_editor_lifecycle_state_builder()
	_ensure_editor_lifecycle_response_builder()
	_editor_lifecycle_action_service.configure(
		_context_builder.build_editor_lifecycle_action_context(
			_server,
			_editor_lifecycle_state_builder,
			_editor_lifecycle_response_builder
		)
	)


func _ensure_http_response_service() -> void:
	if _http_response_service == null:
		_http_response_service = MCPHttpResponseServiceScript.new()
	_ensure_tool_loader_supervisor()
	_http_response_service.configure(_context_builder.build_http_response_context(_server, _tool_loader_supervisor))


func _dispose_helper(service) -> void:
	if service == null:
		return
	if service.has_method("dispose"):
		service.dispose()
