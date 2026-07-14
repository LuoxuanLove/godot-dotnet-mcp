extends RefCounted

# {"name": "plugin_developer_settings_service_contracts"}

const PluginDeveloperSettingsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_developer_settings_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_developer_settings()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginDeveloperSettingsServiceScript.new()
	var state = FakeState.new()
	var localization = FakeLocalization.new()
	var settings := service.build_settings_response({"state": state, "localization": localization, "log_level": "debug"})
	if not bool(settings.get("success", false)):
		return _failure("PluginDeveloperSettingsService settings response should succeed.")
	var data := settings.get("data", {}) as Dictionary
	if str(data.get("log_level", "")) != "debug" or str(data.get("resolved_language", "")) != "zh-CN":
		return _failure("PluginDeveloperSettingsService settings response should preserve log level and resolved language.", data)
	if str(data.get("tool_profile_id", "")) != "custom:test":
		return _failure("PluginDeveloperSettingsService settings response should preserve tool profile id.")

	var empty_language := service.validate_language(localization, "")
	if bool(empty_language.get("success", true)) or str(empty_language.get("error", "")) != "Language code is required":
		return _failure("PluginDeveloperSettingsService should reject empty language codes.")
	var unknown_language := service.validate_language(localization, "fr")
	if bool(unknown_language.get("success", true)) or str(unknown_language.get("error", "")).find("Unsupported language") == -1:
		return _failure("PluginDeveloperSettingsService should reject unsupported language codes.")
	if not bool(service.validate_language(localization, "en").get("success", false)):
		return _failure("PluginDeveloperSettingsService should accept supported language codes.")

	state.settings["language"] = "en"
	var language_set := service.build_language_set_response(state, localization)
	if str(language_set.get("language", "")) != "en":
		return _failure("PluginDeveloperSettingsService language set response should use resolved state language.", language_set)
	var languages := service.build_languages_response(state, localization)
	var language_rows: Array = (languages.get("data", {}) as Dictionary).get("languages", [])
	if language_rows.size() != 2 or str((language_rows[0] as Dictionary).get("name", "")) == "":
		return _failure("PluginDeveloperSettingsService languages response should include display names.", languages)

	var profiles := service.build_profiles_response(state, [{"id": "default"}])
	if not ((profiles.get("data", {}) as Dictionary).get("custom_profiles", {}) is Dictionary):
		return _failure("PluginDeveloperSettingsService profiles response should include custom profiles.")

	return {"name": "plugin_developer_settings_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_developer_settings() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_developer_settings_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin developer settings sources should be readable."
	for required in [
		"PluginDeveloperSettingsServiceScript.new()",
		"_ensure_plugin_developer_settings_service().build_settings_response(",
		"_ensure_plugin_developer_settings_service().validate_language(",
		"_ensure_plugin_developer_settings_service().build_language_set_response(",
		"_ensure_plugin_developer_settings_service().build_languages_response(",
		"_ensure_plugin_developer_settings_service().build_profiles_response("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate developer settings responsibility: %s" % required
	for forbidden in [
		"\"resolved_language\": _state.resolve_active_language(_localization)",
		"_localization.get_available_languages().has(language_code)",
		"_localization.get_available_language_codes()"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain developer settings internals: %s" % forbidden
	for required_service in [
		"func build_settings_response(context: Dictionary)",
		"func validate_language(localization, language_code: String)",
		"func build_language_set_response(state, localization)",
		"func build_languages_response(state, localization)",
		"func build_profiles_response(state, builtin_profiles: Array)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginDeveloperSettingsService should own developer settings method: %s" % required_service
	return ""


class FakeState:
	var settings := {
		"language": "zh-CN",
		"tool_profile_id": "custom:test"
	}
	var custom_tool_profiles := {"custom:test": {"name": "Test"}}

	func resolve_active_language(_localization) -> String:
		return str(settings.get("language", "en"))


class FakeLocalization:
	var languages := {"en": true, "zh-CN": true}

	func get_available_languages() -> Dictionary:
		return languages.duplicate()

	func get_available_language_codes() -> Array:
		return ["en", "zh-CN"]

	func get_language_display_name(code: String, active_language: String) -> String:
		return "%s/%s" % [code, active_language]


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_developer_settings_service_contracts", "success": false, "error": message, "details": details}
