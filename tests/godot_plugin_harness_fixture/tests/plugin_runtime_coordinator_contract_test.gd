extends RefCounted

const PluginRuntimeCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/plugin_runtime_coordinator.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

const AUTOLOAD_NAME := "MCPRuntimeBridgeContract"
const RUNTIME_BRIDGE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd"

var _autoload_key := "autoload/%s" % AUTOLOAD_NAME


class FakePlugin extends RefCounted:
	var autoload_calls: Array[Dictionary] = []
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

	func get_tree():
		return null


class FakeDebuggerBridge extends RefCounted:
	pass


func run_case(_tree: SceneTree) -> Dictionary:
	var coordinator = PluginRuntimeCoordinator.new()
	var plugin = FakePlugin.new()
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

	return {
		"name": "plugin_runtime_coordinator_contracts",
		"success": true,
		"error": "",
		"details": {
			"autoload_calls": plugin.autoload_calls.size(),
			"debugger_add_count": plugin.debugger_added.size(),
			"debugger_remove_count": plugin.debugger_removed.size()
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	ProjectSettings.set_setting(_autoload_key, "")
	MCPRuntimeDebugStore.clear()
	PluginSelfDiagnosticStore.clear()


func _create_fake_debugger_bridge():
	return FakeDebuggerBridge.new()


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_runtime_coordinator_contracts",
		"success": false,
		"error": message
	}
