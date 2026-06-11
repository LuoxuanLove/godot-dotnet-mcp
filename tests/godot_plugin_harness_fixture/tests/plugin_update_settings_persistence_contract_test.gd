extends RefCounted

const PluginScript = preload("res://addons/godot_dotnet_mcp/plugin.gd")
const PluginRuntimeStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const SettingsStoreScript = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")

var _plugin = null


class FocusRestoreProbePlugin extends PluginScript:
	var discovery_request_count := 0
	var request_parent := Node.new()

	func _ensure_update_refs_discovery_requested(_force_refresh: bool = false) -> bool:
		discovery_request_count += 1
		return true

	func _get_update_request_parent() -> Node:
		return request_parent


class RefreshProbePlugin extends PluginScript:
	var discovery_request_count := 0
	var compare_requests: Array = []
	var request_parent := Node.new()

	func _get_update_request_parent() -> Node:
		return request_parent

	func _on_update_check_requested() -> void:
		discovery_request_count += 1

	func _resolve_current_update_commit() -> String:
		return "current-sync-sha"

	func _start_update_compare_request(base_commit: String, compare_head: String, target_commit: String = "") -> void:
		compare_requests.append({"base": base_commit, "head": compare_head, "target_commit": target_commit})


class RequestParentProbePlugin extends PluginScript:
	var update_check_count := 0

	func _on_update_check_requested() -> void:
		update_check_count += 1


class SyncReloadProbePlugin extends PluginScript:
	var sync_result := {"success": true, "written": 3}
	var marker_error := OK
	var reload_requests: Array[String] = []
	var editor_refresh_count := 0
	var editor_refresh_state := ""
	var editor_refresh_status := ""
	var editor_refresh_result := {"success": true, "scan_requested": true}
	var sync_events: Array[String] = []
	var compare_refresh_count := 0
	var dock_refresh_count := 0

	func _sync_update_archive_to_addon(_archive_path: String) -> Dictionary:
		return sync_result.duplicate(true)

	func _write_update_sync_marker(_target: Dictionary, _written: int) -> int:
		return marker_error

	func _refresh_update_compare_for_current_target() -> void:
		compare_refresh_count += 1

	func _refresh_dock() -> void:
		dock_refresh_count += 1

	func _request_update_sync_editor_refresh(_serial: int) -> Dictionary:
		editor_refresh_count += 1
		editor_refresh_state = str(_state.update_sync_state)
		editor_refresh_status = str(_state.update_sync_status)
		sync_events.append("editor_refresh")
		return editor_refresh_result.duplicate(true)

	func _request_plugin_lifecycle_reload(source: String = "unknown") -> Dictionary:
		reload_requests.append(source)
		sync_events.append("lifecycle_reload")
		return {"success": true, "deferred": true, "data": {"source": source}}


class SyncStartProbePlugin extends PluginScript:
	var archive_requests: Array[Dictionary] = []

	func _get_update_request_parent() -> Node:
		return self

	func _start_update_archive_sync_request(target: Dictionary, serial: int) -> void:
		archive_requests.append({"target": target.duplicate(true), "serial": serial})


class CurrentTabProbeDock extends Control:
	var current_tab := 5
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
	if str(_plugin._state.settings.get("update_source", "")) != "custom_branch" or str(_plugin._state.settings.get("update_custom_branch", "")) != "feature/persisted-settings":
		return _failure("plugin.gd should store update setting changes in runtime settings.")

	var saved_settings := _load_saved_settings()
	if str(saved_settings.get("update_source", "")) != "custom_branch" or str(saved_settings.get("update_custom_branch", "")) != "feature/persisted-settings":
		return _failure("plugin.gd should persist normalized update setting changes through _save_settings().")
	var switch_probe := PluginScript.new()
	switch_probe._state.settings["update_source"] = "latest_stable"
	switch_probe._state.settings["update_custom_branch"] = "fix/old"
	switch_probe._on_update_source_changed("custom_branch")
	if str(switch_probe._state.settings.get("update_source", "")) != "custom_branch" or str(switch_probe._state.settings.get("update_custom_branch", "")) != "dev":
		switch_probe.free()
		return _failure("plugin.gd should reset the selected custom branch to dev whenever custom branch mode is selected.")
	switch_probe.free()
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
		{"source": "latest_release", "kind": "tag", "ref": "01", "commit": "tag-commit"},
		{"source": "release_tag", "kind": "tag", "ref": "01", "commit": "tag-commit"},
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
	target_probe._state.settings["update_release_tag"] = ""
	target_probe._state.update_ref_latest_release = ""
	if not str(target_probe._resolve_update_sync_target().get("ref", "")).is_empty():
		target_probe.free()
		return _failure("plugin.gd should keep latest release sync target unavailable until discovery provides a target.")
	target_probe._state.settings["update_release_tag"] = "01"
	var explicit_release_target: Dictionary = target_probe._resolve_update_sync_target()
	if str(explicit_release_target.get("kind", "")) != "tag" or str(explicit_release_target.get("ref", "")) != "01" or str(explicit_release_target.get("commit", "")) != "tag-commit":
		target_probe.free()
		return _failure("plugin.gd should resolve an explicit release/tag selection as the sync target.")
	target_probe.free()

	var tool_facade_probe := PluginScript.new()
	var current_result: Dictionary = tool_facade_probe.get_plugin_update_current_from_tools()
	if not bool(current_result.get("success", false)) or not (current_result.get("data", {}) is Dictionary):
		tool_facade_probe.free()
		return _failure("plugin.gd should expose current plugin update metadata through the tool facade.")
	var current_data: Dictionary = current_result.get("data", {})
	for required_current_field in ["source_version", "server_version", "protocol_version", "tool_schema_version", "source_fingerprint", "source_fingerprint_short", "lifecycle_reload"]:
		if not current_data.has(required_current_field):
			tool_facade_probe.free()
			return _failure("plugin.gd update tool facade should include %s in current metadata." % required_current_field)
	var status_result: Dictionary = tool_facade_probe.get_plugin_update_status_from_tools()
	if not bool(status_result.get("success", false)) or not (status_result.get("data", {}) is Dictionary):
		tool_facade_probe.free()
		return _failure("plugin.gd should expose update status through the tool facade.")
	var status_data: Dictionary = status_result.get("data", {})
	for required_status_field in ["current", "source", "target", "refs", "compare", "sync", "lifecycle_reload"]:
		if not status_data.has(required_status_field):
			tool_facade_probe.free()
			return _failure("plugin.gd update tool facade should include %s in status." % required_status_field)
	var selected_result: Dictionary = tool_facade_probe.set_plugin_update_source_from_tools("latest_release", "", "v1.0.0")
	if not bool(selected_result.get("success", false)):
		tool_facade_probe.free()
		return _failure("plugin.gd update tool facade should accept update source selection.")
	if str(tool_facade_probe._state.settings.get("update_source", "")) != "latest_release" or str(tool_facade_probe._state.settings.get("update_release_tag", "")) != "v1.0.0":
		tool_facade_probe.free()
		return _failure("plugin.gd update tool facade should persist latest_release source selection and selected release tag.")
	var cleared_release_result: Dictionary = tool_facade_probe.set_plugin_update_source_from_tools("latest_release")
	if not bool(cleared_release_result.get("success", false)) or str(tool_facade_probe._state.settings.get("update_release_tag", "not-empty")) != "":
		tool_facade_probe.free()
		return _failure("plugin.gd update tool facade should clear a previously selected release tag when set_source omits release_tag.")
	var discover_result: Dictionary = tool_facade_probe.discover_plugin_update_refs_from_tools(true)
	if not bool(discover_result.get("success", false)) or str(discover_result.get("status", "")) != "pending":
		tool_facade_probe.free()
		return _failure("plugin.gd update tool facade should report pending discovery when no request host is available.")
	tool_facade_probe.free()

	var sync_start_probe := SyncStartProbePlugin.new()
	sync_start_probe._state.settings["update_source"] = "custom_branch"
	sync_start_probe._state.settings["update_custom_branch"] = "dev"
	var first_sync_start: Dictionary = sync_start_probe.start_plugin_update_sync_from_tools()
	var second_sync_start: Dictionary = sync_start_probe.start_plugin_update_sync_from_tools()
	if sync_start_probe.archive_requests.size() != 1:
		sync_start_probe.free()
		return _failure("plugin.gd update tool facade should not start a second archive sync while one is already loading.")
	if not bool(first_sync_start.get("accepted", false)) or not bool(first_sync_start.get("loading", false)) or bool(second_sync_start.get("accepted", true)) or not bool(second_sync_start.get("loading", false)) or str(second_sync_start.get("status", "")) != "loading":
		sync_start_probe.free()
		return _failure("plugin.gd update tool facade should return idempotent loading status for duplicate sync starts.")
	sync_start_probe.free()

	var refresh_probe := RefreshProbePlugin.new()
	_tree.root.add_child(refresh_probe.request_parent)
	refresh_probe._state.update_refs_state = "success"
	refresh_probe._update_refs_discovery_loaded = true
	refresh_probe._on_update_source_changed("custom_branch")
	if refresh_probe.discovery_request_count != 1:
		refresh_probe.request_parent.queue_free()
		refresh_probe.free()
		return _failure("plugin.gd should force-refresh update refs when the update source is selected again.")
	refresh_probe._state.update_refs_state = "success"
	refresh_probe._update_refs_discovery_loaded = true
	refresh_probe._on_update_custom_branch_changed("dev")
	if refresh_probe.discovery_request_count != 2:
		refresh_probe.request_parent.queue_free()
		refresh_probe.free()
		return _failure("plugin.gd should force-refresh update refs when the selected branch is selected again.")
	refresh_probe._state.update_ref_commits = {"v1.0.0-pre3": "annotated-tag-object-sha"}
	refresh_probe._state.update_ref_versions = {"v1.0.0-pre3": "1.0.0-pre3"}
	refresh_probe._state.update_ref_latest_release = "v1.0.0-pre3"
	refresh_probe._state.settings["update_source"] = "latest_release"
	refresh_probe._state.update_refs_state = "success"
	refresh_probe._update_refs_discovery_loaded = true
	refresh_probe._refresh_update_compare_for_current_target()
	if refresh_probe.compare_requests.is_empty() or str((refresh_probe.compare_requests[0] as Dictionary).get("head", "")) != "v1.0.0-pre3" or str((refresh_probe.compare_requests[0] as Dictionary).get("target_commit", "")) != "annotated-tag-object-sha":
		refresh_probe.request_parent.queue_free()
		refresh_probe.free()
		return _failure("plugin.gd should compare release tags by ref name while preserving the displayed target commit hash.")
	refresh_probe.request_parent.queue_free()
	refresh_probe.free()

	var reload_probe := SyncReloadProbePlugin.new()
	reload_probe._update_sync_request_serial = 10
	reload_probe._state.update_sync_state = "loading"
	await reload_probe._on_update_archive_sync_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), {"kind": "branch", "ref": "dev", "commit": "target-sha"}, 10, null)
	var localized_refresh_status := LocalizationServiceScript.translate("settings_update_sync_refreshing_editor")
	if reload_probe.reload_requests != ["settings_sync"] or reload_probe.sync_events != ["editor_refresh", "lifecycle_reload"] or reload_probe.editor_refresh_count != 1 or reload_probe.editor_refresh_state != "loading" or reload_probe.editor_refresh_status != localized_refresh_status or str(reload_probe._state.update_sync_state) != "success" or reload_probe.compare_refresh_count != 1 or reload_probe.dock_refresh_count < 2:
		reload_probe.free()
		return _failure("plugin.gd should refresh the editor file system before scheduling one deferred lifecycle reload after a successful update sync.")
	reload_probe.free()

	var refresh_timeout_probe := SyncReloadProbePlugin.new()
	refresh_timeout_probe._update_sync_request_serial = 16
	refresh_timeout_probe._state.update_sync_state = "loading"
	refresh_timeout_probe.editor_refresh_result = {"success": false, "scan_requested": true, "scan_completed": false}
	await refresh_timeout_probe._on_update_archive_sync_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), {"kind": "branch", "ref": "dev", "commit": "target-sha"}, 16, null)
	var localized_refresh_timeout := LocalizationServiceScript.translate("settings_update_sync_refresh_timeout")
	if refresh_timeout_probe.reload_requests != [] or refresh_timeout_probe.sync_events != ["editor_refresh"] or str(refresh_timeout_probe._state.update_sync_state) != "error" or str(refresh_timeout_probe._state.update_sync_error) != localized_refresh_timeout or refresh_timeout_probe.compare_refresh_count != 0:
		refresh_timeout_probe.free()
		return _failure("plugin.gd should fail update sync without scheduling lifecycle reload when editor file-system refresh does not finish.")
	refresh_timeout_probe.free()

	var failed_sync_reload_probe := SyncReloadProbePlugin.new()
	failed_sync_reload_probe._update_sync_request_serial = 11
	await failed_sync_reload_probe._on_update_archive_sync_request_completed(HTTPRequest.RESULT_CONNECTION_ERROR, 500, PackedStringArray(), PackedByteArray(), {"kind": "branch", "ref": "dev", "commit": "target-sha"}, 11, null)
	if failed_sync_reload_probe.editor_refresh_count != 0 or not failed_sync_reload_probe.reload_requests.is_empty() or str(failed_sync_reload_probe._state.update_sync_state) != "error":
		failed_sync_reload_probe.free()
		return _failure("plugin.gd should not schedule a lifecycle reload when the update archive request fails.")
	failed_sync_reload_probe.free()

	var failed_copy_reload_probe := SyncReloadProbePlugin.new()
	failed_copy_reload_probe._update_sync_request_serial = 12
	failed_copy_reload_probe.sync_result = {"success": false, "error": "copy failed"}
	await failed_copy_reload_probe._on_update_archive_sync_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), {"kind": "branch", "ref": "dev", "commit": "target-sha"}, 12, null)
	if failed_copy_reload_probe.editor_refresh_count != 0 or not failed_copy_reload_probe.reload_requests.is_empty() or str(failed_copy_reload_probe._state.update_sync_state) != "error":
		failed_copy_reload_probe.free()
		return _failure("plugin.gd should not schedule a lifecycle reload when archive files fail to sync into the addon.")
	failed_copy_reload_probe.free()

	var stale_serial_reload_probe := SyncReloadProbePlugin.new()
	stale_serial_reload_probe._update_sync_request_serial = 14
	stale_serial_reload_probe._state.update_sync_state = "pending"
	await stale_serial_reload_probe._on_update_archive_sync_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), {"kind": "branch", "ref": "dev", "commit": "target-sha"}, 13, null)
	if stale_serial_reload_probe.editor_refresh_count != 0 or not stale_serial_reload_probe.reload_requests.is_empty() or str(stale_serial_reload_probe._state.update_sync_state) != "pending" or stale_serial_reload_probe.compare_refresh_count != 0 or stale_serial_reload_probe.dock_refresh_count != 0:
		stale_serial_reload_probe.free()
		return _failure("plugin.gd should ignore stale update archive callbacks without scheduling a lifecycle reload.")
	stale_serial_reload_probe.free()

	var marker_failure_reload_probe := SyncReloadProbePlugin.new()
	marker_failure_reload_probe._update_sync_request_serial = 15
	marker_failure_reload_probe.marker_error = ERR_CANT_CREATE
	await marker_failure_reload_probe._on_update_archive_sync_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), {"kind": "branch", "ref": "dev", "commit": "target-sha"}, 15, null)
	if marker_failure_reload_probe.editor_refresh_count != 0 or not marker_failure_reload_probe.reload_requests.is_empty() or str(marker_failure_reload_probe._state.update_sync_state) != "error":
		marker_failure_reload_probe.free()
		return _failure("plugin.gd should not schedule a lifecycle reload when sync marker writing fails.")
	marker_failure_reload_probe.free()

	var pending_reload_probe := SyncReloadProbePlugin.new()
	pending_reload_probe._update_sync_request_serial = 13
	pending_reload_probe._state.update_sync_state = "loading"
	pending_reload_probe._plugin_reenable_pending = true
	await pending_reload_probe._on_update_archive_sync_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), {"kind": "branch", "ref": "dev", "commit": "target-sha"}, 13, null)
	if pending_reload_probe.editor_refresh_count != 1 or not pending_reload_probe.reload_requests.is_empty() or str(pending_reload_probe._state.update_sync_state) != "success":
		pending_reload_probe.free()
		return _failure("plugin.gd should keep sync success state without scheduling a duplicate lifecycle reload when one is already pending.")
	pending_reload_probe.free()

	var focus_restore_probe := FocusRestoreProbePlugin.new()
	focus_restore_probe._state.current_tab = 0
	focus_restore_probe._state.settings["_pending_focus_snapshot"] = {"tab_index": 5, "focus_path": ""}
	focus_restore_probe._restore_pending_focus_snapshot_if_needed()
	if focus_restore_probe._state.current_tab != 5 or focus_restore_probe.discovery_request_count != 1 or focus_restore_probe._state.settings.has("_pending_focus_snapshot"):
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
	if current_tab_probe._state.current_tab != 5 or current_tab_probe.discovery_request_count != 1 or probe_dock.apply_model_count != 0:
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
