extends RefCounted

const FilesystemExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/filesystem/executor.gd")

const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_filesystem_contracts"


func run_case(_tree: SceneTree) -> Dictionary:
	var executor = FilesystemExecutorScript.new()

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/filesystem_tools.gd"):
		return _failure("filesystem_tools.gd should be removed once the split executor becomes the only stable entry.")

	_remove_tree(TEMP_ROOT)

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 6:
		return _failure("Filesystem executor should expose 6 tool definitions after the split.")

	var expected_names := ["directory", "file_read", "file_write", "file_manage", "json", "search"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Filesystem executor is missing tool definition '%s'." % expected_name)

	var directory_create_result: Dictionary = executor.execute("directory", {
		"action": "create",
		"path": TEMP_ROOT.path_join("data")
	})
	if not bool(directory_create_result.get("success", false)):
		return _failure("Directory create failed through the split directory service.")

	var file_write_path := TEMP_ROOT.path_join("data").path_join("notes.txt")
	var file_write_result: Dictionary = executor.execute("file_write", {
		"action": "write",
		"path": file_write_path,
		"content": "future architecture only"
	})
	if not bool(file_write_result.get("success", false)):
		return _failure("File write failed through the split file_write service.")

	var file_read_result: Dictionary = executor.execute("file_read", {
		"action": "read",
		"path": file_write_path
	})
	if not bool(file_read_result.get("success", false)):
		return _failure("File read failed through the split file_read service.")
	if str(file_read_result.get("data", {}).get("content", "")) != "future architecture only":
		return _failure("File read returned unexpected content after split.")

	var copied_path := TEMP_ROOT.path_join("data").path_join("notes_copy.txt")
	var file_copy_result: Dictionary = executor.execute("file_manage", {
		"action": "copy",
		"source": file_write_path,
		"dest": copied_path
	})
	if not bool(file_copy_result.get("success", false)):
		return _failure("File copy failed through the split file_manage service.")

	var json_path := TEMP_ROOT.path_join("data").path_join("config.json")
	var json_write_result: Dictionary = executor.execute("json", {
		"action": "write",
		"path": json_path,
		"data": {
			"project": {
				"mode": "future"
			}
		}
	})
	if not bool(json_write_result.get("success", false)):
		return _failure("JSON write failed through the split json service.")

	var json_get_result: Dictionary = executor.execute("json", {
		"action": "get_value",
		"path": json_path,
		"key": "project.mode"
	})
	if not bool(json_get_result.get("success", false)):
		return _failure("JSON get_value failed through the split json service.")
	if str(json_get_result.get("data", {}).get("value", "")) != "future":
		return _failure("JSON get_value returned unexpected data after split.")

	var search_find_result: Dictionary = executor.execute("search", {
		"action": "find_files",
		"pattern": "*.json",
		"path": TEMP_ROOT,
		"recursive": true
	})
	if not bool(search_find_result.get("success", false)):
		return _failure("Search find_files failed through the split search service.")

	var search_grep_result: Dictionary = executor.execute("search", {
		"action": "grep",
		"pattern": "future architecture",
		"path": TEMP_ROOT,
		"filter": "*.txt",
		"recursive": true
	})
	if not bool(search_grep_result.get("success", false)):
		return _failure("Search grep failed through the split search service.")

	var directory_files_result: Dictionary = executor.execute("directory", {
		"action": "get_files",
		"path": TEMP_ROOT,
		"filter": "*.txt",
		"recursive": true
	})
	if not bool(directory_files_result.get("success", false)):
		return _failure("Directory get_files failed through the split directory service.")

	return {
		"name": "filesystem_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"txt_file_count": int(directory_files_result.get("data", {}).get("count", 0)),
			"json_match_count": int(search_find_result.get("data", {}).get("count", 0)),
			"grep_match_count": int(search_grep_result.get("data", {}).get("count", 0)),
			"copied_path": copied_path
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_remove_tree(TEMP_ROOT)


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_tree_absolute(absolute_path)


func _remove_tree_absolute(absolute_path: String) -> void:
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree_absolute(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "filesystem_tool_executor_contracts",
		"success": false,
		"error": message
	}
