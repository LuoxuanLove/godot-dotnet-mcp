@tool
extends RefCounted
class_name MCPStdioServiceContextBuilder

## Builds service contexts for the stdio transport.
## Keeps shared MCP service wiring out of the transport parser/framing code.

const MCPResourcesServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service_context.gd")
const MCPPromptsServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service_context.gd")
const MCPToolRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router_context.gd")
const MCPJsonRpcMethodContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_method_context.gd")
const MCPJsonRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_router_context.gd")
const MCPJsonRpcRequestContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_request_context.gd")


func build_tool_rpc_router_context(server, tool_activity_registry = null):
	var context = MCPToolRpcRouterContextScript.new()
	context.get_tool_loader = func(): return server.get("_tool_loader")
	context.is_tool_enabled = Callable(server._service_bundle, "is_tool_enabled")
	context.is_tool_exposed = Callable(server._service_bundle, "is_tool_exposed")
	context.log = Callable(server, "_log")
	context.sanitize_for_json = Callable(server, "_sanitize_for_json")
	context.tool_activity_registry = tool_activity_registry
	return context


func build_resources_service_context(server):
	var context = MCPResourcesServiceContextScript.new()
	context.get_tool_loader = func(): return server.get("_tool_loader")
	context.get_tool_loader_status = Callable(server._service_bundle, "get_stdio_tool_loader_status")
	context.get_tool_activity_registry = Callable(server._service_bundle, "get_stdio_tool_activity_registry")
	context.sanitize_for_json = Callable(server, "_sanitize_for_json")
	return context


func build_prompts_service_context(server):
	var context = MCPPromptsServiceContextScript.new()
	context.get_tool_loader_status = Callable(server._service_bundle, "get_stdio_tool_loader_status")
	return context


func build_json_rpc_method_context(server, tool_rpc_router, resources_service, prompts_service, response_service):
	var context = MCPJsonRpcMethodContextScript.new()
	context.tool_rpc_router = tool_rpc_router
	context.resources_service = resources_service
	context.prompts_service = prompts_service
	context.response_service = response_service
	context.log = Callable(server, "_log")
	return context


func build_json_rpc_router_context(server, json_rpc_method_service, response_service):
	var context = MCPJsonRpcRouterContextScript.new()
	context.handle_initialize = Callable(json_rpc_method_service, "handle_initialize")
	context.handle_tools_list = Callable(json_rpc_method_service, "handle_tools_list")
	context.handle_tools_call_async = Callable(json_rpc_method_service, "handle_tools_call_async")
	context.handle_resources_list = Callable(json_rpc_method_service, "handle_resources_list")
	context.handle_resources_templates_list = Callable(json_rpc_method_service, "handle_resources_templates_list")
	context.handle_resources_read = Callable(json_rpc_method_service, "handle_resources_read")
	context.handle_prompts_list = Callable(json_rpc_method_service, "handle_prompts_list")
	context.handle_prompts_get = Callable(json_rpc_method_service, "handle_prompts_get")
	context.handle_notification = Callable(json_rpc_method_service, "handle_notification")
	context.build_json_rpc_response = Callable(response_service, "build_json_rpc_response")
	context.build_json_rpc_error = Callable(response_service, "build_json_rpc_error")
	context.log = Callable(server, "_log")
	return context


func build_json_rpc_request_context(server, json_rpc_router, response_service):
	var context = MCPJsonRpcRequestContextScript.new()
	context.route_json_rpc_async = Callable(json_rpc_router, "route_request_async")
	context.build_json_rpc_error = Callable(response_service, "build_json_rpc_error")
	context.emit_request_received = func(method: String, params: Dictionary) -> void:
		server.call_deferred("emit_signal", "request_received", method, params)
	context.log = Callable(server, "_log")
	return context
