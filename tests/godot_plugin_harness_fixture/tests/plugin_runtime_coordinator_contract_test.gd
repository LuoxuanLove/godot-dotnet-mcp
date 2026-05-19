extends RefCounted

const PluginRuntimeCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/plugin_runtime_coordinator.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

const AUTOLOAD_NAME := "MCPRuntimeBridgeContract"
const RUNTIME_BRIDGE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd"

var _autoload_key := "autoload/%s" % AUTOLOAD_NAME


class FakePlugin extends RefCounted:
	var autoload_calls: Array[Dictionary] = []
	var autoload_removed: Array[String] = []
	var debugger_added: Array = []
	var debugger_removed: Array = []

	func add_autoload_singleton(name: String, path: String) -> void:
		ProjectSettings.set_setting("autoload/%s" % name, path)
		autoload_calls.append({
			"name": name,
			"path": path
		})

	func add_debugger_plugin(plugin) -> void:
		debugger_added.append(plugin)

	func remove_debugger_plugin(plugin) -> void:
		debugger_removed.append(plugin)

	func remove_autoload_singleton(name: String) -> void:
		autoload_removed.append(name)
		ProjectSettings.set_setting("autoload/%s" % name, "")

	func get_tree():
		return null


class FakeDebuggerBridge extends RefCounted:
	pass


class FakeActionRouter extends RefCounted:
	var started_count := 0
	var stopped_count := 0
	var request_count := 0

	func handle_server_started() -> void:
		started_count += 1

	func handle_server_stopped() -> void:
		stopped_count += 1

	func handle_request_received(_method: String, _params: Dictionary) -> void:
		request_count += 1


class FakeServerController extends RefCounted:
	signal server_started
	signal server_stopped
	signal request_received(method: String, params: Dictionary)

	var attach_count := 0
	var detach_count := 0
	var attached_plugin = null
	var attached_settings: Dictionary = {}

	func attach(plugin, settings: Dictionary) -> void:
		attach_count += 1
		attached_plugin = plugin
		attached_settings = settings.duplicate(true)

	func detach() -> void:
		detach_count += 1
		attached_plugin = null
		attached_settings = {}


func run_case(_tree: SceneTree) -> Dictionary:
	var coordinator = PluginRuntimeCoordinator.new()
	var plugin = FakePlugin.new()
	var action_router = FakeActionRouter.new()
	ProjectSettings.set_setting(_autoload_key, "")
	MCPRuntimeDebugStore.clear()
	PluginSelfDiagnosticStore.clear()

	coordinator.ensure_runtime_bridge_autoload(plugin, AUTOLOAD_NAME, RUNTIME_BRIDGE_PATH)
	if str(ProjectSettings.get_setting(_autoload_key, "")) != RUNTIME_BRIDGE_PATH:
		return _failure("PluginRuntimeCoordinator should install the runtime bridge autoload path.")
	if plugin.autoload_calls.size() != 1:
		return _failure("Runtime bridge autoload should be registered once.")

	var bridge_status: Dictionary = MCPRuntimeDebugStore.get_bridge_status()
	if not bool(bridge_status.get("installed", false)):
		return _failure("Runtime bridge status should report installed after autoload registration.")
	if str(bridge_status.get("autoload_name", "")) != AUTOLOAD_NAME:
		return _failure("Runtime bridge status should keep the configured autoload name.")

	coordinator.ensure_runtime_bridge_autoload(plugin, AUTOLOAD_NAME, RUNTIME_BRIDGE_PATH)
	if plugin.autoload_calls.size() != 1:
		return _failure("Runtime bridge autoload should not register twice when already installed.")

	if not coordinator.remove_runtime_bridge_autoload(plugin, AUTOLOAD_NAME, RUNTIME_BRIDGE_PATH):
		return _failure("PluginRuntimeCoordinator should remove the runtime bridge autoload.")
	if plugin.autoload_removed.size() != 1:
		return _failure("Runtime bridge autoload should be removed exactly once.")
	if str(ProjectSettings.get_setting(_autoload_key, "")) != "":
		return _failure("Runtime bridge autoload path should be cleared after removal.")

	var debugger_bridge = coordinator.install_editor_debugger_bridge(plugin, null, Callable(self, "_create_fake_debugger_bridge"))
	if debugger_bridge == null:
		return _failure("PluginRuntimeCoordinator should create the debugger bridge.")
	if plugin.debugger_added.size() != 1:
		return _failure("PluginRuntimeCoordinator should install the debugger bridge exactly once.")

	debugger_bridge = coordinator.uninstall_editor_debugger_bridge(plugin, debugger_bridge)
	if debugger_bridge != null:
		return _failure("PluginRuntimeCoordinator should clear the debugger bridge reference on uninstall.")
	if plugin.debugger_removed.size() != 1:
		return _failure("PluginRuntimeCoordinator should uninstall the debugger bridge exactly once.")

	if coordinator.has_runtime_bridge_root_instance(plugin, AUTOLOAD_NAME):
		return _failure("Coordinator should not report a runtime bridge root instance when no tree is available.")

	var server_controller = coordinator.attach_server_controller(
		null,
		plugin,
		{"auto_start": true},
		action_router,
		Callable(self, "_create_fake_server_controller")
	)
	if server_controller == null:
		return _failure("PluginRuntimeCoordinator should create and attach a server controller.")
	if server_controller.attach_count != 1:
		return _failure("PluginRuntimeCoordinator should attach the server controller exactly once.")
	server_controller.server_started.emit()
	server_controller.server_stopped.emit()
	server_controller.request_received.emit("tools/list", {})
	if action_router.started_count != 1 or action_router.stopped_count != 1 or action_router.request_count != 1:
		return _failure("PluginRuntimeCoordinator should wire server controller signals to the action router.")

	var disposed_controller = server_controller
	server_controller = coordinator.dispose_server_controller(server_controller, action_router)
	if server_controller != null:
		return _failure("PluginRuntimeCoordinator should clear the server controller reference on dispose.")
	disposed_controller.server_started.emit()
	if action_router.started_count != 1:
		return _failure("Disposed server controller should be disconnected from the action router.")

	var recreated_controller = coordinator.recreate_server_controller(
		FakeServerController.new(),
		plugin,
		{"auto_start": false},
		action_router,
		Callable(self, "_create_fake_server_controller")
	)
	if recreated_controller == null:
		return _failure("PluginRuntimeCoordinator should recreate the server controller.")
	if recreated_controller.attach_count != 1:
		return _failure("Recreated server controller should be attached exactly once.")

	return {
		"name": "plugin_runtime_coordinator_contracts",
		"success": true,
		"error": "",
		"details": {
			"autoload_calls": plugin.autoload_calls.size(),
			"debugger_add_count": plugin.debugger_added.size(),
			"debugger_remove_count": plugin.debugger_removed.size(),
			"server_started_count": action_router.started_count
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	ProjectSettings.set_setting(_autoload_key, "")
	MCPRuntimeDebugStore.clear()
	PluginSelfDiagnosticStore.clear()


func _create_fake_debugger_bridge():
	return FakeDebuggerBridge.new()


func _create_fake_server_controller():
	return FakeServerController.new()


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_runtime_coordinator_contracts",
		"success": false,
		"error": message
	}
