extends RefCounted

# {"name": "plugin_client_config_state_service_contracts"}

const PluginClientConfigStateServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_client_config_state_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_client_config_state()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginClientConfigStateServiceScript.new()
	var detection_service = service.get_client_install_detection_service()
	if detection_service == null:
		return _failure("Client config state service should lazily create the install detection service.")
	if detection_service != service.get_client_install_detection_service():
		return _failure("Client config state service should reuse the install detection service instance.")

	var editor_interface = FakeEditorInterface.new()
	var selected := []
	var dialog = service.configure_client_executable_dialog(editor_interface, Callable(self, "_on_file_selected").bind(selected))
	if dialog == null or not is_instance_valid(dialog):
		return _failure("Client config state service should create the executable picker dialog.")
	if dialog.name != "ClientExecutableDialog" or editor_interface.base_control.get_child_count() != 1:
		return _failure("Client config state service should parent the executable picker dialog to the editor base control.")
	if dialog != service.configure_client_executable_dialog(editor_interface, Callable(self, "_on_file_selected").bind(selected)):
		return _failure("Client config state service should reuse an existing executable picker dialog.")
	if not dialog.file_selected.is_connected(Callable(self, "_on_file_selected").bind(selected)):
		return _failure("Client config state service should connect the selected-file callback.")

	service.remove_client_executable_dialog()
	if service.get_client_executable_dialog() != null:
		return _failure("Client config state service should clear the executable picker dialog on removal.")
	if dialog.is_inside_tree():
		return _failure("Client config state service should detach the executable picker dialog on removal.")

	service.dispose()
	editor_interface.base_control.free()
	return {"name": "plugin_client_config_state_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_client_config_state() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_client_config_state_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin client config state sources should be readable."
	for required in [
		"PluginClientConfigStateServiceScript.new()",
		"_ensure_plugin_client_config_state_service().get_client_install_statuses(",
		"_ensure_plugin_client_config_state_service().configure_client_executable_dialog(",
		"_ensure_plugin_client_config_state_service().remove_client_executable_dialog()",
		"_ensure_plugin_client_config_state_service().get_client_executable_dialog()"
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate client config state responsibility: %s" % required
	for forbidden in [
		"ClientInstallDetectionServiceScript.new()",
		"FileDialog.new()",
		"var _client_executable_dialog",
		"_pending_client_path_request"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain client config state internals: %s" % forbidden
	for required_service in [
		"func get_client_install_statuses(settings: Dictionary)",
		"func invalidate_client_install_status_cache()",
		"func configure_client_executable_dialog(editor_interface, on_file_selected: Callable)",
		"func remove_client_executable_dialog()",
		"func get_client_executable_dialog()"
	]:
		if service_source.find(required_service) == -1:
			return "PluginClientConfigStateService should own client config method: %s" % required_service
	return ""


func _on_file_selected(path: String, selected: Array) -> void:
	selected.append(path)


class FakeEditorInterface:
	var base_control := Control.new()

	func get_base_control():
		return base_control


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_client_config_state_service_contracts", "success": false, "error": message, "details": details}
