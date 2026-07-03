extends RefCounted

# {"name": "plugin_profile_config_service_contracts"}

const PluginProfileConfigServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_profile_config_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_profile_config()
	if not source_guard.is_empty():
		return _failure(source_guard)
	var settings_store_guard := _verify_settings_store_atomic_writes()
	if not settings_store_guard.is_empty():
		return _failure(settings_store_guard)

	var service = PluginProfileConfigServiceScript.new()
	var state = FakeState.new()
	var settings_store = FakeSettingsStore.new()
	var tool_catalog = FakeToolCatalog.new()
	var server_controller = FakeServerController.new()
	var localization = FakeLocalization.new()
	var context := {
		"state": state,
		"settings_store": settings_store,
		"tool_catalog": tool_catalog,
		"server_controller": server_controller,
		"localization": localization,
		"settings_path": "user://settings.json",
		"profile_dir": "user://profiles",
		"builtin_profiles": [{"id": "default"}, {"id": "full"}]
	}

	var apply_result := service.apply_tool_profile(context, "full")
	if not bool(apply_result.get("success", false)):
		return _failure("PluginProfileConfigService should apply builtin profiles.")
	if str(state.settings.get("tool_profile_id", "")) != "full":
		return _failure("PluginProfileConfigService should update active profile id.")
	if not (state.settings.get("disabled_tools", []) as Array).has("tool_two"):
		return _failure("PluginProfileConfigService should apply disabled tools from catalog.")
	if server_controller.disabled_tools.size() != 1 or settings_store.save_count <= 0:
		return _failure("PluginProfileConfigService should update server disabled tools and save settings.")

	var empty_save := service.save_custom_profile(context, "")
	if bool(empty_save.get("success", true)) or str(empty_save.get("error", "")) != "Name required":
		return _failure("PluginProfileConfigService should localize empty custom profile names.")
	var save_result := service.save_custom_profile(context, "QA Profile")
	if not bool(save_result.get("success", false)) or str(save_result.get("profile_id", "")) != "custom:qa-profile":
		return _failure("PluginProfileConfigService should save custom profiles and activate the new id.", save_result)
	if not state.custom_tool_profiles.has("custom:qa-profile"):
		return _failure("PluginProfileConfigService should reload custom profiles after save.")

	var rename_builtin := service.rename_custom_profile(context, "default", "Nope")
	if bool(rename_builtin.get("success", true)) or str(rename_builtin.get("error", "")) != "Builtin protected":
		return _failure("PluginProfileConfigService should protect builtin profile rename.")
	var rename_result := service.rename_custom_profile(context, "custom:qa-profile", "Renamed")
	if not bool(rename_result.get("success", false)) or str(rename_result.get("profile_id", "")) != "custom:renamed":
		return _failure("PluginProfileConfigService should rename custom profiles.", rename_result)

	state.settings["tool_profile_id"] = "custom:renamed"
	var delete_result := service.delete_custom_profile(context, "custom:renamed")
	if not bool(delete_result.get("success", false)) or str(delete_result.get("profile_id", "")) != "default":
		return _failure("PluginProfileConfigService should reset deleted active custom profiles to default.", delete_result)

	state.settings["tool_profile_id"] = "full"
	state.settings["disabled_tools"] = ["tool_two"]
	var export_result := service.export_config(context, "user://export.json")
	if not bool(export_result.get("success", false)):
		return _failure("PluginProfileConfigService should export tool config.", export_result)
	if int((export_result.get("data", {}) as Dictionary).get("disabled_tool_count", 0)) != 1:
		return _failure("PluginProfileConfigService should include disabled tool count in export response.")

	settings_store.import_payload = {"profile_id": "missing", "disabled_tools": ["tool_one", "ghost_tool"]}
	var import_result := service.import_config(context, "user://import.json")
	if not bool(import_result.get("success", false)):
		return _failure("PluginProfileConfigService should import tool config.", import_result)
	var import_data := import_result.get("data", {}) as Dictionary
	if str(import_data.get("resolved_profile_id", "")) != "default":
		return _failure("PluginProfileConfigService should fall back to a matching/default profile for missing imported profile ids.", import_data)
	if (import_data.get("ignored_tools", []) as Array) != ["ghost_tool"]:
		return _failure("PluginProfileConfigService should report ignored imported tools.", import_data)
	if (state.settings.get("disabled_tools", []) as Array) != ["tool_one"]:
		return _failure("PluginProfileConfigService should keep only valid imported disabled tools.")

	return {"name": "plugin_profile_config_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_profile_config() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_profile_config_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin profile config sources should be readable."
	for required in [
		"PluginProfileConfigServiceScript.new()",
		"_ensure_plugin_profile_config_service().apply_tool_profile(",
		"_ensure_plugin_profile_config_service().save_custom_profile(",
		"_ensure_plugin_profile_config_service().rename_custom_profile(",
		"_ensure_plugin_profile_config_service().delete_custom_profile(",
		"_ensure_plugin_profile_config_service().export_config(",
		"_ensure_plugin_profile_config_service().import_config("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate profile/config responsibility: %s" % required
	for forbidden in [
		"_settings_store.save_custom_profile(",
		"_settings_store.rename_custom_profile(",
		"_settings_store.delete_custom_profile(",
		"_settings_store.export_tool_config(",
		"_settings_store.import_tool_config(file_path)",
		"_tool_catalog.find_matching_profile_id("
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain profile/config internals: %s" % forbidden
	for required_service in [
		"func apply_tool_profile(context: Dictionary, profile_id: String)",
		"func save_custom_profile(context: Dictionary, profile_name: String)",
		"func rename_custom_profile(context: Dictionary, profile_id: String, profile_name: String)",
		"func delete_custom_profile(context: Dictionary, profile_id: String)",
		"func export_config(context: Dictionary, file_path: String)",
		"func import_config(context: Dictionary, file_path: String)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginProfileConfigService should own profile/config method: %s" % required_service
	return ""


func _verify_settings_store_atomic_writes() -> String:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
	if source.is_empty():
		return "SettingsStore source should be readable."
	for required in [
		"func _write_json_file_atomically(",
		"FileWriteTransaction.write_text_atomically(",
		"Failed to persist plugin settings"
	]:
		if source.find(required) == -1:
			return "SettingsStore should persist settings/profile/export JSON with verified atomic writes: %s" % required
	var transaction_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/config/file_write_transaction.gd")
	if transaction_source.is_empty():
		return "FileWriteTransaction source should be readable."
	for required_transaction in [
		"static func write_text_atomically(",
		"static func build_sidecar_path(",
		"DirAccess.rename_absolute",
		"write_verify_failed",
		"backup_failed",
		"replace_failed",
		"return sidecar_name"
	]:
		if transaction_source.find(required_transaction) == -1:
			return "FileWriteTransaction should centralize settings/fallback atomic write behavior: %s" % required_transaction
	for forbidden in [
		"func save_plugin_settings(settings_path: String, settings: Dictionary) -> void:\n\tvar settings_dir := settings_path.get_base_dir()\n\tDirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(settings_dir))\n\tvar file = FileAccess.open(settings_path, FileAccess.WRITE)",
		"func export_tool_config(file_path: String, profile_id: String, disabled_tools: Array) -> Dictionary:"
	]:
		if forbidden.begins_with("func export_tool_config"):
			continue
		if source.find(forbidden) != -1:
			return "SettingsStore should not use direct FileAccess.WRITE for plugin settings."
	return ""


class FakeState:
	var settings := {
		"tool_profile_id": "default",
		"disabled_tools": []
	}
	var custom_tool_profiles := {}


class FakeSettingsStore:
	var save_count := 0
	var custom_profiles := {}
	var import_payload := {}

	func save_plugin_settings(_settings_path: String, _settings: Dictionary) -> void:
		save_count += 1

	func save_custom_profile(_profile_dir: String, profile_name: String, disabled_tools: Array) -> Dictionary:
		custom_profiles["custom:qa-profile"] = {"name": profile_name, "disabled_tools": disabled_tools.duplicate()}
		return {"success": true, "slug": "qa-profile"}

	func load_custom_profiles(_profile_dir: String) -> Dictionary:
		return custom_profiles.duplicate(true)

	func rename_custom_profile(_profile_dir: String, profile_id: String, profile_name: String) -> Dictionary:
		if not custom_profiles.has(profile_id):
			return {"success": false, "error_code": "profile_not_found"}
		custom_profiles.erase(profile_id)
		custom_profiles["custom:renamed"] = {"name": profile_name, "disabled_tools": []}
		return {"success": true, "profile_id": "custom:renamed", "profile_name": profile_name}

	func delete_custom_profile(_profile_dir: String, profile_id: String) -> Dictionary:
		if not custom_profiles.has(profile_id):
			return {"success": false, "error_code": "profile_not_found"}
		custom_profiles.erase(profile_id)
		return {"success": true}

	func export_tool_config(file_path: String, profile_id: String, disabled_tools: Array) -> Dictionary:
		return {"success": true, "file_path": file_path, "profile_id": profile_id, "disabled_tools": disabled_tools.duplicate()}

	func import_tool_config(file_path: String) -> Dictionary:
		if import_payload.is_empty():
			return {"success": false, "error_code": "config_parse_failed"}
		return {"success": true, "file_path": file_path, "data": import_payload.duplicate(true)}


class FakeToolCatalog:
	func build_tool_name_index(_tools_by_category: Dictionary) -> Array:
		return ["tool_one", "tool_two"]

	func get_disabled_tools_for_profile(profile_id: String, _builtin_profiles: Array, _custom_profiles: Dictionary, _tool_names: Array, current_disabled: Array) -> Array:
		if profile_id == "full":
			return ["tool_two"]
		if profile_id == "default":
			return []
		return current_disabled.duplicate()

	func has_tool_profile(profile_id: String, _builtin_profiles: Array, custom_profiles: Dictionary) -> bool:
		return profile_id in ["default", "full"] or custom_profiles.has(profile_id)

	func find_matching_profile_id(disabled_tools: Array, _builtin_profiles: Array, _custom_profiles: Dictionary, _tool_names: Array) -> String:
		if disabled_tools.is_empty():
			return "default"
		return ""


class FakeServerController:
	var disabled_tools := []

	func get_all_tools_by_category() -> Dictionary:
		return {"system": [{"name": "tool_one"}, {"name": "tool_two"}]}

	func set_disabled_tools(tools: Array) -> void:
		disabled_tools = tools.duplicate()


class FakeLocalization:
	var texts := {
		"tool_profile_name_required": "Name required",
		"tool_profile_save_failed": "Save failed",
		"tool_profile_saved": "Saved %s",
		"tool_profile_builtin_protected": "Builtin protected",
		"tool_profile_renamed": "Renamed %s",
		"tool_profile_deleted": "Deleted",
		"tool_profile_name_conflict": "Name conflict",
		"tool_profile_not_found": "Profile not found",
		"tool_profile_rename_failed": "Rename failed",
		"tool_profile_delete_failed": "Delete failed",
		"tool_config_path_required": "Path required",
		"tool_config_not_found": "Config not found",
		"tool_config_validation_failed": "Validation failed",
		"tool_config_write_failed": "Write failed",
		"tool_config_exported": "Exported",
		"tool_config_imported": "Imported"
	}

	func get_text(key: String) -> String:
		return str(texts.get(key, key))


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_profile_config_service_contracts", "success": false, "error": message, "details": details}
