@tool
extends RefCounted
class_name UserToolScanService

const DEFAULT_ENTRY_BUDGET_PER_TICK := 16

var _root_dir := ""
var _entry_budget_per_tick := DEFAULT_ENTRY_BUDGET_PER_TICK
var _scan_in_progress := false
var _scan_stack: Array = []
var _scan_snapshot_data: Dictionary = {}
var _entries_processed := 0
var _last_scan_duration_ms := 0.0
var _last_scan_slices := 0
var _last_error := ""


func configure(root_dir: String, entry_budget_per_tick: int = DEFAULT_ENTRY_BUDGET_PER_TICK) -> void:
	_root_dir = root_dir
	_entry_budget_per_tick = max(1, entry_budget_per_tick)
	reset()


func begin_scan() -> Dictionary:
	_scan_in_progress = true
	_scan_snapshot_data = {}
	_entries_processed = 0
	_last_scan_duration_ms = 0.0
	_last_scan_slices = 0
	_last_error = ""
	_scan_stack = [_make_scan_directory_job(_root_dir)]
	return continue_scan()


func continue_scan() -> Dictionary:
	if not _scan_in_progress:
		return _complete_result(_scan_snapshot_data)
	var started_usec := Time.get_ticks_usec()
	var processed_this_slice := 0
	_last_scan_slices += 1
	while processed_this_slice < _entry_budget_per_tick and not _scan_stack.is_empty():
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
			_entries_processed += 1
			continue
		var entry_dict := entry as Dictionary
		processed_this_slice += 1
		_entries_processed += 1
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
		return _complete_result(completed_snapshot)
	return _progress_result()


func reset(reset_last_metrics: bool = true) -> void:
	_scan_in_progress = false
	_scan_stack.clear()
	_scan_snapshot_data.clear()
	_last_error = ""
	if reset_last_metrics:
		_entries_processed = 0
		_last_scan_duration_ms = 0.0
		_last_scan_slices = 0


func get_status() -> Dictionary:
	return {
		"scan_in_progress": _scan_in_progress,
		"scan_entries_processed": _entries_processed,
		"scan_pending_directories": _scan_stack.size(),
		"last_scan_duration_ms": _last_scan_duration_ms,
		"last_scan_slices": _last_scan_slices,
		"last_error": _last_error
	}


func is_scan_in_progress() -> bool:
	return _scan_in_progress


func _complete_result(snapshot: Dictionary) -> Dictionary:
	var result := {
		"success": true,
		"complete": true,
		"snapshot": snapshot,
		"entries_processed": _entries_processed,
		"slices": _last_scan_slices,
		"last_scan_duration_ms": _last_scan_duration_ms,
		"last_error": _last_error
	}
	reset(false)
	return result


func _progress_result() -> Dictionary:
	return {
		"success": true,
		"complete": false,
		"snapshot": {},
		"entries_processed": _entries_processed,
		"slices": _last_scan_slices,
		"last_scan_duration_ms": _last_scan_duration_ms,
		"last_error": _last_error
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


func _get_file_size_bytes(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	return int(file.get_length())
