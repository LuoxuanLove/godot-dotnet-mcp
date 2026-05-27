@tool
extends RefCounted
class_name MCPHttpServiceContextBuilder

const MCPToolLoaderSupervisorContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_loader_supervisor_context.gd")
const MCPToolRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router_context.gd")
const MCPEditorLifecycleEndpointContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_endpoint_context.gd")
const MCPEditorLifecycleActionContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_action_context.gd")
const MCPEditorLifecycleStateBuilderContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_state_builder_context.gd")
const MCPHttpRequestRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router_context.gd")
const MCPJsonRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_router_context.gd")
const MCPJsonRpcMethodContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_method_context.gd")
const MCPResourcesServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service_context.gd")
const MCPPromptsServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service_context.gd")
const MCPJsonRpcRequestContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_request_context.gd")
const MCPToolsApiServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service_context.gd")
const MCPHttpResponseContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_response_context.gd")
const MCPHttpTransportContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_transport_context.gd")
const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const MCPEditorSessionIdentity = preload("res://addons/godot_dotnet_mcp/plugin/runtime/editor_session_identity.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

func build_tool_loader_supervisor_context(server):
	var context = MCPToolLoaderSupervisorContextScript.new()
	context.log = func(message: String, level: String = "debug") -> void:
		MCPDebugBuffer.record(level, "server", message)
		if bool(server.get("_debug_mode")):
			print("[MCP] " + message)
	context.record_registration_issue = func(level: String, reason: String, status: Dictionary, summary: Dictionary) -> void:
		if level == "error":
			PluginSelfDiagnosticStore.record_incident(
				"error", "tool_load_error", "tool_registry_empty_after_register",
				"Tool registration completed with no exposed tools",
				"mcp_http_server", "register_tools", "", "", "", true,
				"Inspect the visibility filters, disabled tool list, and tool loader registration summary.",
				{
					"reason": reason,
					"status": str(status.get("status", "unknown")),
					"tool_count": int(summary.get("tool_count", 0)),
					"exposed_tool_count": int(summary.get("exposed_tool_count", 0)),
					"category_count": int(summary.get("category_count", 0)),
					"tool_load_error_count": int(summary.get("tool_load_error_count", 0))
				}
			)
		elif int(summary.get("tool_load_error_count", 0)) > 0:
			var warning_message = "Skipped %d tool categories due to load errors" % int(summary.get("tool_load_error_count", 0))
			MCPDebugBuffer.record("warning", "server", warning_message)
			if bool(server.get("_debug_mode")):
				print("[MCP] " + warning_message)
			PluginSelfDiagnosticStore.record_incident(
				"warning", "tool_load_error", "tool_domain_load_failed",
				"One or more tool domains were skipped during server registration",
				"mcp_http_server", "register_tools", "", "", "", true,
				"Inspect the tool loader load-error list and editor output for the failing categories.",
				{"tool_load_error_count": int(summary.get("tool_load_error_count", 0))}
			)
	return context

func build_tool_rpc_router_context(server, tool_loader_supervisor, http_response_service):
	var context = MCPToolRpcRouterContextScript.new()
	context.get_tool_loader = Callable(tool_loader_supervisor, "get_tool_loader")
	context.is_tool_enabled = Callable(tool_loader_supervisor, "is_tool_enabled")
	context.is_tool_exposed = Callable(tool_loader_supervisor, "is_tool_exposed")
	context.log = func(message: String, level: String = "debug") -> void:
		MCPDebugBuffer.record(level, "server", message)
		if bool(server.get("_debug_mode")):
			print("[MCP] " + message)
	context.sanitize_for_json = Callable(http_response_service, "sanitize_for_json")
	return context

func build_http_request_router_context(json_rpc_request_service, http_response_service, tools_api_service, editor_lifecycle_endpoint):
	var context = MCPHttpRequestRouterContextScript.new()
	context.handle_mcp_request_async = Callable(json_rpc_request_service, "handle_request_async")
	context.build_health_response = Callable(http_response_service, "build_health_response")
	context.build_tools_list_response = Callable(tools_api_service, "build_tools_list_response")
	context.handle_editor_lifecycle_request = Callable(editor_lifecycle_endpoint, "handle_request")
	context.handle_editor_lifecycle_post_request = Callable(editor_lifecycle_endpoint, "handle_post_request")
	context.build_cors_response = Callable(http_response_service, "build_cors_response")
	return context

func build_http_transport_context(server, tool_loader_supervisor, http_request_router, http_response_service):
	var context = MCPHttpTransportContextScript.new()
	context.log = func(message: String, level: String = "debug") -> void:
		MCPDebugBuffer.record(level, "server", message)
		if bool(server.get("_debug_mode")):
			print("[MCP] " + message)
	context.emit_client_connected = func() -> void:
		server.call_deferred("emit_signal", "client_connected")
	context.emit_client_disconnected = func() -> void:
		server.call_deferred("emit_signal", "client_disconnected")
	context.route_request_async = Callable(http_request_router, "route_request_async")
	context.write_http_response = Callable(http_response_service, "send_http_response")
	context.tick_loader = Callable(tool_loader_supervisor, "tick")
	return context

func build_json_rpc_router_context(server, json_rpc_method_service, http_response_service):
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
	context.build_json_rpc_response = Callable(http_response_service, "build_json_rpc_response")
	context.build_json_rpc_error = Callable(http_response_service, "build_json_rpc_error")
	context.log = func(message: String, level: String = "debug") -> void:
		MCPDebugBuffer.record(level, "server", message)
		if bool(server.get("_debug_mode")):
			print("[MCP] " + message)
	return context

func build_tools_api_service_context(tool_loader_supervisor):
	var context = MCPToolsApiServiceContextScript.new()
	context.get_tool_loader = Callable(tool_loader_supervisor, "get_tool_loader")
	context.get_tool_loader_status = Callable(tool_loader_supervisor, "get_status")
	return context

func build_http_response_context(server, tool_loader_supervisor):
	var context = MCPHttpResponseContextScript.new()
	var server_facts = MCPProtocolFacts.build_server_facts()
	context.get_tool_loader = Callable(tool_loader_supervisor, "get_tool_loader")
	context.get_tool_loader_status = Callable(tool_loader_supervisor, "get_status")
	context.get_server_stats = func() -> Dictionary:
		var connection_stats = server.get_connection_stats()
		var listen_endpoint = server.get_listen_endpoint() if server.has_method("get_listen_endpoint") else {}
		return {
			"running": server.is_running(),
			"listen_host": str(listen_endpoint.get("host", connection_stats.get("listen_host", ""))),
			"listen_port": int(listen_endpoint.get("port", connection_stats.get("listen_port", 0))),
			"listen_url": str(listen_endpoint.get("url", connection_stats.get("listen_url", ""))),
			"connections": int(connection_stats.get("connections", 0)),
			"total_connections": int(connection_stats.get("total_connections", 0)),
			"total_requests": int(connection_stats.get("total_requests", 0)),
			"last_request_method": str(connection_stats.get("last_request_method", "")),
			"last_request_at_unix": int(connection_stats.get("last_request_at_unix", 0))
		}
	context.get_editor_session_identity = func() -> Dictionary:
		var endpoint = server.get_listen_endpoint() if server.has_method("get_listen_endpoint") else {}
		return MCPEditorSessionIdentity.build_identity(endpoint)
	context.get_freshness_snapshot = func() -> Dictionary:
		return PluginInstanceFreshness.get_freshness_snapshot()
	context.log = func(message: String, level: String = "debug") -> void:
		MCPDebugBuffer.record(level, "server", message)
		if bool(server.get("_debug_mode")):
			print("[MCP] " + message)
	context.server_name = str(server_facts.get("server_name", ""))
	context.server_version = str(server_facts.get("server_version", ""))
	context.protocol_version = str(server_facts.get("protocol_version", ""))
	context.tool_schema_version = str(server_facts.get("tool_schema_version", ""))
	return context

func build_editor_lifecycle_state_builder_context(server):
	var context = MCPEditorLifecycleStateBuilderContextScript.new()
	context.get_plugin_host = func():
		var plugin = server.get_parent()
		if plugin == null or not is_instance_valid(plugin):
			return null
		return plugin
	return context

func build_editor_lifecycle_action_context(server, editor_lifecycle_state_builder, editor_lifecycle_response_builder):
	var context = MCPEditorLifecycleActionContextScript.new()
	context.build_state = Callable(editor_lifecycle_state_builder, "build_state")
	context.build_state_with_hint = Callable(editor_lifecycle_state_builder, "build_state_with_hint")
	context.build_success = Callable(editor_lifecycle_response_builder, "build_success")
	context.build_error = Callable(editor_lifecycle_response_builder, "build_error")
	context.schedule_action = func(action: String) -> void:
		server._ensure_service_bundle()
		server._service_bundle.get_editor_lifecycle_action_service().run_deferred_action(action)
	context.get_plugin_host = func():
		var plugin = server.get_parent()
		if plugin == null or not is_instance_valid(plugin):
			return null
		return plugin
	context.log = func(message: String, level: String = "debug") -> void:
		MCPDebugBuffer.record(level, "server", message)
		if bool(server.get("_debug_mode")):
			print("[MCP] " + message)
	return context

func build_editor_lifecycle_endpoint_context(editor_lifecycle_state_builder, editor_lifecycle_action_service, editor_lifecycle_response_builder):
	var context = MCPEditorLifecycleEndpointContextScript.new()
	context.build_state = Callable(editor_lifecycle_state_builder, "build_state")
	context.execute_close = Callable(editor_lifecycle_action_service, "execute_close")
	context.execute_restart = Callable(editor_lifecycle_action_service, "execute_restart")
	context.build_success = Callable(editor_lifecycle_response_builder, "build_success")
	context.build_error = Callable(editor_lifecycle_response_builder, "build_error")
	return context

func build_json_rpc_method_context(server, tool_rpc_router, resources_service, prompts_service, http_response_service):
	var context = MCPJsonRpcMethodContextScript.new()
	context.tool_rpc_router = tool_rpc_router
	context.resources_service = resources_service
	context.prompts_service = prompts_service
	context.response_service = http_response_service
	context.log = func(message: String, level: String = "debug") -> void:
		MCPDebugBuffer.record(level, "server", message)
		if bool(server.get("_debug_mode")):
			print("[MCP] " + message)
	return context

func build_json_rpc_request_context(server, json_rpc_router, http_response_service):
	var context = MCPJsonRpcRequestContextScript.new()
	context.route_json_rpc_async = Callable(json_rpc_router, "route_request_async")
	context.build_json_rpc_error = Callable(http_response_service, "build_json_rpc_error")
	context.emit_request_received = func(method: String, params: Dictionary) -> void:
		server.call_deferred("emit_signal", "request_received", method, params)
	context.log = func(message: String, level: String = "debug") -> void:
		MCPDebugBuffer.record(level, "server", message)
		if bool(server.get("_debug_mode")):
			print("[MCP] " + message)
	return context


func build_resources_service_context(tool_loader_supervisor, http_response_service):
	var context = MCPResourcesServiceContextScript.new()
	context.get_tool_loader = Callable(tool_loader_supervisor, "get_tool_loader")
	context.get_tool_loader_status = Callable(tool_loader_supervisor, "get_status")
	context.sanitize_for_json = Callable(http_response_service, "sanitize_for_json")
	return context

func build_prompts_service_context(tool_loader_supervisor):
	var context = MCPPromptsServiceContextScript.new()
	context.get_tool_loader_status = Callable(tool_loader_supervisor, "get_status")
	return context
