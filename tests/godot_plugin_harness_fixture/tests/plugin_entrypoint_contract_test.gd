extends RefCounted

const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const PluginRuntimeStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")

const RUNTIME_PROBE_PLUGIN_PATH := "res://tests/plugin_entrypoint_runtime_probe.gd"
const RUNTIME_BRIDGE_AUTOLOAD_NAME := "MCPRuntimeBridge"
const RUNTIME_BRIDGE_AUTOLOAD_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd"

var _probe_base_control: Control = null
var _probe_plugin = null
var _probe_entered := false



func run_case(tree: SceneTree) -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	MCPRuntimeDebugStore.clear()
	_seed_saved_settings({
		"auto_start": false,
		"debug_mode": false
	})
	ProjectSettings.set_setting("autoload/%s" % RUNTIME_BRIDGE_AUTOLOAD_NAME, "")

	_probe_base_control = Control.new()
	_probe_base_control.name = "EntrypointProbeRoot"
	tree.root.add_child(_probe_base_control)

	var probe_script = load(RUNTIME_PROBE_PLUGIN_PATH)
	if probe_script == null or not probe_script.has_method("new"):
		return _return_failure(tree, "plugin entrypoint runtime probe script should load in editor probe mode.")
	_probe_plugin = probe_script.new(_probe_base_control)
	_probe_plugin._enter_tree()
	_probe_entered = true
	for service_name in ["_state", "_settings_store", "_server_controller", "_tool_catalog", "_config_service", "_config_tab_action_service", "_dock_model_service", "_client_install_detection_service", "_user_tool_service", "_user_tool_watch_service"]:
		if _probe_plugin.get(service_name) == null:
			return _return_failure(tree, "plugin.gd should initialize required service %s during _enter_tree()." % service_name)
	_probe_plugin._save_settings()

	if _probe_plugin.autoload_install_calls.size() != 1:
		return _return_failure(tree, "plugin.gd should install the runtime bridge autoload during _enter_tree().")
	if str(ProjectSettings.get_setting("autoload/%s" % RUNTIME_BRIDGE_AUTOLOAD_NAME, "")) != RUNTIME_BRIDGE_AUTOLOAD_PATH:
		return _return_failure(tree, "runtime bridge autoload path should be registered during _enter_tree().")
	if _probe_plugin.debugger_add_calls.size() != 1:
		return _return_failure(tree, "plugin.gd should install the editor debugger bridge during _enter_tree().")
	if _probe_plugin.get_server() == null:
		return _return_failure(tree, "plugin.gd should attach a server controller during _enter_tree().")
	for method_name in ["runtime_restart_server", "runtime_soft_reload", "runtime_full_reload"]:
		if not _probe_plugin.has_method(method_name):
			return _return_failure(tree, "plugin.gd should expose %s as a stable runtime reload entrypoint." % method_name)
	if _probe_plugin.dock_add_calls.size() != 1:
		return _return_failure(tree, "plugin.gd should create and dock MCP during _enter_tree().")
	if _probe_plugin.base_control == null or _probe_plugin.base_control.get_child_count() != 1:
		return _return_failure(tree, "plugin.gd should add exactly one dock child to the editor base control.")

	var dock: Control = _probe_plugin.dock_add_calls[0].get("dock", null)
	if dock == null or not is_instance_valid(dock):
		return _return_failure(tree, "plugin.gd should create a valid dock instance.")
	var dock_script = dock.get_script()
	if dock_script == null or str(dock_script.resource_path) != "res://addons/godot_dotnet_mcp/ui/mcp_dock.gd":
		return _return_failure(tree, "plugin.gd should instantiate the production MCP scene.")
	if dock.get_parent() != _probe_base_control:
		return _return_failure(tree, "plugin.gd should parent MCP under the editor base control.")

	var bridge_status: Dictionary = MCPRuntimeDebugStore.get_bridge_status()
	if not bool(bridge_status.get("installed", false)):
		return _return_failure(tree, "runtime bridge status should report installed after _enter_tree().")
	if str(bridge_status.get("autoload_name", "")) != RUNTIME_BRIDGE_AUTOLOAD_NAME:
		return _return_failure(tree, "runtime bridge status should keep the configured autoload name.")
	var persisted_auto_start := bool(_probe_plugin._state.settings.get("auto_start", true))
	var persisted_debug_mode := bool(_probe_plugin._state.settings.get("debug_mode", true))
	if persisted_auto_start:
		return _return_failure(tree, "plugin.gd should preserve saved auto_start=false instead of forcing it back to true.")
	if persisted_debug_mode:
		return _return_failure(tree, "plugin.gd should preserve saved debug_mode=false instead of forcing it back to true.")
	if _probe_plugin._server_controller == null or bool(_probe_plugin._server_controller._running):
		return _return_failure(tree, "plugin.gd should not auto-start the server when saved auto_start=false is restored.")

	var runtime_full_reload: Dictionary = _probe_plugin.runtime_full_reload()
	if not bool(runtime_full_reload.get("success", false)) or not bool(runtime_full_reload.get("deferred", false)):
		return _return_failure(tree, "plugin.gd runtime_full_reload should report a deferred reload request.")
	if _probe_plugin.scheduled_runtime_reloads.size() != 1:
		return _return_failure(tree, "plugin.gd runtime_full_reload should schedule exactly one runtime reload callback.")
	var duplicate_runtime_full_reload: Dictionary = _probe_plugin.runtime_full_reload()
	if bool(duplicate_runtime_full_reload.get("success", true)) or str(duplicate_runtime_full_reload.get("error", "")).find("Runtime reload already scheduled") == -1:
		return _return_failure(tree, "plugin.gd runtime_full_reload should reject duplicate pending reload requests.")
	_probe_plugin._pending_runtime_reload_action = ""

	_probe_plugin._on_full_reload_requested()
	_probe_plugin._on_full_reload_requested()
	if _probe_plugin.plugin_reenable_schedule_count != 1:
		return _return_failure(tree, "plugin.gd should schedule only one full reload while a plugin re-enable is pending.")

	_probe_plugin._exit_tree()
	await tree.process_frame
	await tree.process_frame
	_probe_entered = false

	if _probe_plugin.autoload_remove_calls.size() != 1:
		return _return_failure(tree, "plugin.gd should remove the runtime bridge autoload during _exit_tree().")
	if _probe_plugin.debugger_remove_calls.size() != 1:
		return _return_failure(tree, "plugin.gd should remove the editor debugger bridge during _exit_tree().")
	if _probe_plugin.dock_remove_calls.size() != 1:
		return _return_failure(tree, "plugin.gd should detach the dock during _exit_tree().")
	if _probe_plugin.get_server() != null:
		return _return_failure(tree, "plugin.gd should dispose the server controller during _exit_tree().")
	if _probe_plugin.base_control != null and _probe_plugin.base_control.get_child_count() != 0:
		return _return_failure(tree, "plugin.gd should remove the dock from the editor base control during _exit_tree().")
	bridge_status = MCPRuntimeDebugStore.get_bridge_status()
	if bool(bridge_status.get("installed", true)):
		return _return_failure(tree, "runtime bridge status should report removed after _exit_tree().")
	if bool(is_instance_valid(dock)):
		return _return_failure(tree, "plugin.gd should queue-free the dock during _exit_tree().")

	var autoload_install_count: int = _probe_plugin.autoload_install_calls.size()
	var debugger_add_count: int = _probe_plugin.debugger_add_calls.size()
	var dock_add_count: int = _probe_plugin.dock_add_calls.size()
	var server_attached: bool = _probe_plugin.get_server() != null
	_teardown_probe(tree)

	return {
		"name": "plugin_entrypoint_contracts",
		"success": true,
		"error": "",
		"details": {
			"autoload_install_count": autoload_install_count,
			"debugger_add_count": debugger_add_count,
			"dock_add_count": dock_add_count,
			"server_attached": server_attached,
			"auto_start": persisted_auto_start,
			"debug_mode": persisted_debug_mode
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_teardown_probe(_tree)


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_entrypoint_contracts",
		"success": false,
		"error": message
	}


func _return_failure(tree: SceneTree, message: String) -> Dictionary:
	_teardown_probe(tree)
	return _failure(message)


func _teardown_probe(tree: SceneTree) -> void:
	if _probe_plugin != null and is_instance_valid(_probe_plugin) and _probe_entered:
		_probe_plugin._exit_tree()
		_probe_entered = false

	if _probe_base_control != null and is_instance_valid(_probe_base_control):
		if _probe_base_control.get_parent() != null:
			_probe_base_control.get_parent().remove_child(_probe_base_control)
		_probe_base_control.queue_free()

	if _probe_plugin != null and is_instance_valid(_probe_plugin):
		_probe_plugin.free()

	_probe_base_control = null
	_probe_plugin = null
	_probe_entered = false
	PluginSelfDiagnosticStore.clear()
	MCPRuntimeDebugStore.clear()
	ProjectSettings.set_setting("autoload/%s" % RUNTIME_BRIDGE_AUTOLOAD_NAME, "")
	_remove_saved_settings()


func _seed_saved_settings(overrides: Dictionary) -> void:
	var settings_path := PluginRuntimeStateScript.SETTINGS_PATH
	var settings_dir := settings_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(settings_dir))
	var settings := PluginRuntimeStateScript.build_default_settings()
	settings.merge(overrides, true)
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()


func _remove_saved_settings() -> void:
	var settings_path := ProjectSettings.globalize_path(PluginRuntimeStateScript.SETTINGS_PATH)
	if FileAccess.file_exists(PluginRuntimeStateScript.SETTINGS_PATH):
		DirAccess.remove_absolute(settings_path)
