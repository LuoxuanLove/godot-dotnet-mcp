extends RefCounted

const UserToolWatchService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_watch_service.gd")


class Recorder extends RefCounted:
	var calls: Array[Dictionary] = []

	func record(paths: Array[String], reason: String) -> void:
		calls.append({
			"paths": paths.duplicate(),
			"reason": reason
		})


func run_case(_tree: SceneTree) -> Dictionary:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_watch_service.gd")
	if source.find("get_file_as_bytes") != -1:
		return _failure("User tool watcher should not read entire script contents during polling.")
	if source.find("const POLL_INTERVAL_MSEC := 5000") == -1:
		return _failure("User tool watcher should keep a conservative polling interval to avoid idle editor stalls.")
	if source.find("const SCAN_ENTRY_BUDGET_PER_TICK := 16") == -1:
		return _failure("User tool watcher should keep a per-tick scan budget to avoid periodic editor stalls.")
	if source.find("if not _scan_in_progress and not _initial_scan_pending:") == -1 or source.find("now_msec - _last_poll_msec < POLL_INTERVAL_MSEC") == -1:
		return _failure("User tool watcher should skip ProjectSettings reads until the next poll window when no scan is active.")
	if source.find("func start() -> void:") == -1 or source.find("_initial_scan_pending = true") == -1:
		return _failure("User tool watcher should schedule initial scans instead of doing synchronous startup scans.")
	if source.find("func get_status_snapshot() -> Dictionary:") == -1:
		return _failure("User tool watcher should expose a cached status snapshot for idle Dock polling.")

	var service = UserToolWatchService.new()
	var recorder = Recorder.new()
	service.configure(
		RefCounted.new(),
		null,
		null,
		Callable(recorder, "record")
	)
	var idle_status: Dictionary = service.get_status_snapshot()
	if bool(idle_status.get("enabled", true)) or bool(idle_status.get("watching", true)):
		return _failure("User tool watcher status snapshot should avoid ProjectSettings reads before watch start.")

	var changed_path := "res://addons/godot_dotnet_mcp/custom_tools/sample_watch_target.gd"
	var result: Dictionary = service._apply_pending_changes({
		"removed": [],
		"added": [],
		"changed": [changed_path]
	})
	if not bool(result.get("success", false)):
		return _failure("User tool watcher should apply external refresh via callback.")
	if recorder.calls.size() != 1:
		return _failure("User tool watcher should invoke the external refresh callback once.")

	var call: Dictionary = recorder.calls[0]
	if str(call.get("reason", "")) != "watcher_file_changed":
		return _failure("User tool watcher should preserve the change reason.")

	var paths: Array = call.get("paths", [])
	if paths.size() != 1 or str(paths[0]) != changed_path:
		return _failure("User tool watcher should pass the changed path to the callback.")

	var budget_result := _verify_scan_budget()
	if not bool(budget_result.get("success", false)):
		return budget_result

	return {
		"name": "user_tool_watch_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"callback_count": recorder.calls.size(),
			"last_reason": str(call.get("reason", "")),
			"last_path": str((paths[0] if paths.size() > 0 else ""))
		}
	}


func _verify_scan_budget() -> Dictionary:
	var previous_setting = ProjectSettings.get_setting(UserToolWatchService.ENABLE_RUNTIME_LOADING_SETTING, null)
	var had_setting := ProjectSettings.has_setting(UserToolWatchService.ENABLE_RUNTIME_LOADING_SETTING)
	ProjectSettings.set_setting(UserToolWatchService.ENABLE_RUNTIME_LOADING_SETTING, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UserToolWatchService.CUSTOM_TOOLS_DIR))
	var created_paths: Array[String] = []
	for index in range(80):
		var path := "res://addons/godot_dotnet_mcp/custom_tools/watch_budget_%02d.gd" % index
		created_paths.append(path)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_restore_runtime_loading_setting(had_setting, previous_setting)
			_cleanup_paths(created_paths)
			return _failure("Failed to create watcher budget fixture file: %s" % path)
		file.store_string("extends RefCounted\n")
		file.close()
	var service = UserToolWatchService.new()
	var recorder = Recorder.new()
	service.configure(RefCounted.new(), null, null, Callable(recorder, "record"))
	service.start()
	var start_status: Dictionary = service.get_status()
	if not bool(start_status.get("baseline_scan_pending", false)):
		_restore_runtime_loading_setting(had_setting, previous_setting)
		_cleanup_paths(created_paths)
		return _failure("User tool watcher start should defer the initial baseline scan.")
	if int(start_status.get("known_script_count", 0)) != 0:
		_restore_runtime_loading_setting(had_setting, previous_setting)
		_cleanup_paths(created_paths)
		return _failure("User tool watcher start should not synchronously build the initial snapshot.")
	for _baseline_attempt in range(20):
		service.tick()
		if not bool(service.get_status().get("baseline_scan_pending", false)) and not bool(service.get_status().get("scan_in_progress", false)):
			break
	var baseline_status: Dictionary = service.get_status()
	if bool(baseline_status.get("baseline_scan_pending", false)) or bool(baseline_status.get("scan_in_progress", false)):
		_restore_runtime_loading_setting(had_setting, previous_setting)
		_cleanup_paths(created_paths)
		return _failure("User tool watcher should complete the deferred baseline scan after several ticks.")
	var steady_state_result := _verify_steady_state_poll_starts_next_scan(service, created_paths)
	if not bool(steady_state_result.get("success", false)):
		_restore_runtime_loading_setting(had_setting, previous_setting)
		_cleanup_paths(created_paths)
		return steady_state_result
	var slice_result := _verify_incremental_slice_budget(service, created_paths)
	if not bool(slice_result.get("success", false)):
		_restore_runtime_loading_setting(had_setting, previous_setting)
		_cleanup_paths(created_paths)
		return slice_result
	for _attempt in range(20):
		service.tick()
		if not bool(service.get_status().get("scan_in_progress", false)):
			break
	var final_status: Dictionary = service.get_status()
	_restore_runtime_loading_setting(had_setting, previous_setting)
	_cleanup_paths(created_paths)
	if bool(final_status.get("scan_in_progress", false)):
		return _failure("User tool watcher should complete the budgeted scan after several ticks.")
	if int(final_status.get("last_scan_slices", 0)) <= 1:
		return _failure("User tool watcher should report that a large scan was split across multiple slices.")
	return {"success": true}


func _verify_steady_state_poll_starts_next_scan(service, created_paths: Array[String]) -> Dictionary:
	for path in created_paths:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string("extends Node\n")
			file.close()
	service._last_poll_msec = 0
	service.tick()
	var status: Dictionary = service.get_status()
	if not bool(status.get("scan_in_progress", false)) and int(status.get("last_scan_slices", 0)) <= 1:
		return _failure("User tool watcher should start the next steady-state scan once the poll window opens.")
	for _attempt in range(20):
		service.tick()
		if not bool(service.get_status().get("scan_in_progress", false)):
			break
	return {"success": true}


func _verify_incremental_slice_budget(service, created_paths: Array[String]) -> Dictionary:
	var entries: Array = []
	for path in created_paths:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string("extends Node\n")
			file.close()
		entries.append({
			"name": path.get_file(),
			"path": path,
			"is_dir": false
		})
	service._scan_in_progress = true
	service._scan_stack = [{
		"path": UserToolWatchService.CUSTOM_TOOLS_DIR,
		"entries": entries,
		"index": 0
	}]
	service._scan_snapshot_data = {}
	service._scan_entries_processed = 0
	service._last_scan_slices = 0
	var first_result: Dictionary = service._continue_scan_snapshot()
	var first_status: Dictionary = service.get_status()
	if bool(first_result.get("complete", false)) or not bool(first_status.get("scan_in_progress", false)):
		return _failure("User tool watcher should leave large scans in progress after one budgeted slice.")
	if int(first_status.get("scan_entries_processed", 0)) > 16:
		return _failure("User tool watcher should not process more entries than the per-tick scan budget.")
	return {"success": true}


func _cleanup_paths(paths: Array[String]) -> void:
	for path in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _restore_runtime_loading_setting(had_setting: bool, previous_setting) -> void:
	if had_setting:
		ProjectSettings.set_setting(UserToolWatchService.ENABLE_RUNTIME_LOADING_SETTING, previous_setting)
	else:
		ProjectSettings.clear(UserToolWatchService.ENABLE_RUNTIME_LOADING_SETTING)


func _failure(message: String) -> Dictionary:
	return {
		"name": "user_tool_watch_service_contracts",
		"success": false,
		"error": message
	}
