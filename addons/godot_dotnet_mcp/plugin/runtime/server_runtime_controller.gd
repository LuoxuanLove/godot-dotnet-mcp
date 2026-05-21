@tool
extends RefCounted
class_name ServerRuntimeController

signal server_started
signal server_stopped
signal request_received(method: String, params: Dictionary)

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const ServerRuntimeLspDiagnosticsSnapshotService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_lsp_diagnostics_snapshot_service.gd")
const ServerRuntimeNodeLifecycleService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_node_lifecycle_service.gd")
const ServerRuntimeSettingsProjectionService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_settings_projection_service.gd")
const SERVER_SCRIPT_PATH = "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd"

var _plugin: EditorPlugin
var _server: Node
var _stdio_server: Node
var _lsp_snapshot_service := ServerRuntimeLspDiagnosticsSnapshotService.new()
var _node_lifecycle := ServerRuntimeNodeLifecycleService.new()
var _settings_projection := ServerRuntimeSettingsProjectionService.new()


func attach(plugin: EditorPlugin, settings: Dictionary) -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_attach", "attach")
	_plugin = plugin
	var runtime_settings := _settings_projection.project(settings)
	_server = _node_lifecycle.ensure_server_node(
		_plugin,
		_server,
		runtime_settings,
		false,
		Callable(self, "_on_server_started"),
		Callable(self, "_on_server_stopped"),
		Callable(self, "_on_request_received")
	)
	_finish_operation(operation, _server != null, "server_runtime_controller", "attach")


func detach() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_detach", "detach")
	stop()
	_node_lifecycle.dispose_server_node(_server)
	_server = null
	_node_lifecycle.dispose_stdio_server_node(_stdio_server)
	_stdio_server = null
	_plugin = null
	_finish_operation(operation, true, "server_runtime_controller", "detach")


func reinitialize(settings: Dictionary, reason: String = "manual") -> bool:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_reinitialize", reason, {"reason": reason})
	var operation_id := str(operation.get("operation_id", ""))
	var phase_started = PluginSelfDiagnosticStore.begin_phase()
	var runtime_settings := _settings_projection.project(settings)
	PluginSelfDiagnosticStore.record_operation_phase(operation_id, "settings_projection", phase_started, {"reason": reason})
	return _reinitialize_runtime_settings(runtime_settings, reason, true, operation)


func start(settings: Dictionary, reason: String = "manual") -> bool:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_start", reason, {"reason": reason})
	var operation_id := str(operation.get("operation_id", ""))
	var phase_started = PluginSelfDiagnosticStore.begin_phase()
	var runtime_settings := _settings_projection.project(settings)
	PluginSelfDiagnosticStore.record_operation_phase(operation_id, "settings_projection", phase_started, {"reason": reason})
	if not _reinitialize_runtime_settings(runtime_settings, reason, false, operation):
		_finish_operation(operation, false, "server_runtime_controller", reason)
		return false
	if _has_server_method("start"):
		phase_started = PluginSelfDiagnosticStore.begin_phase()
		var started = _server.start(operation_id)
		PluginSelfDiagnosticStore.record_operation_phase(operation_id, "http_server.start", phase_started, {"started": started})
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
				operation_id,
				true,
				"Inspect the server listen error and port configuration.",
				{"port": int(runtime_settings.get("port", ServerRuntimeSettingsProjectionService.DEFAULT_PORT))}
			)
		var transport_mode := str(runtime_settings.get("transport_mode", ServerRuntimeSettingsProjectionService.DEFAULT_TRANSPORT_MODE))
		if transport_mode in ["stdio", "both"]:
			phase_started = PluginSelfDiagnosticStore.begin_phase()
			_stdio_server = _node_lifecycle.ensure_stdio_server_node(_plugin, _stdio_server, _server, runtime_settings, operation_id)
			PluginSelfDiagnosticStore.record_operation_phase(operation_id, "stdio_server.ensure", phase_started, {"transport_mode": transport_mode})
		_finish_operation(operation, started, "server_runtime_controller", reason)
		return started
	_finish_operation(operation, false, "server_runtime_controller", reason)
	return false


func _reinitialize_runtime_settings(runtime_settings: Dictionary, reason: String, track_operation: bool, operation: Dictionary = {}) -> bool:
	if track_operation and operation.is_empty():
		operation = PluginSelfDiagnosticStore.begin_operation("server_reinitialize", reason, {"reason": reason})
	var operation_id := str(operation.get("operation_id", ""))
	var effective_reason := "plugin_lifecycle_reload" if reason == "auto_start" else reason
	var force_reload_server = reason == "tool_soft_reload" or reason == "tool_full_reload" or reason == "auto_start"
	if force_reload_server:
		var dispose_started = PluginSelfDiagnosticStore.begin_phase()
		stop()
		_node_lifecycle.dispose_server_node(_server)
		_server = null
		PluginSelfDiagnosticStore.record_operation_phase(operation_id, "server_node.dispose_existing", dispose_started, {"reason": reason})

	var ensure_started = PluginSelfDiagnosticStore.begin_phase()
	_server = _node_lifecycle.ensure_server_node(
		_plugin,
		_server,
		runtime_settings,
		force_reload_server,
		Callable(self, "_on_server_started"),
		Callable(self, "_on_server_stopped"),
		Callable(self, "_on_request_received"),
		operation_id
	)
	PluginSelfDiagnosticStore.record_operation_phase(operation_id, "server_node.ensure", ensure_started, {"force_reload": force_reload_server})
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
		if track_operation:
			_finish_operation(operation, false, "server_runtime_controller", reason)
		return false

	if _has_server_method("reinitialize"):
		var disabled_tools: Array = runtime_settings.get("disabled_tools", [])
		var reinitialize_started = PluginSelfDiagnosticStore.begin_phase()
		_server.reinitialize(
			int(runtime_settings.get("port", ServerRuntimeSettingsProjectionService.DEFAULT_PORT)),
			str(runtime_settings.get("host", ServerRuntimeSettingsProjectionService.DEFAULT_HOST)),
			bool(runtime_settings.get("debug_mode", true)),
			disabled_tools,
			effective_reason,
			operation_id
		)
		PluginSelfDiagnosticStore.record_operation_phase(operation_id, "http_server.reinitialize", reinitialize_started, {"reason": effective_reason})
	else:
		var legacy_started = PluginSelfDiagnosticStore.begin_phase()
		if _has_server_method("stop"):
			_server.stop()
		if _has_server_method("initialize"):
			_server.initialize(
				int(runtime_settings.get("port", ServerRuntimeSettingsProjectionService.DEFAULT_PORT)),
				str(runtime_settings.get("host", ServerRuntimeSettingsProjectionService.DEFAULT_HOST)),
				bool(runtime_settings.get("debug_mode", true)),
				operation_id
			)
		if _has_server_method("set_disabled_tools"):
			var disabled_tools: Array = runtime_settings.get("disabled_tools", [])
			_server.set_disabled_tools(disabled_tools)
		PluginSelfDiagnosticStore.record_operation_phase(operation_id, "http_server.legacy_initialize", legacy_started, {"reason": effective_reason})

	if track_operation:
		_finish_operation(operation, true, "server_runtime_controller", effective_reason)
	return true


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
	return _lsp_snapshot_service.build_snapshot(_resolve_tool_loader())


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


func _has_server_method(method_name: String) -> bool:
	return _server != null and is_instance_valid(_server) and _server.has_method(method_name)


func _resolve_tool_loader():
	if _server == null or not is_instance_valid(_server):
		return null
	if _server.has_method("get_tool_loader"):
		return _server.get_tool_loader()
	return null


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
