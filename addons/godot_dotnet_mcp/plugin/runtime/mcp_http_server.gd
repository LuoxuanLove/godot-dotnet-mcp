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

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		dispose()

func _process(delta: float) -> void:
	if not _running:
		return
	_ensure_service_bundle()
	_service_bundle.get_http_transport_service().process_frame(_tcp_server, _running, delta)

func initialize(port: int, host: String, debug: bool, diagnostic_operation_id: String = "") -> void:
	_port = port
	_host = host
	_debug_mode = debug
	_ensure_initialized(diagnostic_operation_id)

func reinitialize(port: int, host: String, debug: bool, disabled_tools: Array = [], reason: String = "manual", diagnostic_operation_id: String = "") -> Dictionary:
	var phase_started = PluginSelfDiagnosticStore.begin_phase()
	_ensure_initialized(diagnostic_operation_id)
	PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "http_server.ensure_initialized", phase_started)
	if _running:
		phase_started = PluginSelfDiagnosticStore.begin_phase()
		stop()
		PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "http_server.stop_running", phase_started)
	_port = port
	_host = host
	_debug_mode = debug
	phase_started = PluginSelfDiagnosticStore.begin_phase()
	set_disabled_tools(disabled_tools)
	PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "tool_loader.set_disabled_tools", phase_started, {"disabled_tool_count": disabled_tools.size()})
	phase_started = PluginSelfDiagnosticStore.begin_phase()
	_ensure_service_bundle(diagnostic_operation_id)
	PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "service_bundle.ensure", phase_started)
	var force_reload_tools = reason == "tool_soft_reload" or reason == "tool_full_reload" or reason == "plugin_lifecycle_reload" or reason == "auto_start"
	phase_started = PluginSelfDiagnosticStore.begin_phase()
	var registration_summary = _service_bundle.get_tool_loader_supervisor().register_tools(reason, force_reload_tools)
	PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "tool_loader.register_tools", phase_started, registration_summary)
	_record_tool_loader_performance_phases(diagnostic_operation_id, registration_summary)
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

func start(diagnostic_operation_id: String = "") -> bool:
	var phase_started = PluginSelfDiagnosticStore.begin_phase()
	_ensure_initialized(diagnostic_operation_id)
	PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "http_server.ensure_initialized", phase_started)
	if _running:
		return true
	phase_started = PluginSelfDiagnosticStore.begin_phase()
	var error = _tcp_server.listen(_port, _host)
	PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "http_server.tcp_listen", phase_started, {"host": _host, "port": _port, "error": error})
	if error != OK:
		var failure_context := _build_listen_failure_context(error)
		push_error("[MCP] Failed to start server on port %d: %s" % [_port, error_string(error)])
		PluginSelfDiagnosticStore.record_incident(
			"error", "server_error", "server_listen_failed",
			"Embedded MCP server failed to listen on the configured endpoint (%s)" % str(failure_context.get("failure_reason", "unknown")),
			"mcp_http_server", "start", "", "", "", true,
			_build_listen_failure_suggested_action(failure_context),
			failure_context
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

func get_listen_endpoint() -> Dictionary:
	return {
		"host": _host,
		"port": _port,
		"url": "http://%s:%d/mcp" % [_host, _port],
		"running": _running
	}

func get_connection_stats() -> Dictionary:
	if _connection_state == null:
		return {
			"active_connections": 0, "connections": 0, "total_connections": 0,
			"total_requests": 0, "last_request_method": "", "last_request_at_unix": 0
		}
	var stats = _connection_state.get_connection_stats()
	if not stats.has("active_connections"):
		stats["active_connections"] = int(stats.get("connections", 0))
	stats["listen_host"] = _host
	stats["listen_port"] = _port
	stats["listen_url"] = "http://%s:%d/mcp" % [_host, _port]
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

func _ensure_initialized(diagnostic_operation_id: String = "") -> void:
	if _tcp_server == null:
		var tcp_server_started = PluginSelfDiagnosticStore.begin_phase()
		_tcp_server = TCPServer.new()
		PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "http_server.create_tcp_server", tcp_server_started)
	_ensure_service_bundle(diagnostic_operation_id)
	var supervisor = _service_bundle.get_tool_loader_supervisor()
	if not bool(supervisor.get_status().get("initialized", false)):
		var register_started = PluginSelfDiagnosticStore.begin_phase()
		var registration_summary = supervisor.register_tools()
		PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "tool_loader.register_tools", register_started, registration_summary)
		_record_tool_loader_performance_phases(diagnostic_operation_id, registration_summary)

func _ensure_service_bundle(diagnostic_operation_id: String = "") -> void:
	if _service_bundle == null:
		var create_started = PluginSelfDiagnosticStore.begin_phase()
		_service_bundle = MCPHttpServiceBundleScript.new()
		PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "service_bundle.create", create_started)
	var configure_started = PluginSelfDiagnosticStore.begin_phase()
	_service_bundle.configure(self, _connection_state)
	PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "service_bundle.configure", configure_started)
	var ensure_started = PluginSelfDiagnosticStore.begin_phase()
	_service_bundle.ensure_initialized()
	PluginSelfDiagnosticStore.record_operation_phase(diagnostic_operation_id, "service_bundle.initialize", ensure_started)

func _record_tool_loader_performance_phases(diagnostic_operation_id: String, summary: Dictionary) -> void:
	var performance = summary.get("performance", {})
	if not (performance is Dictionary):
		return
	var performance_dict := performance as Dictionary
	for metric_name in ["definition_scan_ms", "preload_ms", "startup_ms"]:
		var duration_ms = float(performance_dict.get(metric_name, 0.0))
		if duration_ms > 0.0:
			PluginSelfDiagnosticStore.record_operation_phase_duration(
				diagnostic_operation_id,
				"tool_loader.%s" % metric_name.replace("_ms", ""),
				duration_ms
			)


func _get_runtime_control_service(ensure_initialized: bool = true):
	if ensure_initialized:
		_ensure_service_bundle()
		return _service_bundle.get_runtime_control_service()
	if _service_bundle == null:
		return null
	return _service_bundle.get_runtime_control_service()


func _build_listen_failure_context(error_code: int, error_text_override: String = "") -> Dictionary:
	var has_error_text_override := not error_text_override.is_empty()
	var error_text := error_text_override if has_error_text_override else error_string(error_code)
	var failure_reason := _classify_listen_failure(error_code, error_text)
	if not has_error_text_override and failure_reason == "address_in_use" and _is_configured_port_in_windows_excluded_range():
		failure_reason = "port_excluded_or_reserved"
	var context := {
		"host": _host,
		"port": _port,
		"endpoint": "http://%s:%d/mcp" % [_host, _port],
		"error_code": error_code,
		"error_text": error_text,
		"failure_reason": failure_reason,
		"platform": OS.get_name(),
		"diagnostic_commands": []
	}
	if failure_reason == "port_excluded_or_reserved":
		context["diagnostic_commands"] = _build_windows_excluded_port_diagnostic_commands()
		context["requires_client_config_update"] = true
	elif failure_reason == "access_denied":
		if _is_windows():
			context["diagnostic_commands"] = _build_windows_excluded_port_diagnostic_commands()
		context["requires_client_config_update"] = false
	elif failure_reason == "address_in_use":
		if _is_windows():
			context["diagnostic_commands"] = _build_windows_excluded_port_diagnostic_commands()
		context["requires_client_config_update"] = false
	else:
		context["requires_client_config_update"] = false
	return context


func _classify_listen_failure(_error_code: int, error_text: String) -> String:
	var normalized := error_text.to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized.find("alreadyinuse") != -1 or normalized.find("addressinuse") != -1 or normalized.find("eaddrinuse") != -1:
		return "address_in_use"
	if _is_windows() and normalized.find("port") != -1 and (normalized.find("excluded") != -1 or normalized.find("reserved") != -1):
		return "port_excluded_or_reserved"
	if normalized.find("accessdenied") != -1 or normalized.find("permissiondenied") != -1 or normalized.find("forbidden") != -1 or normalized.find("10013") != -1:
		return "access_denied"
	return "listen_failed"


func _build_listen_failure_suggested_action(context: Dictionary) -> String:
	match str(context.get("failure_reason", "")):
		"address_in_use":
			if str(context.get("platform", "")).to_lower().find("windows") != -1:
				return "Check whether another process or stale plugin instance is already listening on this host/port. If no listener is present, inspect Windows excluded TCP port ranges with netsh."
			return "Check whether another process or stale plugin instance is already listening on this host/port."
		"port_excluded_or_reserved":
			return "On Windows, check excluded TCP port ranges with netsh and choose a bindable port, then update client MCP configuration."
		"access_denied":
			if str(context.get("platform", "")).to_lower().find("windows") != -1:
				return "Check OS permissions or security policy for binding this host/port. On Windows, netsh excluded port ranges can help rule out reserved ports."
			return "Check OS permissions or security policy for binding the configured host/port."
		_:
			return "Check whether the configured host/port is bindable and update the MCP server/client configuration if needed."


func _is_windows() -> bool:
	return OS.get_name().to_lower().find("windows") != -1


func _build_windows_excluded_port_diagnostic_commands() -> Array[String]:
	return [
		"netsh interface ipv4 show excludedportrange protocol=tcp",
		"netsh interface ipv6 show excludedportrange protocol=tcp"
	]


func _is_configured_port_in_windows_excluded_range() -> bool:
	if not _is_windows():
		return false
	for family in ["ipv4", "ipv6"]:
		var output: Array = []
		var exit_code := OS.execute(
			"netsh.exe",
			PackedStringArray(["interface", str(family), "show", "excludedportrange", "protocol=tcp"]),
			output,
			true,
			false
		)
		if exit_code == 0 and _netsh_excluded_ranges_include_port(output, _port):
			return true
	return false


func _netsh_excluded_ranges_include_port(output: Array, port: int) -> bool:
	for chunk in output:
		var text := str(chunk).replace("\r", "\n")
		for raw_line in text.split("\n", false):
			var parts := raw_line.strip_edges().split(" ", false)
			if parts.size() < 2:
				continue
			var start_text := str(parts[0])
			var end_text := str(parts[1])
			if not start_text.is_valid_int() or not end_text.is_valid_int():
				continue
			var start_port := int(start_text)
			var end_port := int(end_text)
			if start_port <= port and port <= end_port:
				return true
	return false
