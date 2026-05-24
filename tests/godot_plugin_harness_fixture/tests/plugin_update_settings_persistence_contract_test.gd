extends RefCounted

const PluginScript = preload("res://addons/godot_dotnet_mcp/plugin.gd")
const PluginRuntimeStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")

var _plugin = null


func run_case(_tree: SceneTree) -> Dictionary:
	_remove_saved_settings()
	_plugin = PluginScript.new()
	if _plugin == null:
		return _failure("plugin.gd should instantiate for update settings persistence contracts.")

	_plugin._on_update_source_changed("custom_branch")
	_plugin._on_update_custom_branch_changed("feature/persisted-settings")
	_plugin._on_update_release_tag_changed("v9.9.9")
	if str(_plugin._state.settings.get("update_source", "")) != "branch" or str(_plugin._state.settings.get("update_custom_branch", "")) != "feature/persisted-settings" or str(_plugin._state.settings.get("update_release_tag", "")) != "v9.9.9":
		return _failure("plugin.gd should store update setting changes in runtime settings.")

	var saved_settings := _load_saved_settings()
	if str(saved_settings.get("update_source", "")) != "branch" or str(saved_settings.get("update_custom_branch", "")) != "feature/persisted-settings" or str(saved_settings.get("update_release_tag", "")) != "v9.9.9":
		return _failure("plugin.gd should persist normalized update setting changes through _save_settings().")
	if saved_settings.has("update_ref_branches") or saved_settings.has("update_ref_releases") or saved_settings.has("update_refs_state"):
		return _failure("plugin.gd should not persist transient discovered update refs in settings.")
	return {"name": "plugin_update_settings_persistence_contracts", "success": true, "error": ""}


func cleanup_case(_tree: SceneTree) -> void:
	if _plugin != null and is_instance_valid(_plugin):
		_plugin.free()
	_plugin = null
	_remove_saved_settings()


func _load_saved_settings() -> Dictionary:
	var file := FileAccess.open(PluginRuntimeStateScript.SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}


func _remove_saved_settings() -> void:
	var settings_path := ProjectSettings.globalize_path(PluginRuntimeStateScript.SETTINGS_PATH)
	if FileAccess.file_exists(PluginRuntimeStateScript.SETTINGS_PATH):
		DirAccess.remove_absolute(settings_path)


func _failure(message: String) -> Dictionary:
	return {"name": "plugin_update_settings_persistence_contracts", "success": false, "error": message}
