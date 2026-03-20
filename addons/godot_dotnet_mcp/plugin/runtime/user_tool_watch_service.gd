@tool
extends RefCounted
class_name UserToolWatchService

const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"
const ENABLE_RUNTIME_LOADING_SETTING := "godot_dotnet_mcp/user_tools/enable_runtime_loading"
const ENABLE_RUNTIME_LOADING_SETTING_LEGACY := "user_tools/enable_runtime_loading"
const POLL_INTERVAL_MSEC := 500
const SETTLE_DELAY_MSEC := 300

var _plugin: Object
var _reload_coordinator = null
var _user_tool_service = null
var _watching := false
var _last_poll_msec := 0
var _last_scan_unix := 0
var _known_snapshot: Dictionary = {}
var _pending_snapshot: Dictionary = {}
var _pending_changes: Dictionary = {}
var _pending_since_msec := 0
var _last_change_reason := ""
var _last_error := ""


func configure(plugin: Object, reload_coordinator, user_tool_service) -> void:
	_plugin = plugin
	_reload_coordinator = reload_coordinator
	_user_tool_service = user_tool_service


func start() -> void:
	_watching = true
	_last_poll_msec = 0
	_last_scan_unix = int(Time.get_unix_time_from_system())
	_pending_snapshot.clear()
	_pending_changes.clear()
	_pending_since_msec = 0
	_last_change_reason = ""
	_last_error = ""
	var scan_result = _scan_snapshot()
	if _as_bool(scan_result.get("success", false)):
		_known_snapshot = (scan_result.get("snapshot", {}) as Dictionary).duplicate(true)
	else:
		_known_snapshot.clear()
		_last_error = str(scan_result.get("error", "watch_start_failed"))


func stop() -> void:
	_watching = false
	_pending_snapshot.clear()
	_pending_changes.clear()
	_pending_since_msec = 0


func tick() -> void:
	if not _watching:
		return
	if not _is_runtime_loading_enabled():
		_pending_snapshot.clear()
		_pending_changes.clear()
		_pending_since_msec = 0
		return
	var now_msec := Time.get_ticks_msec()
	if _last_poll_msec > 0 and now_msec - _last_poll_msec < POLL_INTERVAL_MSEC:
		return
	_last_poll_msec = now_msec

	var scan_result = _scan_snapshot()
	_last_scan_unix = int(Time.get_unix_time_from_system())
	if not _as_bool(scan_result.get("success", false)):
		_last_error = str(scan_result.get("error", "watch_scan_failed"))
		return

	var snapshot := (scan_result.get("snapshot", {}) as Dictionary).duplicate(true)
	var changes = _compute_changes(_known_snapshot, snapshot)
	if _changes_are_empty(changes):
		return

	if not _snapshots_equal(snapshot, _pending_snapshot):
		_pending_snapshot = snapshot.duplicate(true)
		_pending_changes = changes.duplicate(true)
		_pending_since_msec = now_msec
		_last_change_reason = "external_watch_pending"
		return

	if now_msec - _pending_since_msec < SETTLE_DELAY_MSEC:
		return

	var apply_result = _apply_pending_changes(_pending_changes)
	if _as_bool(apply_result.get("success", false)):
		_known_snapshot = snapshot.duplicate(true)
		_last_change_reason = str(apply_result.get("reason", "external_watch"))
		_last_error = ""
	else:
		_last_error = str(apply_result.get("error", "watch_apply_failed"))
	_pending_snapshot.clear()
	_pending_changes.clear()
	_pending_since_msec = 0


func get_status() -> Dictionary:
	return {
		"enabled": _is_runtime_loading_enabled(),
		"watching": _watching and _is_runtime_loading_enabled(),
		"known_script_count": _known_snapshot.size(),
		"last_scan_unix": _last_scan_unix,
		"last_change_reason": _last_change_reason,
		"last_error": _last_error
	}


func _apply_pending_changes(changes: Dictionary) -> Dictionary:
	if _plugin == null or not is_instance_valid(_plugin):
		return {"success": false, "error": "Plugin reference is unavailable"}
	var removed_paths: Array[String] = changes.get("removed", [])
	var added_paths: Array[String] = changes.get("added", [])
	var changed_paths: Array[String] = changes.get("changed", [])
	if _plugin.has_method("_apply_external_user_tool_catalog_refresh"):
		if not removed_paths.is_empty():
			_plugin._apply_external_user_tool_catalog_refresh(removed_paths, "watcher_file_removed")
		if not added_paths.is_empty():
			_plugin._apply_external_user_tool_catalog_refresh(added_paths, "watcher_file_added")
		if not changed_paths.is_empty():
			_plugin._apply_external_user_tool_catalog_refresh(changed_paths, "watcher_file_changed")
		return {"success": true, "reason": _summarize_change_reason(removed_paths, added_paths, changed_paths)}
	if _plugin.has_method("_refresh_user_tool_registry"):
		_plugin._refresh_user_tool_registry()
	if _reload_coordinator == null:
		return {"success": false, "error": "Reload coordinator is unavailable"}
	for script_path in removed_paths:
		_reload_coordinator.request_reload_by_script(script_path, "watcher_file_removed")
	for script_path in added_paths:
		_reload_coordinator.request_reload_by_script(script_path, "watcher_file_added")
	for script_path in changed_paths:
		_reload_coordinator.request_reload_by_script(script_path, "watcher_file_changed")
	if _plugin.has_method("_rebuild_user_tool_ui_model"):
		_plugin._rebuild_user_tool_ui_model()
	return {"success": true, "reason": _summarize_change_reason(removed_paths, added_paths, changed_paths)}


func _compute_changes(previous: Dictionary, current: Dictionary) -> Dictionary:
	var removed: Array[String] = []
	var added: Array[String] = []
	var changed: Array[String] = []
	for script_path in previous.keys():
		var normalized_path = str(script_path)
		if not current.has(normalized_path):
			removed.append(normalized_path)
	for script_path in current.keys():
		var normalized_path = str(script_path)
		if not previous.has(normalized_path):
			added.append(normalized_path)
			continue
		var previous_entry = previous.get(normalized_path, {})
		var current_entry = current.get(normalized_path, {})
		if int(previous_entry.get("modified_unix", 0)) != int(current_entry.get("modified_unix", 0)):
			changed.append(normalized_path)
			continue
		if int(previous_entry.get("size_bytes", -1)) != int(current_entry.get("size_bytes", -1)):
			changed.append(normalized_path)
	removed.sort()
	added.sort()
	changed.sort()
	return {
		"removed": removed,
		"added": added,
		"changed": changed
	}


func _scan_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	var script_paths: Array[String] = []
	_collect_script_paths(CUSTOM_TOOLS_DIR, script_paths)
	for script_path in script_paths:
		var global_path = ProjectSettings.globalize_path(script_path)
		if not FileAccess.file_exists(script_path):
			continue
		snapshot[script_path] = {
			"modified_unix": int(FileAccess.get_modified_time(script_path)),
			"size_bytes": int(FileAccess.get_file_as_bytes(global_path).size())
		}
	return {"success": true, "snapshot": snapshot}


func _collect_script_paths(dir_path: String, output: Array[String]) -> void:
	var global_path = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(global_path):
		return
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry = dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child_path = "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_collect_script_paths(child_path, output)
		elif entry.ends_with(".gd"):
			output.append(child_path.replace("\\", "/"))
	dir.list_dir_end()


func _changes_are_empty(changes: Dictionary) -> bool:
	return (changes.get("removed", []) as Array).is_empty() \
		and (changes.get("added", []) as Array).is_empty() \
		and (changes.get("changed", []) as Array).is_empty()


func _snapshots_equal(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for script_path in left.keys():
		var normalized_path = str(script_path)
		if not right.has(normalized_path):
			return false
		var left_entry = left.get(normalized_path, {})
		var right_entry = right.get(normalized_path, {})
		if int(left_entry.get("modified_unix", 0)) != int(right_entry.get("modified_unix", 0)):
			return false
		if int(left_entry.get("size_bytes", -1)) != int(right_entry.get("size_bytes", -1)):
			return false
	return true


func _summarize_change_reason(removed_paths: Array[String], added_paths: Array[String], changed_paths: Array[String]) -> String:
	if not removed_paths.is_empty():
		return "watcher_file_removed"
	if not added_paths.is_empty():
		return "watcher_file_added"
	if not changed_paths.is_empty():
		return "watcher_file_changed"
	return "external_watch"


func _is_runtime_loading_enabled() -> bool:
	if ProjectSettings.has_setting(ENABLE_RUNTIME_LOADING_SETTING):
		return true if ProjectSettings.get_setting(ENABLE_RUNTIME_LOADING_SETTING, false) else false
	return true if ProjectSettings.get_setting(ENABLE_RUNTIME_LOADING_SETTING_LEGACY, false) else false


func _as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return !is_zero_approx(value)
	if value is String:
		var normalized = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null
