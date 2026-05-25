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

	if PluginRuntimeStateScript.DEFAULT_SETTINGS.has("per" + "miss" + "ion" + "_level"):
		return _failure("PluginRuntimeState should not expose a legacy access level setting.")
	if PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES.is_empty():
		return _failure("PluginRuntimeState should expose builtin tool profiles.")
	if PluginRuntimeStateScript.TOOL_DOMAIN_DEFS.is_empty():
		return _failure("PluginRuntimeState should expose tool domain definitions.")
	for profile in PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES:
		if not (profile is Dictionary):
			continue
		var profile_id := str((profile as Dictionary).get("id", ""))
		if profile_id == "full":
			continue
		var enabled_categories: Array = (profile as Dictionary).get("enabled_categories", [])
		if not enabled_categories.has("runtime"):
			return _failure("Builtin tool profile '%s' should keep runtime atomic tools enabled for system runtime tree children." % profile_id)
	var expected_collapsed := [
		"system_bindings_audit",
		"system_editor_log",
		"system_editor_state",
		"system_help",
		"system_plugin_reload",
		"system_project_configure",
		"system_project_files",
		"system_project_index_build",
		"system_project_run",
		"system_project_state",
		"system_project_stop",
		"system_project_symbol_search",
		"system_runtime_control",
		"system_runtime_diagnose",
		"system_runtime_step",
		"system_scene_analyze",
		"system_scene_dependency_graph",
		"system_scene_patch",
		"system_scene_tree",
		"system_scene_validate",
		"system_script_analyze",
		"system_script_patch"
	]
	if JSON.stringify(PluginRuntimeStateScript.DEFAULT_COLLAPSED_SYSTEM_TOOLS) != JSON.stringify(expected_collapsed):
		return _failure("PluginRuntimeState should expose the current exact default collapsed system tool set.")
	if PluginRuntimeStateScript.DEFAULT_COLLAPSED_SYSTEM_TOOLS.has("system_project_advise"):
		return _failure("PluginRuntimeState should not keep deprecated system_project_advise in the default collapsed set.")
	if PluginRuntimeStateScript.TOOL_PROFILE_DIR.is_empty() or not PluginRuntimeStateScript.TOOL_PROFILE_DIR.begins_with("user://"):
		return _failure("PluginRuntimeState should expose the tool profile storage directory.")
	if PluginRuntimeStateScript.SETTINGS_PATH.is_empty() or not PluginRuntimeStateScript.SETTINGS_PATH.begins_with("user://"):
		return _failure("PluginRuntimeState should expose the settings storage path.")
	if PluginRuntimeStateScript.DEFAULT_SETTINGS.get("tool_profile_id", "") != "default":
		return _failure("PluginRuntimeState should expose default settings with the default profile id.")
	if not bool(PluginRuntimeStateScript.DEFAULT_SETTINGS.get("auto_start", false)):
		return _failure("PluginRuntimeState should keep auto_start enabled in default settings.")
	if not bool(PluginRuntimeStateScript.DEFAULT_SETTINGS.get("debug_mode", false)):
		return _failure("PluginRuntimeState should expose debug_mode in default settings.")
	if str(PluginRuntimeStateScript.DEFAULT_SETTINGS.get("update_source", "")) != "latest_stable":
		return _failure("PluginRuntimeState should default update scaffolding to the latest stable release source.")
	if str(PluginRuntimeStateScript.DEFAULT_SETTINGS.get("update_custom_branch", "")) != "dev":
		return _failure("PluginRuntimeState should default the custom update branch to dev without changing port/log/language defaults.")
	if str(PluginRuntimeStateScript.DEFAULT_SETTINGS.get("update_release_tag", "not-empty")) != "":
		return _failure("PluginRuntimeState should keep the release/tag update target empty by default.")
	if int(PluginRuntimeStateScript.DEFAULT_SETTINGS.get("port", 0)) != 3000 or str(PluginRuntimeStateScript.DEFAULT_SETTINGS.get("log_level", "")) != "info" or str(PluginRuntimeStateScript.DEFAULT_SETTINGS.get("language", "")) != "en":
		return _failure("PluginRuntimeState should not change existing port, log level, or language defaults.")
	if PluginRuntimeStateScript.DEFAULT_SETTINGS.has("update_ref_branches") or PluginRuntimeStateScript.DEFAULT_SETTINGS.has("update_ref_releases") or PluginRuntimeStateScript.DEFAULT_SETTINGS.has("update_refs_state") or PluginRuntimeStateScript.DEFAULT_SETTINGS.has("update_sync_state") or PluginRuntimeStateScript.DEFAULT_SETTINGS.has("update_compare_state"):
		return _failure("PluginRuntimeState should keep discovered update refs transient instead of persisting them in default settings.")
	if not state.update_ref_branches.is_empty() or not state.update_ref_releases.is_empty() or not state.update_ref_commits.is_empty() or not state.update_ref_latest_stable_release.is_empty() or not state.update_ref_latest_release.is_empty() or state.update_refs_state != "idle" or state.update_sync_state != "idle" or state.update_compare_state != "idle" or state.update_compare_ahead_by != -1 or state.update_compare_behind_by != -1:
		return _failure("PluginRuntimeState should expose an empty transient update ref discovery state.")

	return {
		"name": "plugin_runtime_state_contracts",
		"success": true,
		"error": "",
		"details": {
			"domain_count": PluginRuntimeStateScript.TOOL_DOMAIN_DEFS.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_runtime_state_contracts",
		"success": false,
		"error": message
	}
