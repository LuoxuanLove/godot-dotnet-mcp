@tool
extends RefCounted
class_name MCPStdioServiceContextBuilder

## Builds service contexts for the stdio transport.
## Keeps shared MCP service wiring out of the transport parser/framing code.

const MCPResourcesServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service_context.gd")
const MCPPromptsServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service_context.gd")
const MCPToolRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router_context.gd")


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
