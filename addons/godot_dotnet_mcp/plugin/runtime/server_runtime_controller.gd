@tool
extends RefCounted
class_name ServerRuntimeController

signal server_started
signal server_stopped
signal request_received(method: String, params: Dictionary)

const SERVER_SCRIPT_PATH = "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd"
const STDIO_SERVER_SCRIPT_PATH = "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd"
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const ENV_RUNTIME_SERVER_HOST := "GODOT_DOTNET_MCP_SERVER_HOST"
const ENV_RUNTIME_SERVER_PORT := "GODOT_DOTNET_MCP_SERVER_PORT"

var _plugin: EditorPlugin
var _server: Node
var _stdio_server: Node


func attach(plugin: EditorPlugin, settings: Dictionary) -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_attach", "attach")
	_plugin = plugin
	_ensure_server_node(_build_runtime_settings(settings))
	_finish_operation(operation, _server != null, "server_runtime_controller", "attach")


func detach() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_detach", "detach")
	stop()
	_dispose_server_node()
	_dispose_stdio_server_node()
	_plugin = null
	_finish_operation(operation, true, "server_runtime_controller", "detach")


func reinitialize(settings: Dictionary, reason: String = "manual") -> bool:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_reinitialize", reason, {"reason": reason})
	var runtime_settings := _build_runtime_settings(settings)
	var force_reload_server = reason == "tool_soft_reload" or reason == "tool_full_reload"
	if force_reload_server:
		stop()
		_dispose_server_node()

	_ensure_server_node(runtime_settings, force_reload_server)
	if _server == null:
		PluginSelfDiagnosticStore.record_incident(
			"error",
			"server_error",
			"server_node_missing",
			"Server node could not be created during reinitialize",
			"server_runtime_controller",
			reason,
			SERVER_SCRIPT_PATH,
			"",
			str(operation.get("operation_id", "")),
			true,
			"Inspect the server script and plugin lifecycle logs."
		)
		_finish_operation(operation, false, "server_runtime_controller", reason)
		return false

	if _has_server_method("reinitialize"):
		_server.reinitialize(
			int(runtime_settings.get("port", 3000)),
			str(runtime_settings.get("host", "127.0.0.1")),
			_as_bool(runtime_settings.get("debug_mode", true)),
			runtime_settings.get("disabled_tools", []),
			reason
		)
	else:
		if _has_server_method("stop"):
			_server.stop()
		if _has_server_method("initialize"):
			_server.initialize(
				int(runtime_settings.get("port", 3000)),
				str(runtime_settings.get("host", "127.0.0.1")),
				_as_bool(runtime_settings.get("debug_mode", true))
			)
		if _has_server_method("set_disabled_tools"):
			_server.set_disabled_tools(runtime_settings.get("disabled_tools", []))

	_finish_operation(operation, true, "server_runtime_controller", reason)
	return true


func start(settings: Dictionary, reason: String = "manual") -> bool:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_start", reason, {"reason": reason})
	var runtime_settings := _build_runtime_settings(settings)
	if not reinitialize(runtime_settings, reason):
		_finish_operation(operation, false, "server_runtime_controller", reason)
		return false
	if _has_server_method("start"):
		var started = _server.start()
		if not started:
			PluginSelfDiagnosticStore.record_incident(
				"error",
				"server_error",
				"server_start_failed",
				"Embedded MCP server failed to start",
				"server_runtime_controller",
				reason,
				SERVER_SCRIPT_PATH,
				"",
				str(operation.get("operation_id", "")),
				true,
				"Inspect the server listen error and port configuration.",
				{"port": int(runtime_settings.get("port", 3000))}
			)
		# Start stdio server if transport_mode includes stdio
		var transport_mode := str(runtime_settings.get("transport_mode", "http"))
		if transport_mode in ["stdio", "both"]:
			_ensure_stdio_server_node(runtime_settings)
		_finish_operation(operation, started, "server_runtime_controller", reason)
		return started
	_finish_operation(operation, false, "server_runtime_controller", reason)
	return false


func stop() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_stop", "stop")
	if _has_server_method("stop"):
		_server.stop()
	if _stdio_server != null and is_instance_valid(_stdio_server) and _stdio_server.has_method("stop"):
		_stdio_server.stop()
	_finish_operation(operation, true, "server_runtime_controller", "stop")


func is_stdio_running() -> bool:
	return _stdio_server != null and is_instance_valid(_stdio_server) and \
		_stdio_server.has_method("is_running") and _stdio_server.is_running()


func is_running() -> bool:
	return _has_server_method("is_running") and _server.is_running()


func get_server() -> Node:
	return _server


func get_tools_by_category() -> Dictionary:
	if _has_server_method("get_tools_by_category"):
		return _server.get_tools_by_category()
	return {}


func get_all_tools_by_category() -> Dictionary:
	if _has_server_method("get_all_tools_by_category"):
		return _server.get_all_tools_by_category()
	return get_tools_by_category()


func get_tool_load_errors() -> Array:
	if _has_server_method("get_tool_load_errors"):
		return _server.get_tool_load_errors()
	return []


func get_domain_states() -> Array:
	if _has_server_method("get_domain_states"):
		return _server.get_domain_states()
	return []


func get_all_domain_states() -> Array:
	if _has_server_method("get_all_domain_states"):
		return _server.get_all_domain_states()
	return get_domain_states()


func get_reload_status() -> Dictionary:
	if _has_server_method("get_reload_status"):
		return _server.get_reload_status()
	return {}


func get_performance_summary() -> Dictionary:
	if _has_server_method("get_performance_summary"):
		return _server.get_performance_summary()
	return {}


func get_tool_usage_stats() -> Array:
	var loader = _resolve_tool_loader()
	if loader == null or not loader.has_method("get_tool_usage_stats"):
		return []
	return loader.get_tool_usage_stats()


func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"loader": {
			"available": false,
			"has_tool_loader": false,
			"owns_diagnostics_service": false,
			"service_generation": 0,
			"tool_loader_status": {}
		},
		"service": {
			"available": false,
			"request_count": 0,
			"active_key": "",
			"cache_entry_count": 0,
			"last_completed_status": {},
			"status": {},
			"last_error": ""
		},
		"client": {
			"available": false
		},
		"error": "LSP diagnostics status is unavailable"
	}

	var loader = _resolve_tool_loader()
	if loader == null:
		snapshot["error"] = "Tool loader is unavailable"
		return snapshot

	if loader.has_method("get_lsp_diagnostics_debug_snapshot"):
		var loader_snapshot = loader.get_lsp_diagnostics_debug_snapshot()
		if loader_snapshot is Dictionary and not (loader_snapshot as Dictionary).is_empty():
			return _normalize_lsp_diagnostics_snapshot(loader_snapshot as Dictionary)
	if loader.has_method("get_gdscript_lsp_diagnostics_service"):
		var service = loader.get_gdscript_lsp_diagnostics_service()
		if service != null and service.has_method("get_debug_snapshot"):
			return _normalize_lsp_diagnostics_snapshot({
				"has_tool_loader": true,
				"service_available": true,
				"service": service.get_debug_snapshot()
			})

	snapshot["error"] = "Tool loader does not expose LSP diagnostics state"
	return snapshot


func reload_domain(category: String) -> Dictionary:
	if _has_server_method("reload_tool_domain"):
		return _server.reload_tool_domain(category)
	return {}


func reload_all_domains() -> Dictionary:
	if _has_server_method("reload_all_tool_domains"):
		return _server.reload_all_tool_domains()
	return {}


func request_reload_by_script(script_path: String, reason: String = "manual") -> Dictionary:
	var normalized_path = script_path.strip_edges()
	if normalized_path.is_empty():
		return {"success": false, "error": "Missing script path"}
	var loader = _resolve_tool_loader()
	if loader == null or not loader.has_method("request_reload_by_script"):
		return {"success": false, "error": "Tool loader does not support script reload requests"}
	return loader.request_reload_by_script(normalized_path, reason)


func get_user_tool_runtime_snapshot() -> Array[Dictionary]:
	var loader = _resolve_tool_loader()
	if loader == null or not loader.has_method("get_user_tool_runtime_snapshot"):
		return []
	return loader.get_user_tool_runtime_snapshot()


func get_connection_stats() -> Dictionary:
	if _has_server_method("get_connection_stats"):
		return _server.get_connection_stats()
	return {}


func get_tool_loader_status() -> Dictionary:
	if _has_server_method("get_tool_loader_status"):
		return _server.get_tool_loader_status()
	return {}


func get_connection_count() -> int:
	if _has_server_method("get_connection_count"):
		return _server.get_connection_count()
	return 0


func set_debug_mode(enabled: bool) -> void:
	if _has_server_method("set_debug_mode"):
		_server.set_debug_mode(enabled)


func set_disabled_tools(disabled_tools: Array) -> void:
	if _has_server_method("set_disabled_tools"):
		_server.set_disabled_tools(disabled_tools)


func _build_runtime_settings(settings: Dictionary) -> Dictionary:
	var runtime_settings := settings.duplicate(true)
	if OS.has_environment(ENV_RUNTIME_SERVER_HOST):
		var env_host := OS.get_environment(ENV_RUNTIME_SERVER_HOST).strip_edges()
		if not env_host.is_empty():
			runtime_settings["host"] = env_host
	if OS.has_environment(ENV_RUNTIME_SERVER_PORT):
		var env_port := OS.get_environment(ENV_RUNTIME_SERVER_PORT).strip_edges()
		if env_port.is_valid_int():
			var parsed_port := int(env_port)
			if parsed_port > 0:
				runtime_settings["port"] = parsed_port
	return runtime_settings


func _ensure_server_node(settings: Dictionary, force_reload: bool = false) -> void:
	if not force_reload and _server != null and is_instance_valid(_server):
		return

	if _plugin == null:
		PluginSelfDiagnosticStore.record_incident(
			"error",
			"lifecycle_error",
			"server_attach_missing_plugin",
			"Server node creation was requested before the plugin instance was available",
			"server_runtime_controller",
			"ensure_server_node",
			SERVER_SCRIPT_PATH,
			"",
			"",
			true,
			"Ensure attach() runs after the plugin enters the tree."
		)
		return

	var script = ResourceLoader.load(
		SERVER_SCRIPT_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE if force_reload else ResourceLoader.CACHE_MODE_REUSE
	)
	if script == null or not (script is Script):
		PluginSelfDiagnosticStore.record_incident(
			"error",
			"resource_missing",
			"server_script_missing",
			"Server script could not be loaded",
			"server_runtime_controller",
			"ensure_server_node",
			SERVER_SCRIPT_PATH,
			"",
			"",
			true,
			"Verify that the embedded HTTP server script exists and can be instantiated."
		)
		return
	if not (script as Script).can_instantiate():
		PluginSelfDiagnosticStore.record_incident(
			"error",
			"server_error",
			"server_script_not_instantiable",
			"Server script exists but cannot be instantiated",
			"server_runtime_controller",
			"ensure_server_node",
			SERVER_SCRIPT_PATH,
			"",
			"",
			true,
			"Inspect the server script for parse errors or invalid inheritance."
		)
		return

	_server = (script as Script).new()
	if _server == null:
		PluginSelfDiagnosticStore.record_incident(
			"error",
			"server_error",
			"server_instance_create_failed",
			"Server script.new() returned null",
			"server_runtime_controller",
			"ensure_server_node",
			SERVER_SCRIPT_PATH,
			"",
			"",
			true,
			"Inspect the server script for instantiation errors."
		)
		return

	_server.name = "MCPHttpServer"
	_plugin.add_child(_server)

	if _has_server_method("initialize"):
		_server.initialize(
			int(settings.get("port", 3000)),
			str(settings.get("host", "127.0.0.1")),
			_as_bool(settings.get("debug_mode", true))
		)

	if _has_server_method("set_disabled_tools"):
		_server.set_disabled_tools(settings.get("disabled_tools", []))

	_connect_server_signals()


func _dispose_server_node() -> void:
	if _server != null and is_instance_valid(_server):
		if _server.get_parent() != null:
			_server.get_parent().remove_child(_server)
		_server.set_script(null)
		_server.free()
	_server = null


func _ensure_stdio_server_node(settings: Dictionary) -> void:
	if _plugin == null:
		return
	# Create stdio server node if not already present
	if _stdio_server == null or not is_instance_valid(_stdio_server):
		var script = ResourceLoader.load(STDIO_SERVER_SCRIPT_PATH, "", ResourceLoader.CACHE_MODE_REUSE)
		if script == null or not (script is Script):
			return
		if not (script as Script).can_instantiate():
			return
		_stdio_server = (script as Script).new()
		if _stdio_server == null:
			return
		_stdio_server.name = "MCPStdioServer"
		_plugin.add_child(_stdio_server)

	# Inject tool_loader from the HTTP server
	if _server != null and is_instance_valid(_server) and _server.has_method("get_tool_loader"):
		_stdio_server.initialize(_server.get_tool_loader(), _as_bool(settings.get("debug_mode", false)))

	if _stdio_server.has_method("set_disabled_tools"):
		_stdio_server.set_disabled_tools(settings.get("disabled_tools", []))
	if _stdio_server.has_method("start"):
		_stdio_server.start()


func _dispose_stdio_server_node() -> void:
	if _stdio_server != null and is_instance_valid(_stdio_server):
		if _stdio_server.get_parent() != null:
			_stdio_server.get_parent().remove_child(_stdio_server)
		_stdio_server.set_script(null)
		_stdio_server.free()
	_stdio_server = null


func _connect_server_signals() -> void:
	if _server == null:
		return

	if _server.has_signal("server_started") and not _server.server_started.is_connected(_on_server_started):
		_server.server_started.connect(_on_server_started)
	if _server.has_signal("server_stopped") and not _server.server_stopped.is_connected(_on_server_stopped):
		_server.server_stopped.connect(_on_server_stopped)
	if _server.has_signal("request_received") and not _server.request_received.is_connected(_on_request_received):
		_server.request_received.connect(_on_request_received)


func _has_server_method(method_name: String) -> bool:
	return _server != null and is_instance_valid(_server) and _server.has_method(method_name)


func _resolve_tool_loader():
	if _server == null or not is_instance_valid(_server):
		return null
	if _server.has_method("get_tool_loader"):
		return _server.get_tool_loader()
	return null


func _normalize_lsp_diagnostics_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {
		"loader": {
			"available": bool(raw_snapshot.get("has_tool_loader", false)),
			"has_tool_loader": bool(raw_snapshot.get("has_tool_loader", false)),
			"owns_diagnostics_service": bool(raw_snapshot.get("service_available", false)),
			"service_generation": int(raw_snapshot.get("service_generation", 0)),
			"tool_loader_status": raw_snapshot.get("tool_loader_status", {})
		},
		"service": {
			"available": false,
			"request_count": 0,
			"active_key": "",
			"cache_entry_count": 0,
			"last_completed_status": {},
			"status": {},
			"last_error": ""
		},
		"client": {
			"available": false
		},
		"error": "LSP diagnostics status is unavailable"
	}

	var service_raw = raw_snapshot.get("service", {})
	var service_snapshot: Dictionary = {}
	if service_raw is Dictionary:
		service_snapshot = (service_raw as Dictionary).duplicate(true)

	var service_summary_raw = snapshot.get("service", {})
	var service_summary: Dictionary = service_summary_raw if service_summary_raw is Dictionary else {}
	service_summary["available"] = bool(raw_snapshot.get("service_available", false)) and not service_snapshot.is_empty()
	service_summary["request_count"] = int(service_snapshot.get("request_count", 0))
	service_summary["active_key"] = str(service_snapshot.get("active_key", ""))
	service_summary["cache_entry_count"] = int(service_snapshot.get("cache_entry_count", 0))
	service_summary["last_completed_status"] = service_snapshot.get("last_completed_status", {})
	service_summary["status"] = service_snapshot.get("status", {})

	var status_raw = service_summary.get("status", {})
	var status_dict: Dictionary = status_raw if status_raw is Dictionary else {}
	var last_completed_raw = service_summary.get("last_completed_status", {})
	var last_completed: Dictionary = last_completed_raw if last_completed_raw is Dictionary else {}
	var client_raw = service_snapshot.get("client", {})
	if client_raw is Dictionary:
		var client_snapshot := (client_raw as Dictionary).duplicate(true)
		client_snapshot["available"] = not client_snapshot.is_empty()
		snapshot["client"] = client_snapshot

	var last_error := str(status_dict.get("error", ""))
	if last_error.is_empty():
		last_error = str(last_completed.get("error", ""))
	service_summary["last_error"] = last_error
	snapshot["service"] = service_summary

	if bool(service_summary.get("available", false)):
		snapshot.erase("error")
	elif not last_error.is_empty():
		snapshot["error"] = last_error
	return snapshot


func _as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return !is_zero_approx(value)
	if value is String:
		var normalized = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null


func _on_server_started() -> void:
	server_started.emit()


func _on_server_stopped() -> void:
	server_stopped.emit()


func _on_request_received(method: String, params: Dictionary) -> void:
	request_received.emit(method, params)


func _finish_operation(operation: Dictionary, success: bool, component: String, phase: String) -> void:
	if operation.is_empty():
		return
	var finished = PluginSelfDiagnosticStore.end_operation(str(operation.get("operation_id", "")), success, [], {"component": component, "phase": phase})
	PluginSelfDiagnosticStore.record_slow_operation(finished, component, phase)
