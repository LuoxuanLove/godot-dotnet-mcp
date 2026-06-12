extends RefCounted

const PluginReloadCoordinatorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_reload_coordinator.gd")


class FakeEditorInterface extends RefCounted:
	var calls: Array[Dictionary] = []


	func set_plugin_enabled(plugin_id: String, enabled: bool) -> void:
		calls.append({"plugin_id": plugin_id, "enabled": enabled})


var _coordinator: Node = null
var _editor_interface := FakeEditorInterface.new()


func run_case(tree: SceneTree) -> Dictionary:
	_coordinator = PluginReloadCoordinatorScript.new()
	_coordinator.configure("godot_dotnet_mcp", _editor_interface)
	var source_guard_error := _assert_coordinator_is_lifecycle_only()
	if not source_guard_error.is_empty():
		return _failure(source_guard_error)
	tree.root.add_child(_coordinator)
	for _attempt in range(3):
		await tree.process_frame
		if _editor_interface.calls.size() > 0:
			break
	if _editor_interface.calls.size() != 1:
		return _failure("PluginReloadCoordinator should disable the plugin on the first process frame.")
	var disable_call: Dictionary = _editor_interface.calls[0]
	if str(disable_call.get("plugin_id", "")) != "godot_dotnet_mcp" or bool(disable_call.get("enabled", true)):
		return _failure("PluginReloadCoordinator should disable godot_dotnet_mcp before waiting to re-enable it.")

	await tree.process_frame
	if _editor_interface.calls.size() != 1:
		return _failure("PluginReloadCoordinator should not re-enable the plugin on the immediate next frame.")

	await tree.create_timer(0.35).timeout
	await tree.process_frame
	if _editor_interface.calls.size() != 2:
		return _failure("PluginReloadCoordinator should re-enable the plugin after the release delay.")
	var enable_call: Dictionary = _editor_interface.calls[1]
	if str(enable_call.get("plugin_id", "")) != "godot_dotnet_mcp" or not bool(enable_call.get("enabled", false)):
		return _failure("PluginReloadCoordinator should re-enable godot_dotnet_mcp after the delay.")
	if _coordinator != null and is_instance_valid(_coordinator):
		return _failure("PluginReloadCoordinator should queue-free itself after re-enabling the plugin.")

	return {
		"name": "plugin_reload_coordinator_contracts",
		"success": true,
		"error": "",
		"details": {
			"calls": _editor_interface.calls.duplicate(true)
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _coordinator != null and is_instance_valid(_coordinator):
		_coordinator.queue_free()
	_coordinator = null
	await tree.process_frame
	await tree.process_frame


func _assert_coordinator_is_lifecycle_only() -> String:
	var source_path := "res://addons/godot_dotnet_mcp/plugin/runtime/plugin_reload_coordinator.gd"
	if not FileAccess.file_exists(source_path):
		return "PluginReloadCoordinator source should exist for lifecycle-only source guards."
	var source := FileAccess.get_file_as_string(source_path)
	for forbidden in [
		"_server_controller",
		"func request_reload(",
		"func request_reload_by_script(",
		"func request_reload_all(",
		"reload_domain(",
		"reload_all_domains()"
	]:
		if source.find(forbidden) != -1:
			return "PluginReloadCoordinator should only coordinate plugin re-enable lifecycle, not runtime reload requests: %s" % forbidden
	return ""


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_reload_coordinator_contracts",
		"success": false,
		"error": message
	}
