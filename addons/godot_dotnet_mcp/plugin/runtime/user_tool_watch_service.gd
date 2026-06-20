@tool
extends RefCounted
class_name UserToolWatchService

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
var _scan_in_progress := false
var _initial_scan_pending := false
var _scan_stack: Array = []
var _scan_snapshot_data: Dictionary = {}
var _scan_entries_processed := 0
var _last_scan_duration_ms := 0.0
var _last_scan_slices := 0
var _runtime_loading_enabled_cache := false


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
	_reset_scan_state()
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
	_reset_scan_state()
	_initial_scan_pending = false


func tick() -> void:
	if not _watching:
		return
	var now_msec := Time.get_ticks_msec()
	if not _scan_in_progress and not _initial_scan_pending:
		if _last_poll_msec > 0 and now_msec - _last_poll_msec < POLL_INTERVAL_MSEC:
			return
		_last_poll_msec = now_msec
	_runtime_loading_enabled_cache = _is_runtime_loading_enabled()
	if not _runtime_loading_enabled_cache:
		_pending_snapshot.clear()
		_pending_changes.clear()
		_pending_since_msec = 0
		_reset_scan_state()
		_initial_scan_pending = false
		return
	if _scan_in_progress:
		var sliced_result := _continue_scan_snapshot()
		if bool(sliced_result.get("complete", false)):
			_handle_scan_result(sliced_result, now_msec)
		return
	if _initial_scan_pending:
		var baseline_result := _begin_incremental_scan()
		if bool(baseline_result.get("complete", false)):
			_handle_scan_result(baseline_result, now_msec)
		return
	var scan_result := _begin_incremental_scan()
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
	return {
		"enabled": _runtime_loading_enabled_cache,
		"watching": _watching and _runtime_loading_enabled_cache,
		"baseline_scan_pending": _initial_scan_pending,
		"known_script_count": _known_snapshot.size(),
		"last_scan_unix": _last_scan_unix,
		"scan_in_progress": _scan_in_progress,
		"scan_entries_processed": _scan_entries_processed,
		"scan_pending_directories": _scan_stack.size(),
		"last_scan_duration_ms": _last_scan_duration_ms,
		"last_scan_slices": _last_scan_slices,
		"last_change_reason": _last_change_reason,
		"last_error": _last_error
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


func _scan_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	var script_paths: Array[String] = []
	_collect_script_paths(CUSTOM_TOOLS_DIR, script_paths)
	for script_path in script_paths:
		if not FileAccess.file_exists(script_path):
			continue
		snapshot[script_path] = {
			"modified_unix": int(FileAccess.get_modified_time(script_path)),
			"size_bytes": _get_file_size_bytes(script_path)
		}
	return {"success": true, "snapshot": snapshot}


func _begin_incremental_scan() -> Dictionary:
	_scan_in_progress = true
	_scan_stack = [_make_scan_directory_job(CUSTOM_TOOLS_DIR)]
	_scan_snapshot_data = {}
	_scan_entries_processed = 0
	_last_scan_duration_ms = 0.0
	_last_scan_slices = 0
	return _continue_scan_snapshot()


func _continue_scan_snapshot() -> Dictionary:
	if not _scan_in_progress:
		return {"success": true, "complete": true, "snapshot": _scan_snapshot_data}
	var started_usec := Time.get_ticks_usec()
	var processed_this_slice := 0
	_last_scan_slices += 1
	while processed_this_slice < SCAN_ENTRY_BUDGET_PER_TICK and not _scan_stack.is_empty():
		var stack_index := _scan_stack.size() - 1
		var job = _scan_stack[stack_index]
		if not (job is Dictionary):
			_scan_stack.pop_back()
			continue
		var dir_job := job as Dictionary
		var entries: Array = dir_job.get("entries", [])
		var index := int(dir_job.get("index", 0))
		if index >= entries.size():
			_scan_stack.pop_back()
			continue
		var entry = entries[index]
		dir_job["index"] = index + 1
		_scan_stack[stack_index] = dir_job
		if not (entry is Dictionary):
			processed_this_slice += 1
			_scan_entries_processed += 1
			continue
		var entry_dict := entry as Dictionary
		processed_this_slice += 1
		_scan_entries_processed += 1
		var child_path := str(entry_dict.get("path", ""))
		if bool(entry_dict.get("is_dir", false)):
			_scan_stack.append(_make_scan_directory_job(child_path))
		elif child_path.ends_with(".gd") and FileAccess.file_exists(child_path):
			_scan_snapshot_data[child_path.replace("\\", "/")] = {
				"modified_unix": int(FileAccess.get_modified_time(child_path)),
				"size_bytes": _get_file_size_bytes(child_path)
			}
	_last_scan_duration_ms = maxf(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.0)
	if _scan_stack.is_empty():
		var completed_snapshot := _scan_snapshot_data
		_scan_snapshot_data = {}
		var result: Dictionary = {}
		result["success"] = true
		result["complete"] = true
		result["snapshot"] = completed_snapshot
		result["entries_processed"] = _scan_entries_processed
		result["slices"] = _last_scan_slices
		_reset_scan_state(false)
		return result
	return {
		"success": true,
		"complete": false,
		"snapshot": {},
		"entries_processed": _scan_entries_processed,
		"slices": _last_scan_slices
	}


func _make_scan_directory_job(dir_path: String) -> Dictionary:
	var entries: Array = []
	var global_path = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(global_path):
		return {"path": dir_path, "entries": entries, "index": 0}
	var dir = DirAccess.open(dir_path)
	if dir == null:
		_last_error = "watch_scan_open_failed:%s" % dir_path
		return {"path": dir_path, "entries": entries, "index": 0}
	dir.list_dir_begin()
	while true:
		var entry = dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var entry_data: Dictionary = {}
		entry_data["name"] = entry
		entry_data["path"] = "%s/%s" % [dir_path, entry]
		entry_data["is_dir"] = dir.current_is_dir()
		entries.append(entry_data)
	dir.list_dir_end()
	entries.sort_custom(Callable(self, "_sort_scan_entries"))
	return {"path": dir_path, "entries": entries, "index": 0}


func _sort_scan_entries(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("path", "")) < str(right.get("path", ""))


func _reset_scan_state(reset_last_metrics: bool = true) -> void:
	_scan_in_progress = false
	_scan_stack.clear()
	_scan_snapshot_data.clear()
	if reset_last_metrics:
		_scan_entries_processed = 0
		_last_scan_duration_ms = 0.0
		_last_scan_slices = 0


func _get_file_size_bytes(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	return int(file.get_length())


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


func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
