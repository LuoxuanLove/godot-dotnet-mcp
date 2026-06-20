extends RefCounted

const UserToolScanService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_scan_service.gd")

const SCAN_ROOT := "res://addons/godot_dotnet_mcp/custom_tools/scan_service_contract"


func run_case(_tree: SceneTree) -> Dictionary:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_scan_service.gd")
	if source.find("get_file_as_bytes") != -1 or source.find("get_file_as_string") != -1:
		return _failure("UserToolScanService should scan metadata without reading full script contents.")
	if source.find("DEFAULT_ENTRY_BUDGET_PER_TICK := 16") == -1:
		return _failure("UserToolScanService should keep the conservative default scan budget.")
	if source.find("func begin_scan() -> Dictionary:") == -1 or source.find("func continue_scan() -> Dictionary:") == -1:
		return _failure("UserToolScanService should expose explicit incremental scan steps.")
	if source.find("func get_status() -> Dictionary:") == -1:
		return _failure("UserToolScanService should expose lightweight status snapshots for diagnostics.")

	_cleanup_root()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCAN_ROOT))
	var created_paths: Array[String] = []
	for index in range(80):
		var path := "%s/scan_%02d.gd" % [SCAN_ROOT, index]
		created_paths.append(path)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_cleanup_root()
			return _failure("Failed to create scan fixture: %s" % path)
		file.store_string("extends RefCounted\n")
		file.close()

	var service = UserToolScanService.new()
	service.configure(SCAN_ROOT, 16)
	var first_result: Dictionary = service.begin_scan()
	var first_status: Dictionary = service.get_status()
	if bool(first_result.get("complete", false)):
		_cleanup_root()
		return _failure("Large user-tool scans should not complete in a single budgeted slice.")
	if not bool(first_status.get("scan_in_progress", false)):
		_cleanup_root()
		return _failure("Large user-tool scans should remain in progress after the first budgeted slice.")
	if int(first_status.get("scan_entries_processed", 0)) > 16:
		_cleanup_root()
		return _failure("UserToolScanService should not process more entries than the configured slice budget.")

	var final_result: Dictionary = first_result
	for _attempt in range(20):
		final_result = service.continue_scan()
		if bool(final_result.get("complete", false)):
			break
	if not bool(final_result.get("complete", false)):
		_cleanup_root()
		return _failure("UserToolScanService should complete a large scan after several slices.")
	if int(final_result.get("slices", 0)) <= 1:
		_cleanup_root()
		return _failure("UserToolScanService should report multi-slice completion for large scans.")
	var snapshot: Dictionary = final_result.get("snapshot", {})
	if snapshot.size() != created_paths.size():
		_cleanup_root()
		return _failure("UserToolScanService should include all discovered .gd files in the completed snapshot.")
	var sample_entry: Dictionary = snapshot.get(created_paths[0], {})
	if int(sample_entry.get("modified_unix", 0)) <= 0 or int(sample_entry.get("size_bytes", 0)) <= 0:
		_cleanup_root()
		return _failure("UserToolScanService should record file timestamp and size metadata.")
	var completed_status: Dictionary = service.get_status()
	if bool(completed_status.get("scan_in_progress", true)):
		_cleanup_root()
		return _failure("UserToolScanService status should clear scan_in_progress after completion.")
	if int(completed_status.get("last_scan_slices", 0)) <= 1:
		_cleanup_root()
		return _failure("UserToolScanService status should retain the last completed slice count.")

	var missing_service = UserToolScanService.new()
	missing_service.configure("%s/missing" % SCAN_ROOT, 16)
	var missing_result: Dictionary = missing_service.begin_scan()
	if not bool(missing_result.get("complete", false)) or not bool(missing_result.get("success", false)):
		_cleanup_root()
		return _failure("UserToolScanService should complete missing roots as empty snapshots.")
	if not (missing_result.get("snapshot", {}) as Dictionary).is_empty():
		_cleanup_root()
		return _failure("UserToolScanService should return an empty snapshot for missing roots.")

	_cleanup_root()
	return {
		"name": "user_tool_scan_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"file_count": created_paths.size(),
			"slices": int(final_result.get("slices", 0))
		}
	}


func _cleanup_root() -> void:
	var absolute_root := ProjectSettings.globalize_path(SCAN_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		_remove_directory_recursive(absolute_root)


func _remove_directory_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while not entry.is_empty():
			if entry != "." and entry != "..":
				var child_path := path.path_join(entry)
				if dir.current_is_dir():
					_remove_directory_recursive(child_path)
				else:
					DirAccess.remove_absolute(child_path)
			entry = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "user_tool_scan_service_contracts",
		"success": false,
		"error": message
	}
