@tool
extends RefCounted
class_name PluginRuntimeCoordinator

const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")


func ensure_runtime_bridge_autoload(plugin, autoload_name: String, runtime_bridge_path: String) -> void:
	if plugin == null:
		return
	var setting_key := "autoload/%s" % autoload_name
	var current_path := str(ProjectSettings.get_setting(setting_key, ""))
	if _is_runtime_bridge_autoload_path(current_path, runtime_bridge_path):
		MCPRuntimeDebugStore.set_bridge_status(true, autoload_name, runtime_bridge_path, "Runtime bridge autoload already installed")
		return
	if not current_path.is_empty():
		MCPRuntimeDebugStore.set_bridge_status(false, autoload_name, current_path, "Autoload name is occupied by another script")
		return
	if plugin.has_method("add_autoload_singleton"):
		plugin.add_autoload_singleton(autoload_name, runtime_bridge_path)
	else:
		ProjectSettings.set_setting(setting_key, runtime_bridge_path)
	MCPRuntimeDebugStore.set_bridge_status(true, autoload_name, runtime_bridge_path, "Runtime bridge autoload installed")


func remove_runtime_bridge_autoload(plugin, autoload_name: String, runtime_bridge_path: String) -> bool:
	if plugin == null:
		return false
	var setting_key := "autoload/%s" % autoload_name
	var current_path := str(ProjectSettings.get_setting(setting_key, ""))
	if not _is_runtime_bridge_autoload_path(current_path, runtime_bridge_path):
		MCPRuntimeDebugStore.set_bridge_status(false, autoload_name, current_path, "Runtime bridge autoload not owned by this plugin")
		return false
	if plugin.has_method("remove_autoload_singleton"):
		plugin.remove_autoload_singleton(autoload_name)
	else:
		ProjectSettings.set_setting(setting_key, "")
	ProjectSettings.save()
	MCPRuntimeDebugStore.set_bridge_status(false, autoload_name, runtime_bridge_path, "Runtime bridge autoload removed")
	return true


func install_editor_debugger_bridge(plugin, current_bridge, bridge_factory: Callable):
	if current_bridge != null:
		return current_bridge
	if plugin == null or not bridge_factory.is_valid():
		return null
	var bridge = bridge_factory.call()
	if bridge == null:
		return null
	if plugin.has_method("add_debugger_plugin"):
		plugin.add_debugger_plugin(bridge)
	return bridge


func uninstall_editor_debugger_bridge(plugin, bridge):
	if bridge == null:
		return null
	if plugin != null and plugin.has_method("remove_debugger_plugin"):
		plugin.remove_debugger_plugin(bridge)
	if bridge.has_method("set_script"):
		bridge.set_script(null)
	return null


func has_runtime_bridge_root_instance(plugin, autoload_name: String) -> bool:
	var tree = _get_tree(plugin)
	if tree == null or tree.root == null:
		return false
	var runtime_bridge = tree.root.get_node_or_null(NodePath(autoload_name))
	return runtime_bridge != null and is_instance_valid(runtime_bridge)


func attach_server_controller(current_controller, plugin, settings: Dictionary, action_router, factory: Callable):
	var controller = current_controller
	if controller == null and factory.is_valid():
		controller = factory.call()
	if controller == null:
		return null
	if controller.has_method("attach"):
		controller.attach(plugin, settings)
	_connect_server_controller_signals(controller, action_router)
	return controller


func dispose_server_controller(server_controller, action_router):
	if server_controller == null:
		return null
	_disconnect_server_controller_signals(server_controller, action_router)
	if server_controller.has_method("detach"):
		server_controller.detach()
	return null


func recreate_server_controller(current_controller, plugin, settings: Dictionary, action_router, factory: Callable):
	dispose_server_controller(current_controller, action_router)
	return attach_server_controller(null, plugin, settings, action_router, factory)


func _connect_server_controller_signals(server_controller, action_router) -> void:
	if server_controller == null or action_router == null:
		return
	if server_controller.has_signal("server_started") and action_router.has_method("handle_server_started"):
		var started_callable = Callable(action_router, "handle_server_started")
		if not server_controller.server_started.is_connected(started_callable):
			server_controller.server_started.connect(started_callable)
	if server_controller.has_signal("server_stopped") and action_router.has_method("handle_server_stopped"):
		var stopped_callable = Callable(action_router, "handle_server_stopped")
		if not server_controller.server_stopped.is_connected(stopped_callable):
			server_controller.server_stopped.connect(stopped_callable)
	if server_controller.has_signal("request_received") and action_router.has_method("handle_request_received"):
		var request_callable = Callable(action_router, "handle_request_received")
		if not server_controller.request_received.is_connected(request_callable):
			server_controller.request_received.connect(request_callable)


func _disconnect_server_controller_signals(server_controller, action_router) -> void:
	if server_controller == null or action_router == null:
		return
	if server_controller.has_signal("server_started") and action_router.has_method("handle_server_started"):
		var started_callable = Callable(action_router, "handle_server_started")
		if server_controller.server_started.is_connected(started_callable):
			server_controller.server_started.disconnect(started_callable)
	if server_controller.has_signal("server_stopped") and action_router.has_method("handle_server_stopped"):
		var stopped_callable = Callable(action_router, "handle_server_stopped")
		if server_controller.server_stopped.is_connected(stopped_callable):
			server_controller.server_stopped.disconnect(stopped_callable)
	if server_controller.has_signal("request_received") and action_router.has_method("handle_request_received"):
		var request_callable = Callable(action_router, "handle_request_received")
		if server_controller.request_received.is_connected(request_callable):
			server_controller.request_received.disconnect(request_callable)


func _get_tree(plugin):
	if plugin == null:
		return null
	if plugin.has_method("get_tree"):
		return plugin.get_tree()
	return null


func _is_runtime_bridge_autoload_path(setting_value: String, runtime_bridge_path: String) -> bool:
	var normalized := setting_value.trim_prefix("*")
	return normalized == runtime_bridge_path
