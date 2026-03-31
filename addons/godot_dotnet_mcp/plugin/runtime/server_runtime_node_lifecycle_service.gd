@tool
extends RefCounted
class_name ServerRuntimeNodeLifecycleService

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const SERVER_SCRIPT_PATH = "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd"
const STDIO_SERVER_SCRIPT_PATH = "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd"


func ensure_server_node(
	plugin_root: EditorPlugin,
	existing_server: Node,
	settings: Dictionary,
	force_reload: bool,
	on_server_started: Callable,
	on_server_stopped: Callable,
	on_request_received: Callable
) -> Node:
	if not force_reload and existing_server != null and is_instance_valid(existing_server):
		_connect_server_signals(existing_server, on_server_started, on_server_stopped, on_request_received)
		return existing_server

	if plugin_root == null:
		_record_server_incident(
			"lifecycle_error",
			"server_attach_missing_plugin",
			"Server node creation was requested before the plugin instance was available",
			"Ensure attach() runs after the plugin enters the tree."
		)
		return null

	var script = _load_server_script(force_reload)
	if script == null:
		return null

	var server = script.new()
	if server == null:
		_record_server_incident(
			"server_error",
			"server_instance_create_failed",
			"Server script.new() returned null",
			"Inspect the server script for instantiation errors."
		)
		return null

	server.name = "MCPHttpServer"
	plugin_root.add_child(server)

	if server.has_method("initialize"):
		server.initialize(
			int(settings.get("port", 3000)),
			str(settings.get("host", "127.0.0.1")),
			_as_bool(settings.get("debug_mode", true))
		)

	if server.has_method("set_disabled_tools"):
		server.set_disabled_tools(settings.get("disabled_tools", []))

	_connect_server_signals(server, on_server_started, on_server_stopped, on_request_received)
	return server


func dispose_server_node(server: Node) -> void:
	_dispose_node(server)


func ensure_stdio_server_node(plugin_root: EditorPlugin, existing_stdio_server: Node, server: Node, settings: Dictionary) -> Node:
	if plugin_root == null:
		return existing_stdio_server

	var stdio_server = existing_stdio_server
	if stdio_server == null or not is_instance_valid(stdio_server):
		var script = ResourceLoader.load(STDIO_SERVER_SCRIPT_PATH, "", ResourceLoader.CACHE_MODE_REUSE)
		if script == null or not (script is Script):
			return null
		if not (script as Script).can_instantiate():
			return null
		stdio_server = (script as Script).new()
		if stdio_server == null:
			return null
		stdio_server.name = "MCPStdioServer"
		plugin_root.add_child(stdio_server)

	if server != null and is_instance_valid(server) and server.has_method("get_tool_loader"):
		stdio_server.initialize(server.get_tool_loader(), _as_bool(settings.get("debug_mode", false)))

	if stdio_server.has_method("set_disabled_tools"):
		stdio_server.set_disabled_tools(settings.get("disabled_tools", []))
	if stdio_server.has_method("start"):
		stdio_server.start()
	return stdio_server


func dispose_stdio_server_node(stdio_server: Node) -> void:
	_dispose_node(stdio_server)


func _connect_server_signals(
	server: Node,
	on_server_started: Callable,
	on_server_stopped: Callable,
	on_request_received: Callable
) -> void:
	if server == null:
		return

	if on_server_started.is_valid() and server.has_signal("server_started") and not server.server_started.is_connected(on_server_started):
		server.server_started.connect(on_server_started)
	if on_server_stopped.is_valid() and server.has_signal("server_stopped") and not server.server_stopped.is_connected(on_server_stopped):
		server.server_stopped.connect(on_server_stopped)
	if on_request_received.is_valid() and server.has_signal("request_received") and not server.request_received.is_connected(on_request_received):
		server.request_received.connect(on_request_received)


func _dispose_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.set_script(null)
	node.free()


func _load_server_script(force_reload: bool) -> Script:
	var script = ResourceLoader.load(
		SERVER_SCRIPT_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE if force_reload else ResourceLoader.CACHE_MODE_REUSE
	)
	if script == null or not (script is Script):
		_record_server_incident(
			"resource_missing",
			"server_script_missing",
			"Server script could not be loaded",
			"Verify that the embedded HTTP server script exists and can be instantiated."
		)
		return null
	if not (script as Script).can_instantiate():
		_record_server_incident(
			"server_error",
			"server_script_not_instantiable",
			"Server script exists but cannot be instantiated",
			"Inspect the server script for parse errors or invalid inheritance."
		)
		return null
	return script as Script


func _record_server_incident(incident_type: String, incident_code: String, summary: String, guidance: String) -> void:
	PluginSelfDiagnosticStore.record_incident(
		"error",
		incident_type,
		incident_code,
		summary,
		"server_runtime_node_lifecycle_service",
		"ensure_server_node",
		SERVER_SCRIPT_PATH,
		"",
		"",
		true,
		guidance
	)


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
