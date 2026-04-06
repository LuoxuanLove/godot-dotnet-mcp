extends RefCounted

const PluginRuntimeStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")


class FakeLocalization extends RefCounted:
	func get_language() -> String:
		return "ja"


func run_case(_tree: SceneTree) -> Dictionary:
	var state = PluginRuntimeStateScript.new()
	state.settings = {"language": "zh_CN"}

	if state.resolve_active_language(FakeLocalization.new()) != "zh_CN":
		return _failure("PluginRuntimeState should prefer the configured language setting.")

	state.settings = {}
	if state.resolve_active_language(FakeLocalization.new()) != "ja":
		return _failure("PluginRuntimeState should fall back to localization language.")

	if PluginRuntimeStateScript.PERMISSION_LEVELS.size() != 3:
		return _failure("PluginRuntimeState should expose the three permission levels.")
	if PluginRuntimeStateScript.normalize_permission_level("bogus") != PluginRuntimeStateScript.PERMISSION_EVOLUTION:
		return _failure("PluginRuntimeState should normalize invalid permission levels to evolution.")
	if not PluginRuntimeStateScript.permission_allows_domain(PluginRuntimeStateScript.PERMISSION_DEVELOPER, "plugin"):
		return _failure("PluginRuntimeState should allow developer access to the plugin domain.")
	if PluginRuntimeStateScript.extract_category_from_tool_name("plugin_runtime_list_profiles") != "plugin_runtime":
		return _failure("PluginRuntimeState should extract plugin categories from tool names.")
	if PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES.is_empty():
		return _failure("PluginRuntimeState should expose builtin tool profiles.")
	if PluginRuntimeStateScript.TOOL_DOMAIN_DEFS.is_empty():
		return _failure("PluginRuntimeState should expose tool domain definitions.")
	if PluginRuntimeStateScript.DEFAULT_COLLAPSED_SYSTEM_TOOLS.is_empty():
		return _failure("PluginRuntimeState should expose default collapsed system tools.")
	if PluginRuntimeStateScript.TOOL_PROFILE_DIR.is_empty() or not PluginRuntimeStateScript.TOOL_PROFILE_DIR.begins_with("user://"):
		return _failure("PluginRuntimeState should expose the tool profile storage directory.")
	if PluginRuntimeStateScript.SETTINGS_PATH.is_empty() or not PluginRuntimeStateScript.SETTINGS_PATH.begins_with("user://"):
		return _failure("PluginRuntimeState should expose the settings storage path.")
	if PluginRuntimeStateScript.DEFAULT_SETTINGS.get("tool_profile_id", "") != "default":
		return _failure("PluginRuntimeState should expose default settings with the default profile id.")

	return {
		"name": "plugin_runtime_state_contracts",
		"success": true,
		"error": "",
		"details": {
			"permission_levels": PluginRuntimeStateScript.PERMISSION_LEVELS.size(),
			"domain_count": PluginRuntimeStateScript.TOOL_DOMAIN_DEFS.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_runtime_state_contracts",
		"success": false,
		"error": message
	}
