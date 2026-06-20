@tool
extends RefCounted
class_name UserToolWatchService

const UserToolScanService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_scan_service.gd")

const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"
const ENABLE_RUNTIME_LOADING_SETTING := "godot_dotnet_mcp/user_tools/enable_runtime_loading"
const ENABLE_RUNTIME_LOADING_SETTING_LEGACY := "user_tools/enable_runtime_loading"
const POLL_INTERVAL_MSEC := 5000
const SETTLE_DELAY_MSEC := 300
const SCAN_ENTRY_BUDGET_PER_TICK := 16

var _plugin: Object
var _reload_coordinator = null
var _user_tool_service = null
var _apply_external_user_tool_catalog_refresh := Callable()
var _watching := false
var _last_poll_msec := 0
var _last_scan_unix := 0
var _known_snapshot: Dictionary = {}
var _pending_snapshot: Dictionary = {}
var _pending_changes: Dictionary = {}
var _pending_since_msec := 0
var _last_change_reason := ""
var _last_error := ""
var _initial_scan_pending := false
var _runtime_loading_enabled_cache := false
var _scan_service := UserToolScanService.new()


func _init() -> void:
	_scan_service.configure(CUSTOM_TOOLS_DIR, SCAN_ENTRY_BUDGET_PER_TICK)


func configure(plugin: Object, reload_coordinator, user_tool_service, apply_external_user_tool_catalog_refresh: Callable = Callable()) -> void:
	_plugin = plugin
	_reload_coordinator = reload_coordinator
	_user_tool_service = user_tool_service
	_apply_external_user_tool_catalog_refresh = apply_external_user_tool_catalog_refresh


func start() -> void:
	_watching = true
	_last_poll_msec = 0
	_last_scan_unix = int(Time.get_unix_time_from_system())
	_runtime_loading_enabled_cache = _is_runtime_loading_enabled()
	_pending_snapshot.clear()
	_pending_changes.clear()
	_pending_since_msec = 0
	_scan_service.reset()
	_initial_scan_pending = true
	_last_change_reason = ""
	_last_error = ""
	if not _runtime_loading_enabled_cache:
		_initial_scan_pending = false
		_known_snapshot.clear()
		return
	_known_snapshot.clear()


func stop() -> void:
	_watching = false
	_pending_snapshot.clear()
	_pending_changes.clear()
	_pending_since_msec = 0
	_scan_service.reset()
	_initial_scan_pending = false


func tick() -> void:
	if not _watching:
		return
	var now_msec := Time.get_ticks_msec()
	if not _scan_service.is_scan_in_progress() and not _initial_scan_pending:
		if _last_poll_msec > 0 and now_msec - _last_poll_msec < POLL_INTERVAL_MSEC:
			return
		_last_poll_msec = now_msec
	_runtime_loading_enabled_cache = _is_runtime_loading_enabled()
	if not _runtime_loading_enabled_cache:
		_pending_snapshot.clear()
		_pending_changes.clear()
		_pending_since_msec = 0
		_scan_service.reset()
		_initial_scan_pending = false
		return
	if _scan_service.is_scan_in_progress():
		var sliced_result := _scan_service.continue_scan()
		if bool(sliced_result.get("complete", false)):
			_handle_scan_result(sliced_result, now_msec)
		return
	if _initial_scan_pending:
		var baseline_result := _scan_service.begin_scan()
		if bool(baseline_result.get("complete", false)):
			_handle_scan_result(baseline_result, now_msec)
		return
	var scan_result := _scan_service.begin_scan()
	if bool(scan_result.get("complete", false)):
		_handle_scan_result(scan_result, now_msec)


func _handle_scan_result(scan_result: Dictionary, now_msec: int) -> void:
	_last_scan_unix = int(Time.get_unix_time_from_system())
	if not _as_bool(scan_result.get("success", false)):
		_last_error = str(scan_result.get("error", "watch_scan_failed"))
		return

	var snapshot: Dictionary = {}
	var raw_snapshot = scan_result.get("snapshot", {})
	if raw_snapshot is Dictionary:
		snapshot = raw_snapshot as Dictionary
	if _initial_scan_pending:
		_known_snapshot = snapshot
		_initial_scan_pending = false
		_last_poll_msec = now_msec
		_last_error = ""
		_last_change_reason = "watch_baseline_ready"
		return
	var changes = _compute_changes(_known_snapshot, snapshot)
	if _changes_are_empty(changes):
		return

	if not _snapshots_equal(snapshot, _pending_snapshot):
		_pending_snapshot = snapshot
		_pending_changes = changes
		_pending_since_msec = now_msec
		_last_change_reason = "external_watch_pending"
		return

	if now_msec - _pending_since_msec < SETTLE_DELAY_MSEC:
		return

	var apply_result = _apply_pending_changes(_pending_changes)
	if _as_bool(apply_result.get("success", false)):
		_known_snapshot = snapshot
		_last_change_reason = str(apply_result.get("reason", "external_watch"))
		_last_error = ""
	else:
		_last_error = str(apply_result.get("error", "watch_apply_failed"))
	_pending_snapshot.clear()
	_pending_changes.clear()
	_pending_since_msec = 0


func get_status() -> Dictionary:
	return get_status_snapshot()


func get_status_snapshot() -> Dictionary:
	var scan_status := _scan_service.get_status()
	return {
		"enabled": _runtime_loading_enabled_cache,
		"watching": _watching and _runtime_loading_enabled_cache,
		"baseline_scan_pending": _initial_scan_pending,
		"known_script_count": _known_snapshot.size(),
		"last_scan_unix": _last_scan_unix,
		"scan_in_progress": bool(scan_status.get("scan_in_progress", false)),
		"scan_entries_processed": int(scan_status.get("scan_entries_processed", 0)),
		"scan_pending_directories": int(scan_status.get("scan_pending_directories", 0)),
		"last_scan_duration_ms": float(scan_status.get("last_scan_duration_ms", 0.0)),
		"last_scan_slices": int(scan_status.get("last_scan_slices", 0)),
		"last_change_reason": _last_change_reason,
		"last_error": _last_error if not _last_error.is_empty() else str(scan_status.get("last_error", ""))
	}


func _apply_pending_changes(changes: Dictionary) -> Dictionary:
	if _plugin == null or not is_instance_valid(_plugin):
		return {"success": false, "error": "Plugin reference is unavailable"}
	var removed_paths := _to_string_array(changes.get("removed", []))
	var added_paths := _to_string_array(changes.get("added", []))
	var changed_paths := _to_string_array(changes.get("changed", []))
	if _apply_external_user_tool_catalog_refresh.is_valid():
		if not removed_paths.is_empty():
			_apply_external_user_tool_catalog_refresh.call(removed_paths, "watcher_file_removed")
		if not added_paths.is_empty():
			_apply_external_user_tool_catalog_refresh.call(added_paths, "watcher_file_added")
		if not changed_paths.is_empty():
			_apply_external_user_tool_catalog_refresh.call(changed_paths, "watcher_file_changed")
		return {"success": true, "reason": _summarize_change_reason(removed_paths, added_paths, changed_paths)}
	if _reload_coordinator == null:
		return {"success": false, "error": "Reload coordinator is unavailable"}
	for script_path in removed_paths:
		_reload_coordinator.request_reload_by_script(script_path, "watcher_file_removed")
	for script_path in added_paths:
		_reload_coordinator.request_reload_by_script(script_path, "watcher_file_added")
	for script_path in changed_paths:
		_reload_coordinator.request_reload_by_script(script_path, "watcher_file_changed")
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


func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
