@tool
extends Node
class_name MCPHttpServer

## MCP Server for Godot Engine
## Implements HTTP server with JSON-RPC 2.0 protocol for MCP communication

const MCPToolLoader = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
const MCPToolLoaderSupervisorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_loader_supervisor.gd")
const MCPToolRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router.gd")
const MCPEditorLifecycleEndpointScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_endpoint.gd")
const MCPEditorLifecycleActionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_action_service.gd")
const MCPEditorLifecycleStateBuilderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_state_builder.gd")
const MCPHttpRequestRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router.gd")
const MCPJsonRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_router.gd")
const MCPToolsApiServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service.gd")
const MCPHttpResponseServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_response_service.gd")
const MCPRuntimeControlServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/runtime_control_service.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPDefaultToolPermissionProviderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/default_tool_permission_provider.gd")
const GDScriptLspDiagnosticsService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd")
const GDScriptLspDiagnosticsServicePath = "res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd"
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

signal server_started
signal server_stopped
signal client_connected
signal client_disconnected
signal request_received(method: String, params: Dictionary)

var _tcp_server: TCPServer
var _port: int = 3000
var _host: String = "127.0.0.1"
var _running: bool = false
var _debug_mode: bool = false
var _clients: Array[StreamPeerTCP] = []
var _pending_data: Dictionary = {}  # client -> accumulated data
var _processing_clients: Dictionary = {}
var _total_connections: int = 0
var _total_requests: int = 0
var _last_request_method: String = ""
var _last_request_at_unix: int = 0

var _tool_loader_supervisor = MCPToolLoaderSupervisorScript.new()
var _tool_rpc_router = MCPToolRpcRouterScript.new()
var _editor_lifecycle_endpoint = MCPEditorLifecycleEndpointScript.new()
var _editor_lifecycle_action_service = MCPEditorLifecycleActionServiceScript.new()
var _editor_lifecycle_state_builder = MCPEditorLifecycleStateBuilderScript.new()
var _http_request_router = MCPHttpRequestRouterScript.new()
var _json_rpc_router = MCPJsonRpcRouterScript.new()
var _tools_api_service = MCPToolsApiServiceScript.new()
var _http_response_service = MCPHttpResponseServiceScript.new()
var _runtime_control_service = MCPRuntimeControlServiceScript.new()
var _gdscript_lsp_diagnostics_service
var _default_permission_provider = MCPDefaultToolPermissionProviderScript.new()

# MCP Protocol info
const MCP_VERSION = "2025-06-18"
const SERVER_NAME = "godot-mcp-server"
const SERVER_VERSION = "0.5.0"


func _ready() -> void:
	set_process(true)
	_ensure_initialized()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		dispose()


func _log(message: String, level: String = "debug") -> void:
	MCPDebugBuffer.record(level, "server", message)
	if _debug_mode:
		print("[MCP] " + message)


func _process(_delta: float) -> void:
	if not _running:
		return

	# Accept new connections
	if _tcp_server.is_connection_available():
		var client = _tcp_server.take_connection()
		if client:
			_clients.append(client)
			_pending_data[client] = ""
			_total_connections += 1
			_log("Client connected (total: %d)" % _clients.size(), "info")
			client_connected.emit()

	# Process existing clients
	var clients_to_remove: Array[StreamPeerTCP] = []
	for client in _clients:
		client.poll()
		var status = client.get_status()

		if status == StreamPeerTCP.STATUS_CONNECTED:
			if _processing_clients.has(client):
				continue
			var available = client.get_available_bytes()
			if available > 0:
				var data = client.get_data(available)
				if data[0] == OK:
					var request_str = data[1].get_string_from_utf8()
					_pending_data[client] += request_str
					_log("Received %d bytes, total pending: %d" % [available, _pending_data[client].length()], "trace")
					_process_http_request(client)
				else:
					_log("Error receiving data: %s" % data[0], "warning")
		elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			clients_to_remove.append(client)
			_log("Client status changed: %s" % status, "debug")

	# Remove disconnected clients
	for client in clients_to_remove:
		_clients.erase(client)
		_pending_data.erase(client)
		_processing_clients.erase(client)
		_log("Client disconnected", "info")
		client_disconnected.emit()

	var loader = get_tool_loader()
	if loader != null and loader.has_method("tick"):
		loader.tick(_delta)


func initialize(port: int, host: String, debug: bool) -> void:
	_ensure_initialized()
	_port = port
	_host = host
	_debug_mode = debug


func reinitialize(port: int, host: String, debug: bool, disabled_tools: Array = [], reason: String = "manual") -> Dictionary:
	_ensure_initialized()
	if _running:
		stop()

	_port = port
	_host = host
	_debug_mode = debug
	set_disabled_tools(disabled_tools)
	_register_tools(reason, reason == "tool_soft_reload")

	_log("Reinitialized via %s on http://%s:%d/mcp" % [reason, _host, _port], "info")
	var loader = get_tool_loader()
	if loader != null and not loader.get_tool_load_errors().is_empty():
		_log("Tool load warnings after reinit: %d" % loader.get_tool_load_errors().size(), "warning")

	var loader_status = get_tool_loader_status()
	return {
		"tool_count": int(loader_status.get("tool_count", 0)),
		"tool_category_count": int(loader_status.get("category_count", 0)),
		"tool_load_error_count": int(loader_status.get("tool_load_error_count", 0)),
		"tool_loader_status": loader_status
	}


func start() -> bool:
	_ensure_initialized()
	if _running:
		return true

	var error = _tcp_server.listen(_port, _host)
	if error != OK:
		push_error("[MCP] Failed to start server on port %d: %s" % [_port, error_string(error)])
		PluginSelfDiagnosticStore.record_incident(
			"error",
			"server_error",
			"server_listen_failed",
			"Embedded MCP server failed to listen on the configured endpoint",
			"mcp_http_server",
			"start",
			"",
			"",
			"",
			true,
			"Check whether the configured host/port is already in use.",
			{
				"host": _host,
				"port": _port,
				"error_code": error,
				"error_text": error_string(error)
			}
		)
		return false

	_running = true
	_log("Server started on http://%s:%d/mcp" % [_host, _port], "info")
	server_started.emit()
	return true


func stop() -> void:
	if not _running:
		return

	# Disconnect all clients
	for client in _clients:
		client.disconnect_from_host()
	_clients.clear()
	_pending_data.clear()
	_processing_clients.clear()
	if _runtime_control_service != null and _runtime_control_service.has_method("reset"):
		_runtime_control_service.reset()

	_tcp_server.stop()
	_running = false
	_log("Server stopped", "info")
	server_stopped.emit()


func dispose() -> void:
	stop()
	if _runtime_control_service != null and _runtime_control_service.has_method("reset"):
		_runtime_control_service.reset()
	if _tool_loader_supervisor != null and _tool_loader_supervisor.has_method("dispose"):
		_tool_loader_supervisor.dispose()
	_dispose_helper(_tool_rpc_router)
	_dispose_helper(_editor_lifecycle_endpoint)
	_dispose_helper(_editor_lifecycle_action_service)
	_dispose_helper(_editor_lifecycle_state_builder)
	_dispose_helper(_http_request_router)
	_dispose_helper(_json_rpc_router)
	_dispose_helper(_tools_api_service)
	_dispose_helper(_http_response_service)
	_tool_loader_supervisor = null
	_tool_rpc_router = null
	_editor_lifecycle_endpoint = null
	_editor_lifecycle_action_service = null
	_editor_lifecycle_state_builder = null
	_http_request_router = null
	_json_rpc_router = null
	_tools_api_service = null
	_http_response_service = null
	_runtime_control_service = null
	_gdscript_lsp_diagnostics_service = null
	_default_permission_provider = null
	_tcp_server = null


func is_running() -> bool:
	return _running


func set_port(port: int) -> void:
	_port = port


func set_debug_mode(debug: bool) -> void:
	_debug_mode = debug


func get_connection_count() -> int:
	return _clients.size()


func get_connection_stats() -> Dictionary:
	return {
		"active_connections": _clients.size(),
		"total_connections": _total_connections,
		"total_requests": _total_requests,
		"last_request_method": _last_request_method,
		"last_request_at_unix": _last_request_at_unix
	}


func set_disabled_tools(disabled: Array) -> void:
	_ensure_tool_loader_supervisor()
	_tool_loader_supervisor.set_disabled_tools(disabled)


func get_disabled_tools() -> Array:
	_ensure_tool_loader_supervisor()
	return _tool_loader_supervisor.get_disabled_tools()


func is_tool_enabled(tool_name: String) -> bool:
	_ensure_tool_loader_supervisor()
	return _tool_loader_supervisor.is_tool_enabled(tool_name)


func is_tool_exposed(tool_name: String) -> bool:
	var loader = get_tool_loader()
	if loader == null:
		return false
	if not loader.has_method("is_tool_exposed"):
		return false
	return bool(loader.is_tool_exposed(tool_name))


func get_tools_by_category() -> Dictionary:
	"""Returns tools organized by category for UI display"""
	var loader = get_tool_loader()
	if loader == null:
		return {}
	return loader.get_tools_by_category()


func get_tool_loader() -> MCPToolLoader:
	_ensure_tool_loader_supervisor()
	return _tool_loader_supervisor.get_tool_loader()


func get_runtime_control_service():
	_ensure_runtime_control_service()
	return _runtime_control_service


func build_tools_api_snapshot() -> Dictionary:
	_ensure_tools_api_service()
	return _tools_api_service.build_tools_list_response()


func handle_editor_lifecycle_post(body: String) -> Dictionary:
	_ensure_editor_lifecycle_endpoint()
	return _editor_lifecycle_endpoint.handle_post_request(body)


func handle_editor_lifecycle_request(action: String, args: Dictionary) -> Dictionary:
	_ensure_editor_lifecycle_endpoint()
	return _editor_lifecycle_endpoint.handle_request(action, args)


func handle_jsonrpc_request_async(body: String) -> Dictionary:
	return await _handle_mcp_request_async(body)


func get_tool_loader_status() -> Dictionary:
	_ensure_tool_loader_supervisor()
	return _tool_loader_supervisor.get_status()


func get_all_tools_by_category() -> Dictionary:
	var loader = get_tool_loader()
	if loader == null:
		return {}
	return loader.get_all_tools_by_category()


func get_enabled_tools() -> Array[Dictionary]:
	"""Returns only enabled tool definitions"""
	var enabled: Array[Dictionary] = []
	var loader = get_tool_loader()
	if loader == null:
		return enabled

	for tool_def in loader.get_tool_definitions():
		if is_tool_enabled(tool_def["name"]):
			enabled.append(tool_def)

	return enabled


func get_tool_load_errors() -> Array[Dictionary]:
	var loader = get_tool_loader()
	if loader == null:
		return []
	return loader.get_tool_load_errors()


func get_gdscript_lsp_diagnostics_service():
	var loader = get_tool_loader()
	if loader != null and loader.has_method("get_gdscript_lsp_diagnostics_service"):
		return loader.get_gdscript_lsp_diagnostics_service()
	return GDScriptLspDiagnosticsService.get_singleton()


func get_domain_states() -> Array[Dictionary]:
	var loader = get_tool_loader()
	if loader == null:
		return []
	return loader.get_domain_states()


func get_all_domain_states() -> Array[Dictionary]:
	var loader = get_tool_loader()
	if loader == null:
		return []
	return loader.get_all_domain_states()


func get_reload_status() -> Dictionary:
	var loader = get_tool_loader()
	if loader == null:
		return {}
	return loader.get_reload_status()


func get_performance_summary() -> Dictionary:
	var loader = get_tool_loader()
	if loader == null:
		return {}
	return loader.get_performance_summary()


func reload_tool_domain(domain: String) -> Dictionary:
	var loader = get_tool_loader()
	if loader == null:
		return {}
	return loader.reload_domain(domain)


func reload_all_tool_domains() -> Dictionary:
	var loader = get_tool_loader()
	if loader == null:
		return {}
	return loader.reload_all_domains()


func _ensure_initialized() -> void:
	if _tcp_server == null:
		_tcp_server = TCPServer.new()
	_ensure_tool_loader_supervisor()
	_ensure_http_response_service()
	_ensure_http_request_router()
	_ensure_tools_api_service()
	_ensure_editor_lifecycle_endpoint()
	_ensure_runtime_control_service()
	if not bool(get_tool_loader_status().get("initialized", false)):
		_register_tools()


func _register_tools(reason: String = "initialize", force_reload_scripts: bool = false) -> void:
	_ensure_tool_loader_supervisor()
	_tool_loader_supervisor.register_tools(reason, force_reload_scripts)


func _ensure_tool_loader_supervisor() -> void:
	if _tool_loader_supervisor == null:
		_tool_loader_supervisor = MCPToolLoaderSupervisorScript.new()
	_tool_loader_supervisor.configure(self, {
		"log": Callable(self, "_log"),
		"record_registration_issue": Callable(self, "_record_tool_loader_registration_issue")
	})
	_ensure_tool_rpc_router()


func _ensure_runtime_control_service() -> void:
	if _runtime_control_service == null:
		_runtime_control_service = MCPRuntimeControlServiceScript.new()
	var plugin = get_parent()
	var debugger_bridge = null
	if plugin != null and plugin.has_method("get_editor_debugger_bridge"):
		debugger_bridge = plugin.get_editor_debugger_bridge()
	_runtime_control_service.configure(plugin, debugger_bridge, {
		"log": Callable(self, "_log")
	})


func _ensure_tool_rpc_router() -> void:
	if _tool_rpc_router == null:
		_tool_rpc_router = MCPToolRpcRouterScript.new()
	_ensure_http_response_service()
	_tool_rpc_router.configure({
		"get_tool_loader": Callable(self, "get_tool_loader"),
		"is_tool_enabled": Callable(self, "is_tool_enabled"),
		"is_tool_exposed": Callable(self, "is_tool_exposed"),
		"log": Callable(self, "_log"),
		"sanitize_for_json": Callable(_http_response_service, "sanitize_for_json")
	})


func _ensure_http_request_router() -> void:
	if _http_request_router == null:
		_http_request_router = MCPHttpRequestRouterScript.new()
	_http_request_router.configure({
		"handle_mcp_request_async": Callable(self, "_handle_mcp_request_async"),
		"build_health_response": Callable(self, "_build_health_response"),
		"build_tools_list_response": Callable(self, "_create_tools_list_response"),
		"handle_editor_lifecycle_request": Callable(self, "_handle_editor_lifecycle_request"),
		"handle_editor_lifecycle_post_request": Callable(self, "_handle_editor_lifecycle_post_request"),
		"build_cors_response": Callable(self, "_build_cors_response")
	})


func _ensure_json_rpc_router() -> void:
	if _json_rpc_router == null:
		_json_rpc_router = MCPJsonRpcRouterScript.new()
	_json_rpc_router.configure({
		"handle_initialize": Callable(self, "_handle_initialize"),
		"handle_tools_list": Callable(self, "_handle_tools_list"),
		"handle_tools_call_async": Callable(self, "_handle_tools_call_async"),
		"handle_notification": Callable(self, "_handle_notification"),
		"build_json_rpc_response": Callable(self, "_build_json_rpc_response"),
		"build_json_rpc_error": Callable(self, "_build_json_rpc_error"),
		"log": Callable(self, "_log")
	})


func _ensure_editor_lifecycle_endpoint() -> void:
	if _editor_lifecycle_endpoint == null:
		_editor_lifecycle_endpoint = MCPEditorLifecycleEndpointScript.new()
	_ensure_editor_lifecycle_action_service()
	_ensure_editor_lifecycle_state_builder()
	_editor_lifecycle_endpoint.configure({
		"build_state": Callable(_editor_lifecycle_state_builder, "build_state"),
		"execute_close": Callable(_editor_lifecycle_action_service, "execute_close"),
		"execute_restart": Callable(_editor_lifecycle_action_service, "execute_restart"),
		"success": Callable(self, "_editor_lifecycle_success"),
		"error": Callable(self, "_editor_lifecycle_error")
	})


func _ensure_tools_api_service() -> void:
	if _tools_api_service == null:
		_tools_api_service = MCPToolsApiServiceScript.new()
	_tools_api_service.configure({
		"get_tool_loader": Callable(self, "get_tool_loader"),
		"get_tool_loader_status": Callable(self, "get_tool_loader_status")
	})


func _ensure_editor_lifecycle_state_builder() -> void:
	if _editor_lifecycle_state_builder == null:
		_editor_lifecycle_state_builder = MCPEditorLifecycleStateBuilderScript.new()
	_editor_lifecycle_state_builder.configure({
		"get_plugin_host": Callable(self, "_get_editor_plugin_host")
	})


func _ensure_editor_lifecycle_action_service() -> void:
	if _editor_lifecycle_action_service == null:
		_editor_lifecycle_action_service = MCPEditorLifecycleActionServiceScript.new()
	_ensure_editor_lifecycle_state_builder()
	_editor_lifecycle_action_service.configure({
		"build_state": Callable(_editor_lifecycle_state_builder, "build_state"),
		"build_state_with_hint": Callable(_editor_lifecycle_state_builder, "build_state_with_hint"),
		"success": Callable(self, "_editor_lifecycle_success"),
		"error": Callable(self, "_editor_lifecycle_error"),
		"schedule_action": Callable(self, "_schedule_editor_lifecycle_action"),
		"get_plugin_host": Callable(self, "_get_editor_plugin_host"),
		"log": Callable(self, "_log")
	})


func _ensure_http_response_service() -> void:
	if _http_response_service == null:
		_http_response_service = MCPHttpResponseServiceScript.new()
	_http_response_service.configure({
		"get_tool_loader": Callable(self, "get_tool_loader"),
		"get_tool_loader_status": Callable(self, "get_tool_loader_status"),
		"get_server_stats": Callable(self, "_build_server_stats"),
		"log": Callable(self, "_log")
	}, {
		"server_name": SERVER_NAME,
		"server_version": SERVER_VERSION
	})


func _build_server_stats() -> Dictionary:
	return {
		"running": _running,
		"connections": _clients.size(),
		"total_connections": _total_connections,
		"total_requests": _total_requests,
		"last_request_method": _last_request_method,
		"last_request_at_unix": _last_request_at_unix
	}


func _record_tool_loader_registration_issue(level: String, reason: String, status: Dictionary, summary: Dictionary) -> void:
	if level == "error":
		PluginSelfDiagnosticStore.record_incident(
			"error",
			"tool_load_error",
			"tool_registry_empty_after_register",
			"Tool registration completed with no exposed tools",
			"mcp_http_server",
			"register_tools",
			"",
			"",
			"",
			true,
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
		_log("Skipped %d tool categories due to load errors" % int(summary.get("tool_load_error_count", 0)), "warning")
		PluginSelfDiagnosticStore.record_incident(
			"warning",
			"tool_load_error",
			"tool_domain_load_failed",
			"One or more tool domains were skipped during server registration",
			"mcp_http_server",
			"register_tools",
			"",
			"",
			"",
			true,
			"Inspect the tool loader load-error list and editor output for the failing categories.",
			{"tool_load_error_count": int(summary.get("tool_load_error_count", 0))}
		)


func _process_http_request(client: StreamPeerTCP) -> void:
	var data = _pending_data.get(client, "")
	if data.is_empty():
		return
	if _processing_clients.has(client):
		return

	# Check for complete HTTP request (headers end with \r\n\r\n)
	var header_end = data.find("\r\n\r\n")
	if header_end == -1:
		if data.length() > 0:
			_log("Waiting for headers... current data length: %d" % data.length(), "trace")
		return

	# Parse HTTP headers
	var header_section = data.substr(0, header_end)
	var headers = _parse_http_headers(header_section)

	if headers.is_empty():
		_pending_data[client] = ""
		return

	# Get content length - support chunked encoding
	var content_length = 0
	var is_chunked = false

	if headers.has("content-length"):
		content_length = int(headers["content-length"])
	elif headers.has("transfer-encoding") and headers["transfer-encoding"].to_lower().contains("chunked"):
		is_chunked = true

	# Check if we have complete body
	var body_start = header_end + 4
	var body = data.substr(body_start)

	# IMPORTANT: Content-Length is in bytes, not characters!
	# For UTF-8 strings with multi-byte chars (emojis, Chinese, etc.), we must compare byte sizes
	var body_bytes = body.to_utf8_buffer()
	var body_byte_size = body_bytes.size()
	var request_body := ""

	_log("Request headers: method=%s, content_length=%d, body_bytes=%d, chunked=%s" % [headers.get("method", "?"), content_length, body_byte_size, is_chunked], "trace")

	# Handle chunked encoding
	if is_chunked:
		var decoded_chunked = _decode_chunked_body_bytes(body_bytes)
		if not bool(decoded_chunked.get("complete", false)):
			_log("Waiting for chunked body...", "trace")
			return  # Wait for more data
		var request_bytes: PackedByteArray = decoded_chunked.get("body", PackedByteArray())
		request_body = request_bytes.get_string_from_utf8()
		var remaining_bytes: PackedByteArray = decoded_chunked.get("remaining", PackedByteArray())
		_pending_data[client] = remaining_bytes.get_string_from_utf8()
	elif body_byte_size < content_length:
		_log("Waiting for body... need %d bytes, have %d bytes" % [content_length, body_byte_size], "trace")
		return  # Wait for more data

	# Extract the complete request body (by bytes, then convert back to string)
	if not is_chunked:
		# Extract exactly content_length bytes and convert to string
		var request_bytes = body_bytes.slice(0, content_length)
		request_body = request_bytes.get_string_from_utf8()
		# Remove processed data (also by bytes)
		if body_byte_size > content_length:
			var remaining_bytes = body_bytes.slice(content_length)
			_pending_data[client] = remaining_bytes.get_string_from_utf8()
		else:
			_pending_data[client] = ""

	_processing_clients[client] = true

	# Route request
	var method = headers.get("method", "GET")
	var path = headers.get("path", "/")

	_log("Processing: %s %s (body: %d bytes)" % [method, path, request_body.length()], "debug")
	_total_requests += 1
	_last_request_method = method
	_last_request_at_unix = int(Time.get_unix_time_from_system())

	_ensure_http_request_router()
	var response: Dictionary = await _http_request_router.route_request_async(method, path, request_body)
	var no_body := bool(response.get("_no_body", false))
	if response.has("_no_body"):
		response.erase("_no_body")

	if client in _clients and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_write_http_response(client, response, no_body)
	_processing_clients.erase(client)


func _decode_chunked_body_bytes(data: PackedByteArray) -> Dictionary:
	# Decode chunked transfer encoding with byte offsets.
	# Returns completion state, decoded body, and any remaining bytes.
	var result := PackedByteArray()
	var pos = 0

	while pos < data.size():
		# Find chunk size line end
		var line_end = _find_crlf_bytes(data, pos)
		if line_end == -1:
			return {"complete": false}  # Need more data

		# Parse chunk size (hex)
		var size_str = data.slice(pos, line_end).get_string_from_utf8().strip_edges()
		# Remove any chunk extensions
		var semicolon = size_str.find(";")
		if semicolon != -1:
			size_str = size_str.substr(0, semicolon)

		var chunk_size = size_str.hex_to_int()
		var chunk_start = line_end + 2

		if chunk_size == 0:
			if chunk_start + 1 < data.size() and data[chunk_start] == 13 and data[chunk_start + 1] == 10:
				return {
					"complete": true,
					"body": result,
					"remaining": data.slice(chunk_start + 2, data.size())
				}
			var trailer_end = _find_double_crlf_bytes(data, chunk_start)
			if trailer_end == -1:
				return {"complete": false}  # Need more data
			return {
				"complete": true,
				"body": result,
				"remaining": data.slice(trailer_end, data.size())
			}

		# Check if we have the full chunk
		var chunk_end = chunk_start + chunk_size

		if chunk_end + 2 > data.size():
			return {"complete": false}  # Need more data
		if data[chunk_end] != 13 or data[chunk_end + 1] != 10:
			return {"complete": false}

		# Extract chunk data
		result.append_array(data.slice(chunk_start, chunk_end))
		pos = chunk_end + 2  # Skip chunk data and trailing CRLF

	return {"complete": false}  # Need more data


func _find_crlf_bytes(data: PackedByteArray, start: int) -> int:
	for index in range(start, data.size() - 1):
		if data[index] == 13 and data[index + 1] == 10:
			return index
	return -1


func _find_double_crlf_bytes(data: PackedByteArray, start: int) -> int:
	for index in range(start, data.size() - 3):
		if data[index] == 13 and data[index + 1] == 10 and data[index + 2] == 13 and data[index + 3] == 10:
			return index + 4
	return -1


func _close_client(client: StreamPeerTCP) -> void:
	if client in _clients:
		client.disconnect_from_host()
		_clients.erase(client)
		_pending_data.erase(client)
		_processing_clients.erase(client)
		_log("Client connection closed", "debug")


func _parse_http_headers(header_section: String) -> Dictionary:
	var result: Dictionary = {}
	var lines = header_section.split("\r\n")

	if lines.size() == 0:
		return result

	# Parse request line
	var request_line = lines[0].split(" ")
	if request_line.size() >= 2:
		result["method"] = request_line[0]
		result["path"] = request_line[1]

	# Parse headers
	for i in range(1, lines.size()):
		var line = lines[i]
		var colon_pos = line.find(":")
		if colon_pos > 0:
			var key = line.substr(0, colon_pos).strip_edges().to_lower()
			var value = line.substr(colon_pos + 1).strip_edges()
			result[key] = value

	return result


func _handle_mcp_request_async(body: String) -> Dictionary:
	_log("Parsing request body (%d bytes)" % body.length(), "trace")
	var json = JSON.new()
	var error = json.parse(body)

	if error != OK:
		push_error("[MCP] JSON parse error: %s" % json.get_error_message())
		PluginSelfDiagnosticStore.record_incident(
			"warning",
			"server_error",
			"json_parse_error",
			"MCP request JSON parsing failed",
			"mcp_http_server",
			"handle_mcp_request",
			"",
			"",
			"",
			true,
			"Inspect the malformed request body sent to /mcp.",
			{
				"error_message": json.get_error_message(),
				"body_length": body.length()
			}
		)
		return _build_json_rpc_error(-32700, "Parse error: %s" % json.get_error_message(), null)

	var request = json.get_data()
	if not request is Dictionary:
		return _build_json_rpc_error(-32600, "Invalid Request", null)

	var method = request.get("method", "")
	var params = request.get("params", {})
	var has_id = request.has("id")
	var id = request.get("id")

	_log("Method: %s, ID: %s" % [method, id], "debug")

	request_received.emit(method, params)
	_ensure_json_rpc_router()
	return await _json_rpc_router.route_request_async(method, params, id, has_id)


func _dispose_helper(service) -> void:
	if service == null:
		return
	if service.has_method("dispose"):
		service.dispose()


func _handle_notification(method: String, _params: Dictionary) -> void:
	match method:
		"initialized", "notifications/initialized":
			_log("Client initialized", "info")
		"notifications/cancelled":
			_log("Request cancelled by client", "debug")
		_:
			_log("Notification received: %s" % method, "debug")


func _handle_initialize(params: Dictionary, id) -> Dictionary:
	var result = {
		"protocolVersion": MCP_VERSION,
		"capabilities": {
			"tools": {
				"listChanged": false
			}
		},
		"serverInfo": {
			"name": SERVER_NAME,
			"version": SERVER_VERSION
		}
	}
	return _build_json_rpc_response(result, id)


func get_plugin_permission_provider():
	var plugin = get_parent()
	if plugin != null and plugin.has_method("get_tool_access_provider"):
		var provider = plugin.get_tool_access_provider()
		if provider != null:
			return provider
	if plugin != null and plugin.has_method("is_tool_category_visible_for_permission"):
		return plugin
	if _default_permission_provider != null and _default_permission_provider.has_method("configure"):
		_default_permission_provider.configure({
			"permission_level": "evolution",
			"show_user_tools": true
		})
	return _default_permission_provider


func _handle_tools_list(_params: Dictionary, id) -> Dictionary:
	_ensure_tool_rpc_router()
	return _build_json_rpc_response(_tool_rpc_router.build_tools_list_result(), id)


func _handle_tools_call_async(params: Dictionary, id) -> Dictionary:
	_ensure_tool_rpc_router()
	return _build_json_rpc_response(await _tool_rpc_router.build_tool_call_result_async(params), id)


func _build_json_rpc_response(result, id) -> Dictionary:
	_ensure_http_response_service()
	return _http_response_service.build_json_rpc_response(result, id)


func _create_tools_list_response() -> Dictionary:
	return build_tools_api_snapshot()


func _build_json_rpc_error(code: int, message: String, id) -> Dictionary:
	_ensure_http_response_service()
	return _http_response_service.build_json_rpc_error(code, message, id)


func _build_health_response() -> Dictionary:
	_ensure_http_response_service()
	return _http_response_service.build_health_response()


func _build_cors_response() -> Dictionary:
	_ensure_http_response_service()
	return _http_response_service.build_cors_response()


func _handle_editor_lifecycle_post_request(body: String) -> Dictionary:
	return handle_editor_lifecycle_post(body)


func _handle_editor_lifecycle_request(action: String, args: Dictionary) -> Dictionary:
	return handle_editor_lifecycle_request(action, args)


func _schedule_editor_lifecycle_action(action: String) -> void:
	call_deferred("_run_deferred_editor_lifecycle_action", action)


func _run_deferred_editor_lifecycle_action(action: String) -> void:
	_ensure_editor_lifecycle_action_service()
	_editor_lifecycle_action_service.run_deferred_action(action)


func _get_editor_plugin_host():
	var plugin = get_parent()
	if plugin == null or not is_instance_valid(plugin):
		return null
	return plugin


func _editor_lifecycle_success(data, message: String) -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _editor_lifecycle_error(error: String, message: String, data: Dictionary = {}) -> Dictionary:
	var result := {
		"success": false,
		"error": error,
		"message": message,
		"status": 400
	}
	if not data.is_empty():
		result["data"] = data
	return result


func _write_http_response(client: StreamPeerTCP, data: Dictionary, no_body: bool = false) -> void:
	_ensure_http_response_service()
	_http_response_service.send_http_response(client, data, no_body)
