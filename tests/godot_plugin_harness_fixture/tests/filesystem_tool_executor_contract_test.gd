extends RefCounted

const FilesystemExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/filesystem/executor.gd")

const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_filesystem_contracts"


func run_case(_tree: SceneTree) -> Dictionary:
	var executor = FilesystemExecutorScript.new()

	_remove_tree(TEMP_ROOT)

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 6:
		return _failure("Filesystem executor should expose 6 canonical tool definitions without the compatibility file alias.")

	var expected_names := ["directory", "file_read", "file_write", "file_manage", "json", "search"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	if actual_names.has("file"):
		return _failure("Filesystem executor should not expose the removed compatibility file alias.")
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

	var search_replace_result: Dictionary = executor.execute("search", {
		"action": "find_and_replace",
		"find": "future architecture",
		"replace": "current architecture",
		"path": TEMP_ROOT,
		"filter": "*.txt",
		"recursive": true
	})
	if not bool(search_replace_result.get("success", false)):
		return _failure("Search find_and_replace failed through the split search service.")
	if int(search_replace_result.get("data", {}).get("files_modified", -1)) != 2:
		return _failure("Search find_and_replace should update both text files in the temporary tree.")

	var replaced_read_result: Dictionary = executor.execute("file_read", {
		"action": "read",
		"path": file_write_path
	})
	if not bool(replaced_read_result.get("success", false)):
		return _failure("File read failed after search find_and_replace.")
	if str(replaced_read_result.get("data", {}).get("content", "")) != "current architecture only":
		return _failure("Search find_and_replace returned success without updating file content.")

	var plugin_cfg_content := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.cfg")
	var protected_replace_result: Dictionary = executor.execute("search", {
		"action": "find_and_replace",
		"find": "Godot .NET MCP",
		"replace": "Unsafe Plugin Rewrite",
		"path": "res://addons/godot_dotnet_mcp/plugin.cfg",
		"filter": "*.cfg",
		"recursive": false
	})
	if bool(protected_replace_result.get("success", false)):
		return _failure("Search find_and_replace should reject protected plugin writes.")
	if FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.cfg") != plugin_cfg_content:
		return _failure("Search find_and_replace should leave protected plugin files unchanged.")

	var directory_files_result: Dictionary = executor.execute("directory", {
		"action": "get_files",
		"path": TEMP_ROOT,
		"filter": "*.txt",
		"recursive": true
	})
	if not bool(directory_files_result.get("success", false)):
		return _failure("Directory get_files failed through the split directory service.")
	var directory_files_data: Dictionary = directory_files_result.get("data", {})
	var directory_count_only_result: Dictionary = executor.execute("directory", {
		"action": "get_files",
		"path": TEMP_ROOT,
		"filter": "*.txt",
		"recursive": true,
		"count_only": true
	})
	if not bool(directory_count_only_result.get("success", false)):
		return _failure("Directory get_files count_only failed through the split directory service.")
	var directory_count_only_data: Dictionary = directory_count_only_result.get("data", {})
	if int(directory_count_only_data.get("count", -1)) != int(directory_files_data.get("count", -2)):
		return _failure("Directory get_files count_only should match normal get_files count.")
	if directory_count_only_data.has("files"):
		return _failure("Directory get_files count_only should not return a files array.")
	if not bool(directory_count_only_data.get("count_only", false)):
		return _failure("Directory get_files count_only should mark the response as count_only.")
	var directory_bulk_count_only_result: Dictionary = executor.execute("directory", {
		"action": "get_files",
		"path": TEMP_ROOT,
		"filters": ["*.txt", "*.json"],
		"recursive": true,
		"count_only": true
	})
	if not bool(directory_bulk_count_only_result.get("success", false)):
		return _failure("Directory get_files bulk count_only failed through the split directory service.")
	var directory_bulk_count_only_data: Dictionary = directory_bulk_count_only_result.get("data", {})
	if directory_bulk_count_only_data.has("files"):
		return _failure("Directory get_files bulk count_only should not return a files array.")
	if not bool(directory_bulk_count_only_data.get("count_only", false)):
		return _failure("Directory get_files bulk count_only should mark the response as count_only.")
	var counts_by_filter = directory_bulk_count_only_data.get("counts_by_filter", {})
	if not (counts_by_filter is Dictionary):
		return _failure("Directory get_files bulk count_only should return counts_by_filter.")
	var bulk_counts: Dictionary = counts_by_filter
	if int(bulk_counts.get("*.txt", -1)) != int(directory_files_data.get("count", -2)):
		return _failure("Directory get_files bulk count_only should match the single-filter txt count.")
	if int(bulk_counts.get("*.json", -1)) != int(search_find_result.get("data", {}).get("count", -2)):
		return _failure("Directory get_files bulk count_only should count json files in the same traversal.")

	var guard_cases: Array[Dictionary] = [
		{
			"tool": "directory",
			"args": {"action": "list", "path": "user://outside"}
		},
		{
			"tool": "file_read",
			"args": {"action": "read", "path": "res://../project.godot"}
		},
		{
			"tool": "file_write",
			"args": {"action": "write", "path": "/tmp/godot_dotnet_mcp_outside.txt", "content": "outside"}
		},
		{
			"tool": "file_manage",
			"args": {"action": "copy", "source": file_write_path, "dest": "res://Tmp/../outside_copy.txt"}
		},
		{
			"tool": "json",
			"args": {"action": "read", "path": "file://outside.json"}
		},
		{
			"tool": "json",
			"args": {"action": "read", "path": "file:/outside.json"}
		},
		{
			"tool": "search",
			"args": {"action": "find_files", "pattern": "*.gd", "path": "res://Tmp/./bad"}
		}
	]
	for guard_case in guard_cases:
		var guard_result: Dictionary = executor.execute(str(guard_case.get("tool", "")), guard_case.get("args", {}))
		if bool(guard_result.get("success", false)):
			return _failure("Filesystem executor should reject unsafe project path case: %s" % str(guard_case))
		if str(guard_result.get("error_code", "")) != "project_path_outside_project":
			return _failure("Filesystem executor unsafe path rejection should include project_path_outside_project error_code.")

	var plugin_write_guard_result: Dictionary = executor.execute("file_write", {
		"action": "write",
		"path": "res://ADDONS/godot_dotnet_mcp/unsafe.txt",
		"content": "plugin"
	})
	if bool(plugin_write_guard_result.get("success", false)):
		return _failure("Filesystem executor should reject protected plugin writes case-insensitively.")

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
