@tool
extends RefCounted
class_name PluginRuntimeStateService

const ToolProfileCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_profile_catalog.gd")
const PluginSettingsSchema = preload("res://addons/godot_dotnet_mcp/plugin/config/plugin_settings_schema.gd")

var _settings_store


func configure(settings_store) -> void:
	_settings_store = settings_store


func load_into(state) -> Dictionary:
	if _settings_store == null or state == null:
		return {"success": false, "error": "Runtime state service is unavailable"}

	var load_result = _settings_store.load_plugin_settings(
		PluginSettingsSchema.build_default_settings(),
		PluginSettingsSchema.SETTINGS_PATH,
		PluginSettingsSchema.ALL_TOOL_CATEGORIES,
		PluginSettingsSchema.DEFAULT_COLLAPSED_DOMAINS
	)
	var settings = load_result.get("settings", PluginSettingsSchema.build_default_settings())
	if not (settings is Dictionary):
		settings = PluginSettingsSchema.build_default_settings()

	state.settings = settings
	state.settings["auto_start"] = true
	if not (state.settings.get("client_manual_paths", {}) is Dictionary):
		state.settings["client_manual_paths"] = {}
	state.current_cli_scope = str(state.settings.get("current_cli_scope", state.current_cli_scope))
	state.current_config_platform = str(state.settings.get("current_config_platform", state.current_config_platform))
	state.needs_initial_tool_profile_apply = not bool(load_result.get("has_settings_file", false))
	state.custom_tool_profiles = _settings_store.load_custom_profiles(ToolProfileCatalog.PROFILE_STORAGE_DIR)
	return {
		"success": true,
		"has_settings_file": bool(load_result.get("has_settings_file", false)),
		"custom_profile_count": state.custom_tool_profiles.size()
	}


func save_settings(state) -> void:
	if _settings_store == null or state == null:
		return
	_settings_store.save_plugin_settings(PluginSettingsSchema.SETTINGS_PATH, state.settings)
