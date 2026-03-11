@tool
extends RefCounted
class_name ServerRuntimeController

signal server_started
signal server_stopped
signal request_received(method: String, params: Dictionary)

const SERVER_SCRIPT_PATH = "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd"

var _plugin: EditorPlugin
var _server: Node


func attach(plugin: EditorPlugin, settings: Dictionary) -> void:
	_plugin = plugin
	_ensure_server_node(settings)


func detach() -> void:
	stop()
	_dispose_server_node()
	_plugin = null


func reinitialize(settings: Dictionary, reason: String = "manual") -> bool:
	_ensure_server_node(settings)
	if _server == null:
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

	return true


func start(settings: Dictionary, reason: String = "manual") -> bool:
	if not reinitialize(settings, reason):
		return false
	if _has_server_method("start"):
		return _server.start()
	return false


func stop() -> void:
	if _has_server_method("stop"):
		_server.stop()


func is_running() -> bool:
	return _has_server_method("is_running") and _server.is_running()


func get_server() -> Node:
	return _server


func get_tools_by_category() -> Dictionary:
	if _has_server_method("get_tools_by_category"):
		return _server.get_tools_by_category()
	return {}


func get_tool_load_errors() -> Array:
	if _has_server_method("get_tool_load_errors"):
		return _server.get_tool_load_errors()
	return []


func get_domain_states() -> Array:
	if _has_server_method("get_domain_states"):
		return _server.get_domain_states()
	return []


func get_reload_status() -> Dictionary:
	if _has_server_method("get_reload_status"):
		return _server.get_reload_status()
	return {}


func get_performance_summary() -> Dictionary:
	if _has_server_method("get_performance_summary"):
		return _server.get_performance_summary()
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


func _ensure_server_node(settings: Dictionary) -> void:
	if _server != null and is_instance_valid(_server):
		return

	if _plugin == null:
		return

	var script = load(SERVER_SCRIPT_PATH)
	if script == null:
		return

	_server = script.new()
	if _server == null:
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
		_server.queue_free()
	_server = null


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
