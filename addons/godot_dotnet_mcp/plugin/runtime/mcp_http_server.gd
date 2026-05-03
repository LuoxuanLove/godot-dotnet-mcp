@tool
extends Node
class_name MCPHttpServer

const MCPToolLoader = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
const MCPHttpConnectionStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_connection_state.gd")
const MCPHttpServiceBundleScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_service_bundle.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPDefaultToolAccessProviderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/default_tool_access_provider.gd")
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
var _connection_state = MCPHttpConnectionStateScript.new()
var _service_bundle = MCPHttpServiceBundleScript.new()
var _default_tool_access_provider = MCPDefaultToolAccessProviderScript.new()

func _ready() -> void:
	set_process(true)
	_ensure_initialized()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		dispose()

func _process(delta: float) -> void:
	if not _running:
		return
	_ensure_service_bundle()
	_service_bundle.get_http_transport_service().process_frame(_tcp_server, _running, delta)

func initialize(port: int, host: String, debug: bool) -> void:
	_port = port
	_host = host
	_debug_mode = debug
	_ensure_initialized()

func reinitialize(port: int, host: String, debug: bool, disabled_tools: Array = [], reason: String = "manual") -> Dictionary:
	_ensure_initialized()
	if _running:
		stop()
	_port = port
	_host = host
	_debug_mode = debug
	set_disabled_tools(disabled_tools)
	_ensure_service_bundle()
	var force_reload_tools = reason == "tool_soft_reload" or reason == "tool_full_reload" or reason == "plugin_lifecycle_reload" or reason == "auto_start"
	_service_bundle.get_tool_loader_supervisor().register_tools(reason, force_reload_tools)
	MCPDebugBuffer.record("info", "server", "Reinitialized via %s on http://%s:%d/mcp" % [reason, _host, _port])
	if _debug_mode:
		print("[MCP] Reinitialized via %s on http://%s:%d/mcp" % [reason, _host, _port])
	var loader = get_tool_loader()
	if loader != null and not loader.get_tool_load_errors().is_empty():
		MCPDebugBuffer.record("warning", "server", "Tool load warnings after reinit: %d" % loader.get_tool_load_errors().size())
		if _debug_mode:
			print("[MCP] Tool load warnings after reinit: %d" % loader.get_tool_load_errors().size())
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
			"error", "server_error", "server_listen_failed",
			"Embedded MCP server failed to listen on the configured endpoint",
			"mcp_http_server", "start", "", "", "", true,
			"Check whether the configured host/port is already in use.",
			{"host": _host, "port": _port, "error_code": error, "error_text": error_string(error)}
		)
		return false
	_running = true
	MCPDebugBuffer.record("info", "server", "Server started on http://%s:%d/mcp" % [_host, _port])
	if _debug_mode:
		print("[MCP] Server started on http://%s:%d/mcp" % [_host, _port])
	server_started.emit()
	return true

func stop() -> void:
	if not _running:
		return
	if _connection_state != null:
		_connection_state.disconnect_all_clients()
	var runtime_control = _get_runtime_control_service(false)
	if runtime_control != null and runtime_control.has_method("reset"):
		runtime_control.reset()
	_tcp_server.stop()
	_tcp_server = TCPServer.new()
	_running = false
	MCPDebugBuffer.record("info", "server", "Server stopped")
	if _debug_mode:
		print("[MCP] Server stopped")
	server_stopped.emit()

func dispose() -> void:
	stop()
	if _service_bundle != null and _service_bundle.has_method("dispose"):
		_service_bundle.dispose()
	_service_bundle = null
	_default_tool_access_provider = null
	_connection_state = null
	_tcp_server = null

func is_running() -> bool: return _running
func set_port(port: int) -> void: _port = port
func set_debug_mode(debug: bool) -> void: _debug_mode = debug
func get_connection_count() -> int: return _connection_state.get_connection_count() if _connection_state != null else 0

func get_connection_stats() -> Dictionary:
	if _connection_state == null:
		return {
			"active_connections": 0, "connections": 0, "total_connections": 0,
			"total_requests": 0, "last_request_method": "", "last_request_at_unix": 0
		}
	var stats = _connection_state.get_connection_stats()
	if not stats.has("active_connections"):
		stats["active_connections"] = int(stats.get("connections", 0))
	return stats

func set_disabled_tools(disabled: Array) -> void: _ensure_service_bundle(); _service_bundle.get_tool_loader_supervisor().set_disabled_tools(disabled)
func get_disabled_tools() -> Array: _ensure_service_bundle(); return _service_bundle.get_tool_loader_supervisor().get_disabled_tools()
func is_tool_enabled(tool_name: String) -> bool: _ensure_service_bundle(); return _service_bundle.get_tool_loader_supervisor().is_tool_enabled(tool_name)
func is_tool_exposed(tool_name: String) -> bool: _ensure_service_bundle(); return _service_bundle.get_tool_loader_supervisor().is_tool_exposed(tool_name)
func get_tools_by_category() -> Dictionary: _ensure_service_bundle(); var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader(); return {} if loader == null else loader.get_tools_by_category()
func get_tool_loader() -> MCPToolLoader: _ensure_service_bundle(); return _service_bundle.get_tool_loader_supervisor().get_tool_loader()

func get_runtime_control_service(): return _get_runtime_control_service(true)

func build_tools_api_snapshot() -> Dictionary: _ensure_service_bundle(); return _service_bundle.get_tools_api_service().build_tools_list_response()
func handle_editor_lifecycle_post(body: String) -> Dictionary: _ensure_service_bundle(); return _service_bundle.get_editor_lifecycle_endpoint().handle_post_request(body)
func handle_editor_lifecycle_request(action: String, args: Dictionary) -> Dictionary: _ensure_service_bundle(); return _service_bundle.get_editor_lifecycle_endpoint().handle_request(action, args)
func handle_jsonrpc_request_async(body: String) -> Dictionary: _ensure_service_bundle(); return await _service_bundle.get_json_rpc_request_service().handle_request_async(body)
func get_tool_loader_status() -> Dictionary: _ensure_service_bundle(); return _service_bundle.get_tool_loader_supervisor().get_status()
func get_all_tools_by_category() -> Dictionary: _ensure_service_bundle(); var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader(); return {} if loader == null else loader.get_all_tools_by_category()

func get_enabled_tools() -> Array[Dictionary]:
	_ensure_service_bundle()
	var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader()
	if loader == null:
		return []
	var enabled: Array[Dictionary] = []
	for tool_def in loader.get_tool_definitions():
		if _service_bundle.get_tool_loader_supervisor().is_tool_enabled(tool_def["name"]):
			enabled.append(tool_def)
	return enabled

func get_tool_load_errors() -> Array[Dictionary]: _ensure_service_bundle(); var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader(); return [] if loader == null else loader.get_tool_load_errors()

func get_gdscript_lsp_diagnostics_service():
	_ensure_service_bundle()
	var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader()
	if loader != null and loader.has_method("get_gdscript_lsp_diagnostics_service"):
		var service = loader.get_gdscript_lsp_diagnostics_service()
		if service != null:
			return service
	return null

func get_domain_states() -> Array[Dictionary]: _ensure_service_bundle(); var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader(); return [] if loader == null else loader.get_domain_states()
func get_all_domain_states() -> Array[Dictionary]: _ensure_service_bundle(); var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader(); return [] if loader == null else loader.get_all_domain_states()
func get_reload_status() -> Dictionary: _ensure_service_bundle(); var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader(); return {} if loader == null else loader.get_reload_status()
func get_performance_summary() -> Dictionary: _ensure_service_bundle(); var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader(); return {} if loader == null else loader.get_performance_summary()
func reload_tool_domain(domain: String) -> Dictionary: _ensure_service_bundle(); var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader(); return {} if loader == null else loader.reload_domain(domain)
func reload_all_tool_domains() -> Dictionary: _ensure_service_bundle(); var loader = _service_bundle.get_tool_loader_supervisor().get_tool_loader(); return {} if loader == null else loader.reload_all_domains()

func get_tool_access_provider():
	var plugin = get_parent()
	if plugin != null and plugin.has_method("get_tool_access_provider"):
		var provider = plugin.get_tool_access_provider()
		if provider != null:
			return provider
	if plugin != null and plugin.has_method("is_tool_category_visible"):
		return plugin
	if _default_tool_access_provider != null and _default_tool_access_provider.has_method("configure"):
		_default_tool_access_provider.configure({"show_user_tools": true})
	return _default_tool_access_provider

func _ensure_initialized() -> void:
	if _tcp_server == null:
		_tcp_server = TCPServer.new()
	_ensure_service_bundle()
	var supervisor = _service_bundle.get_tool_loader_supervisor()
	if not bool(supervisor.get_status().get("initialized", false)):
		supervisor.register_tools()

func _ensure_service_bundle() -> void:
	if _service_bundle == null:
		_service_bundle = MCPHttpServiceBundleScript.new()
	_service_bundle.configure(self, _connection_state)
	_service_bundle.ensure_initialized()

func _get_runtime_control_service(ensure_initialized: bool = true):
	if ensure_initialized:
		_ensure_service_bundle()
		return _service_bundle.get_runtime_control_service()
	if _service_bundle == null:
		return null
	return _service_bundle.get_runtime_control_service()
