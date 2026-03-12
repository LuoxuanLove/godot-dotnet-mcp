@tool
extends RefCounted
class_name ServerRuntimeController

signal server_started
signal server_stopped
signal request_received(method: String, params: Dictionary)

const SERVER_SCRIPT_PATH = "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd"
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

var _plugin: EditorPlugin
var _server: Node


func attach(plugin: EditorPlugin, settings: Dictionary) -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_attach", "attach")
	_plugin = plugin
	_ensure_server_node(settings)
	_finish_operation(operation, _server != null, "server_runtime_controller", "attach")


func detach() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_detach", "detach")
	stop()
	_dispose_server_node()
	_plugin = null
	_finish_operation(operation, true, "server_runtime_controller", "detach")


func reinitialize(settings: Dictionary, reason: String = "manual") -> bool:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_reinitialize", reason, {"reason": reason})
	var force_reload_server = reason == "tool_soft_reload"
	if force_reload_server:
		stop()
		_dispose_server_node()

	_ensure_server_node(settings, force_reload_server)
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
			int(settings.get("port", 3000)),
			str(settings.get("host", "127.0.0.1")),
			bool(settings.get("debug_mode", true)),
			settings.get("disabled_tools", []),
			reason
		)
	else:
		if _has_server_method("stop"):
			_server.stop()
		if _has_server_method("initialize"):
			_server.initialize(
				int(settings.get("port", 3000)),
				str(settings.get("host", "127.0.0.1")),
				bool(settings.get("debug_mode", true))
			)
		if _has_server_method("set_disabled_tools"):
			_server.set_disabled_tools(settings.get("disabled_tools", []))

	_finish_operation(operation, true, "server_runtime_controller", reason)
	return true


func start(settings: Dictionary, reason: String = "manual") -> bool:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_start", reason, {"reason": reason})
	if not reinitialize(settings, reason):
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
				{"port": int(settings.get("port", 3000))}
			)
		_finish_operation(operation, started, "server_runtime_controller", reason)
		return started
	_finish_operation(operation, false, "server_runtime_controller", reason)
	return false


func stop() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("server_stop", "stop")
	if _has_server_method("stop"):
		_server.stop()
	_finish_operation(operation, true, "server_runtime_controller", "stop")


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


func reload_domain(category: String) -> Dictionary:
	if _has_server_method("reload_tool_domain"):
		return _server.reload_tool_domain(category)
	return {}


func reload_all_domains() -> Dictionary:
	if _has_server_method("reload_all_tool_domains"):
		return _server.reload_all_tool_domains()
	return {}


func get_connection_stats() -> Dictionary:
	if _has_server_method("get_connection_stats"):
		return _server.get_connection_stats()
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
		ResourceLoader.CACHE_MODE_IGNORE if force_reload else ResourceLoader.CACHE_MODE_REUSE
	)
	if script is Script and force_reload:
		_reload_script_dependency_chain(script as Script, {})
	if script == null:
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

	_server = script.new()
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
			bool(settings.get("debug_mode", true))
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


func _reload_script_dependency_chain(script_resource: Script, visited: Dictionary) -> void:
	if script_resource == null:
		return

	var script_path = str(script_resource.resource_path)
	if not script_path.is_empty():
		if visited.has(script_path):
			return
		visited[script_path] = true

	var base_script = script_resource.get_base_script()
	if base_script is Script:
		_reload_script_dependency_chain(base_script as Script, visited)

	for constant_value in script_resource.get_script_constant_map().values():
		if constant_value is Script:
			_reload_script_dependency_chain(constant_value as Script, visited)

	script_resource.reload()


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
