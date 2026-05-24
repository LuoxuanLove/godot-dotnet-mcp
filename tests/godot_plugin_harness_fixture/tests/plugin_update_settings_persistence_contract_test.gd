extends RefCounted

const PluginScript = preload("res://addons/godot_dotnet_mcp/plugin.gd")
const PluginRuntimeStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const SettingsStoreScript = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")

var _plugin = null


class FocusRestoreProbePlugin extends PluginScript:
	var discovery_request_count := 0
	var request_parent := Node.new()

	func _ensure_update_refs_discovery_requested() -> bool:
		discovery_request_count += 1
		return true

	func _get_update_request_parent() -> Node:
		return request_parent


class RequestParentProbePlugin extends PluginScript:
	var update_check_count := 0

	func _on_update_check_requested() -> void:
		update_check_count += 1


class CurrentTabProbeDock extends Control:
	var current_tab := 3
	var apply_model_count := 0

	func get_current_tab() -> int:
		return current_tab

	func apply_model(_model: Dictionary) -> void:
		apply_model_count += 1


func run_case(_tree: SceneTree) -> Dictionary:
	_remove_saved_settings()
	var settings_store = SettingsStoreScript.new()
	if settings_store._normalize_update_source("latest_dev") != "custom_branch" or settings_store._normalize_update_source("branch") != "custom_branch":
		return _failure("settings_store.gd should preserve legacy dev-tracking update sources as custom_branch.")
	_plugin = PluginScript.new()
	if _plugin == null:
		return _failure("plugin.gd should instantiate for update settings persistence contracts.")

	_plugin._on_update_source_changed("custom_branch")
	_plugin._on_update_custom_branch_changed("feature/persisted-settings")
	_plugin._on_update_release_tag_changed("v9.9.9")
	if str(_plugin._state.settings.get("update_source", "")) != "custom_branch" or str(_plugin._state.settings.get("update_custom_branch", "")) != "feature/persisted-settings" or str(_plugin._state.settings.get("update_release_tag", "")) != "v9.9.9":
		return _failure("plugin.gd should store update setting changes in runtime settings.")

	var saved_settings := _load_saved_settings()
	if str(saved_settings.get("update_source", "")) != "custom_branch" or str(saved_settings.get("update_custom_branch", "")) != "feature/persisted-settings" or str(saved_settings.get("update_release_tag", "")) != "v9.9.9":
		return _failure("plugin.gd should persist normalized update setting changes through _save_settings().")
	if saved_settings.has("update_ref_branches") or saved_settings.has("update_ref_releases") or saved_settings.has("update_refs_state"):
		return _failure("plugin.gd should not persist transient discovered update refs in settings.")

	var target_probe := PluginScript.new()
	target_probe._state.settings["update_custom_branch"] = "feature/target"
	target_probe._state.settings["update_release_tag"] = "01"
	target_probe._state.update_ref_latest_stable_release = "v1.0.0"
	target_probe._state.update_ref_latest_release = "v1.1.0-beta.1"
	target_probe._state.update_ref_commits = {
		"dev": "dev-commit",
		"feature/target": "branch-commit",
		"v1.0.0": "stable-commit",
		"v1.1.0-beta.1": "release-commit",
		"01": "tag-commit"
	}
	var sync_cases := [
		{"source": "custom_branch", "kind": "branch", "ref": "feature/target", "commit": "branch-commit"},
		{"source": "latest_stable", "kind": "tag", "ref": "v1.0.0", "commit": "stable-commit"},
		{"source": "latest_release", "kind": "tag", "ref": "v1.1.0-beta.1", "commit": "release-commit"},
		{"source": "release_tag", "kind": "tag", "ref": "v1.1.0-beta.1", "commit": "release-commit"},
		{"source": "branch", "kind": "branch", "ref": "feature/target", "commit": "branch-commit"},
		{"source": "latest_dev", "kind": "branch", "ref": "feature/target", "commit": "branch-commit"}
	]
	for sync_case in sync_cases:
		target_probe._state.settings["update_source"] = str(sync_case.get("source", ""))
		var target: Dictionary = target_probe._resolve_update_sync_target()
		if str(target.get("kind", "")) != str(sync_case.get("kind", "")) or str(target.get("ref", "")) != str(sync_case.get("ref", "")) or str(target.get("commit", "")) != str(sync_case.get("commit", "")):
			target_probe.free()
			return _failure("plugin.gd should resolve update sync target for source %s." % str(sync_case.get("source", "")))
	target_probe._state.settings["update_source"] = "custom_branch"
	target_probe._state.settings["update_custom_branch"] = ""
	var empty_branch_target: Dictionary = target_probe._resolve_update_sync_target()
	if str(empty_branch_target.get("kind", "")) != "branch" or str(empty_branch_target.get("ref", "")) != "dev" or str(empty_branch_target.get("commit", "")) != "dev-commit":
		target_probe.free()
		return _failure("plugin.gd should fallback empty custom branch sync targets to dev.")
	target_probe._state.settings["update_source"] = "latest_release"
	target_probe._state.settings["update_release_tag"] = "01"
	target_probe._state.update_ref_latest_release = ""
	if not str(target_probe._resolve_update_sync_target().get("ref", "")).is_empty():
		target_probe.free()
		return _failure("plugin.gd should not treat a saved explicit release/tag value as the latest release target.")
	target_probe.free()

	var focus_restore_probe := FocusRestoreProbePlugin.new()
	focus_restore_probe._state.current_tab = 0
	focus_restore_probe._state.settings["_pending_focus_snapshot"] = {"tab_index": 3, "focus_path": ""}
	focus_restore_probe._restore_pending_focus_snapshot_if_needed()
	if focus_restore_probe._state.current_tab != 3 or focus_restore_probe.discovery_request_count != 1 or focus_restore_probe._state.settings.has("_pending_focus_snapshot"):
		focus_restore_probe.free()
		return _failure("plugin.gd should restore the Settings tab index and request update refs after restoring Dock focus.")
	focus_restore_probe._state.settings["update_source"] = "release_tag"
	var focus_request_parent := focus_restore_probe.request_parent
	_tree.root.add_child(focus_request_parent)
	focus_restore_probe._ensure_saved_update_source_discovery_requested()
	if focus_restore_probe.discovery_request_count != 2:
		focus_request_parent.queue_free()
		focus_restore_probe.free()
		return _failure("plugin.gd should request update refs on startup when the saved update source needs release/tag discovery.")
	focus_request_parent.queue_free()
	focus_restore_probe.free()

	var saved_source_probe := FocusRestoreProbePlugin.new()
	var saved_source_dock := CurrentTabProbeDock.new()
	saved_source_dock.current_tab = 0
	saved_source_probe._dock = saved_source_dock
	saved_source_probe._state.settings["update_source"] = "release_tag"
	saved_source_probe._refresh_dock()
	if saved_source_probe.discovery_request_count != 1 or saved_source_dock.apply_model_count != 0:
		saved_source_probe.free()
		saved_source_dock.free()
		return _failure("plugin.gd should auto-discover update refs during Dock refresh when the saved update source needs release/tag discovery.")
	saved_source_probe.free()
	saved_source_dock.free()

	var current_tab_probe := FocusRestoreProbePlugin.new()
	var probe_dock := CurrentTabProbeDock.new()
	current_tab_probe._dock = probe_dock
	current_tab_probe._state.current_tab = 0
	current_tab_probe._refresh_dock()
	if current_tab_probe._state.current_tab != 3 or current_tab_probe.discovery_request_count != 1 or probe_dock.apply_model_count != 0:
		current_tab_probe.free()
		probe_dock.free()
		return _failure("plugin.gd should sync the visible Dock tab before building the model and auto-discover refs on Settings.")
	current_tab_probe.free()
	probe_dock.free()

	var request_parent_probe := RequestParentProbePlugin.new()
	var request_parent_dock := Control.new()
	_tree.root.add_child(request_parent_dock)
	request_parent_probe._dock = request_parent_dock
	if not request_parent_probe._ensure_update_refs_discovery_requested() or request_parent_probe.update_check_count != 1:
		request_parent_probe.free()
		request_parent_dock.queue_free()
		return _failure("plugin.gd should use an active Dock request host when auto-discovering update refs.")
	request_parent_probe.free()
	request_parent_dock.queue_free()

	var pending_retry_probe := RequestParentProbePlugin.new()
	var pending_retry_dock := CurrentTabProbeDock.new()
	pending_retry_probe._dock = pending_retry_dock
	pending_retry_probe._state.settings["update_source"] = "release_tag"
	if pending_retry_probe._ensure_saved_update_source_discovery_requested() or pending_retry_probe.update_check_count != 0 or not pending_retry_probe._update_refs_discovery_retry_pending:
		pending_retry_probe.free()
		pending_retry_dock.free()
		return _failure("plugin.gd should mark saved update refs discovery pending when the Dock is not in the tree yet.")
	_tree.root.add_child(pending_retry_dock)
	pending_retry_probe._refresh_dock()
	if pending_retry_probe.update_check_count != 1 or pending_retry_probe._update_refs_discovery_retry_pending or pending_retry_dock.apply_model_count != 0:
		pending_retry_probe.free()
		pending_retry_dock.queue_free()
		return _failure("plugin.gd should retry pending saved-source update refs discovery after the Dock enters the tree.")
	pending_retry_probe.free()
	pending_retry_dock.queue_free()
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
