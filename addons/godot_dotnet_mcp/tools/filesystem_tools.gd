@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## File system tools for Godot MCP
## Provides file and directory operations within the project

const _PLUGIN_ROOT := "res://addons/godot_dotnet_mcp"
const _MCPFileUtils = preload("res://addons/godot_dotnet_mcp/tools/mcp_file_utils.gd")

var _filesystem_path_utils = _MCPFileUtils.new()


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "directory",
			"description": """DIRECTORY OPERATIONS: Manage directories in the project.

ACTIONS:
- list: List contents of a directory
- create: Create a new directory
- delete: Delete an empty directory
- exists: Check if directory exists
- get_files: Get all files in directory (with filters). Pass count_only=true for a lightweight count-only response (returns count + count_only:true, files array absent). For count_only=true, callers may pass filters=["*.gd", "*.cs"] to count multiple patterns in one traversal; the response includes counts_by_filter. This is a public contract optimized for large-directory callers like project_state summary mode.

EXAMPLES:
- List directory: {"action": "list", "path": "res://scenes"}
- Create directory: {"action": "create", "path": "res://new_folder"}
- Get all .gd files: {"action": "get_files", "path": "res://scripts", "filter": "*.gd"}
- Count-only: {"action": "get_files", "path": "res://", "filter": "*.cs", "recursive": true, "count_only": true}
- Bulk count-only: {"action": "get_files", "path": "res://", "filters": ["*.gd", "*.cs", "*.tscn"], "recursive": true, "count_only": true}
- Check exists: {"action": "exists", "path": "res://assets"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "create", "delete", "exists", "get_files"],
						"description": "Directory action"
					},
					"path": {
						"type": "string",
						"description": "Directory path (res://...)"
					},
					"filter": {
						"type": "string",
						"description": "File filter pattern (e.g., *.gd, *.tscn)"
					},
					"filters": {
						"type": "array",
						"items": {"type": "string"},
						"description": "For count_only get_files, count multiple file filters in a single traversal and return counts_by_filter"
					},
					"recursive": {
						"type": "boolean",
						"description": "Include subdirectories"
					},
				"count_only": {
					"type": "boolean",
					"description": "For get_files, return only the matching file count (key 'count') without including the files array. This is a public API contract — callers such as project_state summary mode depend on the count-only response shape: {\"count\": <int>, \"count_only\": true}. The files array is guaranteed absent when count_only is true."
				}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "file",
			"description": "COMPATIBILITY ALIAS: Legacy filesystem_file entry kept for existing MCP wrappers.",
			"compatibility_alias": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string"},
					"path": {"type": "string"},
					"content": {"type": "string"},
					"source": {"type": "string"},
					"dest": {"type": "string"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "file_read",
			"description": """FILE READ: Read file content and inspect file presence or metadata.

ACTIONS:
- read: Read file contents
- exists: Check if file exists
- get_info: Get file information

NOTE: For script files, prefer using script_read, script_inspect, or script_edit_gd tools.
For resources, prefer using resource_manage tools.

EXAMPLES:
- Read file: {"action": "read", "path": "res://data/config.json"}
- Get info: {"action": "get_info", "path": "res://project.godot"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["read", "exists", "get_info"],
						"description": "File action"
					},
					"path": {
						"type": "string",
						"description": "File path"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "file_write",
			"description": """FILE WRITE: Create or append plain-text files inside the project.

ACTIONS:
- write: Write content to file
- append: Append content to file

EXAMPLES:
- Write file: {"action": "write", "path": "res://data/save.json", "content": "{\\"level\\": 1}"}
- Append file: {"action": "append", "path": "res://notes.txt", "content": "\\nline"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["write", "append"],
						"description": "Write action"
					},
					"path": {
						"type": "string",
						"description": "File path"
					},
					"content": {
						"type": "string",
						"description": "Content to write/append"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "file_manage",
			"description": """FILE MANAGE: Delete, copy or move files in the project.

ACTIONS:
- delete: Delete a file
- copy: Copy a file
- move: Move or rename a file

EXAMPLES:
- Delete: {"action": "delete", "path": "res://old.txt"}
- Copy: {"action": "copy", "source": "res://template.txt", "dest": "res://copy.txt"}
- Move: {"action": "move", "source": "res://old.txt", "dest": "res://new.txt"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["delete", "copy", "move"],
						"description": "Manage action"
					},
					"path": {
						"type": "string",
						"description": "File path"
					},
					"source": {
						"type": "string",
						"description": "Source path for copy/move"
					},
					"dest": {
						"type": "string",
						"description": "Destination path for copy/move"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "json",
			"description": """JSON OPERATIONS: Read and write JSON files.

ACTIONS:
- read: Read and parse JSON file
- write: Write data as JSON file
- get_value: Get a specific value from JSON file using path
- set_value: Set a specific value in JSON file

EXAMPLES:
- Read JSON: {"action": "read", "path": "res://data/config.json"}
- Write JSON: {"action": "write", "path": "res://data/settings.json", "data": {"volume": 0.8}}
- Get value: {"action": "get_value", "path": "res://data/config.json", "key": "player.health"}
- Set value: {"action": "set_value", "path": "res://data/config.json", "key": "player.health", "value": 100}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["read", "write", "get_value", "set_value"],
						"description": "JSON action"
					},
					"path": {
						"type": "string",
						"description": "JSON file path"
					},
					"data": {
						"description": "Data to write (for write action)"
					},
					"key": {
						"type": "string",
						"description": "Dot-separated path to value (e.g., 'player.health')"
					},
					"value": {
						"description": "Value to set"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "search",
			"description": """FILE SEARCH: Search for files and content in the project.

ACTIONS:
- find_files: Find files by name pattern
- grep: Search for text content in files
- find_and_replace: Find and replace text in files

EXAMPLES:
- Find files: {"action": "find_files", "pattern": "*.gd", "path": "res://"}
- Search content: {"action": "grep", "pattern": "func _ready", "path": "res://scripts"}
- Find and replace: {"action": "find_and_replace", "find": "old_name", "replace": "new_name", "path": "res://scripts", "filter": "*.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["find_files", "grep", "find_and_replace"],
						"description": "Search action"
					},
					"pattern": {
						"type": "string",
						"description": "Search pattern"
					},
					"path": {
						"type": "string",
						"description": "Directory to search in"
					},
					"find": {
						"type": "string",
						"description": "Text to find (for find_and_replace)"
					},
					"replace": {
						"type": "string",
						"description": "Replacement text"
					},
					"filter": {
						"type": "string",
						"description": "File filter (e.g., *.gd)"
					},
					"recursive": {
						"type": "boolean",
						"description": "Search recursively"
					}
				},
				"required": ["action"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"directory":
			return _execute_directory(args)
		"file":
			return _execute_file_compat(args)
		"file_read":
			return _execute_file_read(args)
		"file_write":
			return _execute_file_write(args)
		"file_manage":
			return _execute_file_manage(args)
		"json":
			return _execute_json(args)
		"search":
			return _execute_search(args)
		_:
			return _error("Unknown tool: %s" % tool_name)


# ==================== DIRECTORY ====================

func _execute_directory(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")

	if path.is_empty():
		return _error("Path is required")

	var path_result := _normalize_tool_path_result(path)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	match action:
		"list":
			return _list_directory(path)
		"create":
			return _create_directory(path)
		"delete":
			return _delete_directory(path)
		"exists":
			return _directory_exists(path)
		"get_files":
			return _get_files(path, args.get("filter", "*"), args.get("recursive", false), bool(args.get("count_only", false)), args.get("filters", []))
		_:
			return _error("Unknown action: %s" % action)


func _list_directory(path: String) -> Dictionary:
	var dir = DirAccess.open(path)
	if not dir:
		return _error("Cannot open directory: %s" % path)

	var files: Array[String] = []
	var dirs: Array[String] = []

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				dirs.append(file_name)
		else:
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()
	dirs.sort()

	return _success({
		"path": path,
		"directories": dirs,
		"files": files,
		"total_dirs": dirs.size(),
		"total_files": files.size()
	})


func _create_directory(path: String) -> Dictionary:
	var protected_error = _guard_protected_plugin_write(path)
	if not protected_error.is_empty():
		return protected_error

	var abs_path = ProjectSettings.globalize_path(path)
	var error = DirAccess.make_dir_recursive_absolute(abs_path)

	if error != OK:
		return _error("Failed to create directory: %s" % error_string(error))

	# Refresh filesystem
	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _success({"path": path}, "Directory created")


func _delete_directory(path: String) -> Dictionary:
	var protected_error = _guard_protected_plugin_write(path)
	if not protected_error.is_empty():
		return protected_error

	var abs_path = ProjectSettings.globalize_path(path)

	if not DirAccess.dir_exists_absolute(abs_path):
		return _error("Directory not found: %s" % path)

	var error = DirAccess.remove_absolute(abs_path)
	if error != OK:
		return _error("Failed to delete directory (must be empty): %s" % error_string(error))

	# Refresh filesystem
	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _success({"path": path}, "Directory deleted")


func _directory_exists(path: String) -> Dictionary:
	var abs_path = ProjectSettings.globalize_path(path)
	return _success({
		"path": path,
		"exists": DirAccess.dir_exists_absolute(abs_path)
	})


func _get_files(path: String, filter: String, recursive: bool, count_only: bool = false, filters: Array = []) -> Dictionary:
	if count_only:
		if not filters.is_empty():
			return _success({
				"path": path,
				"filters": filters.duplicate(),
				"recursive": recursive,
				"count_only": true,
				"counts_by_filter": _count_files_by_filters(path, filters, recursive)
			})
		return _success({
			"path": path,
			"filter": filter,
			"recursive": recursive,
			"count_only": true,
			"count": _count_files(path, filter, recursive)
		})
	var files: Array[String] = []
	_collect_files(path, filter, recursive, files)

	return _success({
		"path": path,
		"filter": filter,
		"recursive": recursive,
		"count": files.size(),
		"files": files
	})


func _count_files_by_filters(path: String, filters: Array, recursive: bool) -> Dictionary:
	var counts := {}
	for raw_filter in filters:
		counts[str(raw_filter)] = 0
	var pending: Array = [path]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		var dir = DirAccess.open(current)
		if not dir:
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = current.path_join(file_name)
			if dir.current_is_dir():
				if recursive and not file_name.begins_with(".") and not dir.is_link(file_name):
					pending.append(full_path)
			else:
				for raw_filter in filters:
					var filter_text := str(raw_filter)
					if file_name.match(filter_text):
						counts[filter_text] = int(counts.get(filter_text, 0)) + 1
			file_name = dir.get_next()
		dir.list_dir_end()
	return counts


func _count_files(path: String, filter: String, recursive: bool) -> int:
	var count := 0
	var pending: Array = [path]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		var dir = DirAccess.open(current)
		if not dir:
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = current.path_join(file_name)
			if dir.current_is_dir():
				if recursive and not file_name.begins_with(".") and not dir.is_link(file_name):
					pending.append(full_path)
			else:
				if file_name.match(filter):
					count += 1
			file_name = dir.get_next()
		dir.list_dir_end()
	return count


func _collect_files(path: String, filter: String, recursive: bool, results: Array[String]) -> void:
	if FileAccess.file_exists(path):
		var file_name := path.get_file()
		if file_name.match(filter):
			results.append(path)
		return

	var pending: Array = [path]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		var dir = DirAccess.open(current)
		if not dir:
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = current.path_join(file_name)
			if dir.current_is_dir():
				if recursive and not file_name.begins_with(".") and not dir.is_link(file_name):
					pending.append(full_path)
			else:
				if file_name.match(filter) and not dir.is_link(file_name):
					results.append(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()


# ==================== FILE ====================

func _execute_file_read(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"read":
			return _read_file(args.get("path", ""))
		"exists":
			return _file_exists(args.get("path", ""))
		"get_info":
			return _get_file_info(args.get("path", ""))
		_:
			return _error("Unknown action: %s" % action)


func _execute_file_write(args: Dictionary) -> Dictionary:
	match args.get("action", ""):
		"write":
			return _write_file(args.get("path", ""), args.get("content", ""))
		"append":
			return _append_file(args.get("path", ""), args.get("content", ""))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _execute_file_manage(args: Dictionary) -> Dictionary:
	match args.get("action", ""):
		"delete":
			return _delete_file(args.get("path", ""))
		"copy":
			return _copy_file(args.get("source", ""), args.get("dest", ""))
		"move":
			return _move_file(args.get("source", ""), args.get("dest", ""))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _execute_file_compat(args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	if action in ["read", "exists", "get_info"]:
		return _execute_file_read(args)
	if action in ["write", "append"]:
		return _execute_file_write(args)
	return _execute_file_manage(args)


func _read_file(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var path_result := _normalize_tool_path_result(path, false)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return _error("Cannot read file: %s" % path)

	var content = file.get_as_text()
	file.close()

	return _success({
		"path": path,
		"content": content,
		"size": content.length()
	})


func _write_file(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var path_result := _normalize_tool_path_result(path, false)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	var protected_error = _guard_protected_plugin_write(path)
	if not protected_error.is_empty():
		return protected_error

	# Ensure directory exists
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return _error("Cannot write file: %s" % path)

	file.store_string(content)
	file.close()

	# Refresh filesystem
	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _success({
		"path": path,
		"size": content.length()
	}, "File written")


func _append_file(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var path_result := _normalize_tool_path_result(path, false)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	# Read existing content if file exists
	var existing = ""
	if FileAccess.file_exists(path):
		var read_file = FileAccess.open(path, FileAccess.READ)
		if read_file:
			existing = read_file.get_as_text()
			read_file.close()

	return _write_file(path, existing + content)


func _delete_file(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var path_result := _normalize_tool_path_result(path, false)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	var protected_error = _guard_protected_plugin_write(path)
	if not protected_error.is_empty():
		return protected_error

	var abs_path = ProjectSettings.globalize_path(path)

	if not FileAccess.file_exists(path):
		return _error("File not found: %s" % path)

	var error = DirAccess.remove_absolute(abs_path)
	if error != OK:
		return _error("Failed to delete file: %s" % error_string(error))

	# Refresh filesystem
	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _success({"path": path}, "File deleted")


func _file_exists(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var path_result := _normalize_tool_path_result(path, false)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	return _success({
		"path": path,
		"exists": FileAccess.file_exists(path)
	})


func _copy_file(source: String, dest: String) -> Dictionary:
	if source.is_empty() or dest.is_empty():
		return _error("Source and destination paths are required")

	var source_result := _normalize_tool_path_result(source, false)
	if not bool(source_result.get("success", false)):
		return source_result
	var dest_result := _normalize_tool_path_result(dest, false)
	if not bool(dest_result.get("success", false)):
		return dest_result
	source = str(source_result.get("path", ""))
	dest = str(dest_result.get("path", ""))

	var protected_error = _guard_protected_plugin_write(dest)
	if not protected_error.is_empty():
		return protected_error

	var source_abs = ProjectSettings.globalize_path(source)
	var dest_abs = ProjectSettings.globalize_path(dest)

	if not FileAccess.file_exists(source):
		return _error("Source file not found: %s" % source)

	# Ensure destination directory exists
	var dest_dir = dest.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dest_dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))

	var error = DirAccess.copy_absolute(source_abs, dest_abs)
	if error != OK:
		return _error("Failed to copy file: %s" % error_string(error))

	# Refresh filesystem
	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _success({
		"source": source,
		"dest": dest
	}, "File copied")


func _move_file(source: String, dest: String) -> Dictionary:
	if source.is_empty() or dest.is_empty():
		return _error("Source and destination paths are required")

	var source_result := _normalize_tool_path_result(source, false)
	if not bool(source_result.get("success", false)):
		return source_result
	var dest_result := _normalize_tool_path_result(dest, false)
	if not bool(dest_result.get("success", false)):
		return dest_result
	source = str(source_result.get("path", ""))
	dest = str(dest_result.get("path", ""))

	var source_error = _guard_protected_plugin_write(source)
	if not source_error.is_empty():
		return source_error
	var dest_error = _guard_protected_plugin_write(dest)
	if not dest_error.is_empty():
		return dest_error

	var source_abs = ProjectSettings.globalize_path(source)
	var dest_abs = ProjectSettings.globalize_path(dest)

	if not FileAccess.file_exists(source):
		return _error("Source file not found: %s" % source)

	# Ensure destination directory exists
	var dest_dir = dest.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dest_dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))

	var error = DirAccess.rename_absolute(source_abs, dest_abs)
	if error != OK:
		return _error("Failed to move file: %s" % error_string(error))

	# Refresh filesystem
	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _success({
		"source": source,
		"dest": dest
	}, "File moved")


func _get_file_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var path_result := _normalize_tool_path_result(path, false)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	if not FileAccess.file_exists(path):
		return _error("File not found: %s" % path)

	return _success({
		"path": path,
		"name": path.get_file(),
		"extension": path.get_extension(),
		"directory": path.get_base_dir(),
		"modified_time": FileAccess.get_modified_time(path)
	})


# ==================== JSON ====================

func _execute_json(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")

	if path.is_empty():
		return _error("Path is required")

	var path_result := _normalize_tool_path_result(path, false)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	match action:
		"read":
			return _read_json(path)
		"write":
			return _write_json(path, args.get("data"))
		"get_value":
			return _get_json_value(path, args.get("key", ""))
		"set_value":
			return _set_json_value(path, args.get("key", ""), args.get("value"))
		_:
			return _error("Unknown action: %s" % action)


func _read_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return _error("Cannot read file: %s" % path)

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		return _error("Invalid JSON: %s at line %d" % [json.get_error_message(), json.get_error_line()])

	return _success({
		"path": path,
		"data": json.get_data()
	})


func _write_json(path: String, data) -> Dictionary:
	if data == null:
		return _error("Data is required")

	var normalized_data = _parse_json_like_value(data)
	var content = JSON.stringify(normalized_data, "\t")

	return _write_file(path, content)


func _normalize_tool_path(path: String) -> String:
	var result := _normalize_tool_path_result(path)
	return str(result.get("path", "")) if bool(result.get("success", false)) else ""


func _normalize_tool_path_result(path: String, allow_root: bool = true) -> Dictionary:
	return _filesystem_path_utils.validate_project_path(path, allow_root)


func _guard_protected_plugin_write(path: String) -> Dictionary:
	var normalized_path := path.replace("\\", "/").trim_suffix("/")
	var normalized_plugin_root := _PLUGIN_ROOT
	if OS.get_name() == "Windows":
		normalized_path = normalized_path.to_lower()
		normalized_plugin_root = normalized_plugin_root.to_lower()
	if normalized_path == normalized_plugin_root or normalized_path.begins_with(normalized_plugin_root + "/"):
		return _error("Writes to plugin files are blocked: %s" % path)
	return {}


func _get_json_value(path: String, key: String) -> Dictionary:
	if key.is_empty():
		return _error("Key is required")

	var read_result = _read_json(path)
	if not read_result.get("success", false):
		return read_result

	var data = read_result.data.data
	var value_result = _get_nested_value(data, key)
	if not value_result.get("success", false):
		return value_result

	return _success({
		"path": path,
		"key": key,
		"value": value_result["data"]["value"]
	})


func _set_json_value(path: String, key: String, value) -> Dictionary:
	if key.is_empty():
		return _error("Key is required")

	# Read existing data or create new
	var data = {}
	if FileAccess.file_exists(path):
		var read_result = _read_json(path)
		if read_result.get("success", false):
			data = read_result.data.data
		if not data is Dictionary:
			data = {}

	var normalized_value = _parse_json_like_value(value)
	var set_result = _set_nested_value(data, key, normalized_value)
	if not set_result.get("success", false):
		return set_result

	return _write_json(path, data)


# ==================== SEARCH ====================

func _execute_search(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"find_files":
			return _find_files(args.get("pattern", "*"), args.get("path", "res://"), args.get("recursive", true))
		"grep":
			return _grep(args.get("pattern", ""), args.get("path", "res://"), args.get("filter", "*"), args.get("recursive", true))
		"find_and_replace":
			return _find_and_replace(args.get("find", ""), args.get("replace", ""), args.get("path", "res://"), args.get("filter", "*"), args.get("recursive", true))
		_:
			return _error("Unknown action: %s" % action)


func _find_files(pattern: String, path: String, recursive: bool) -> Dictionary:
	var path_result := _normalize_tool_path_result(path)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	var files: Array[String] = []
	_collect_files(path, pattern, recursive, files)

	return _success({
		"pattern": pattern,
		"path": path,
		"count": files.size(),
		"files": files
	})


func _grep(pattern: String, path: String, filter: String, recursive: bool) -> Dictionary:
	if pattern.is_empty():
		return _error("Pattern is required")

	var path_result := _normalize_tool_path_result(path)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	var files: Array[String] = []
	_collect_files(path, filter, recursive, files)

	var matches: Array[Dictionary] = []
	var regex = RegEx.new()
	var regex_error = regex.compile(pattern)

	for file_path in files:
		var file_path_result := _normalize_tool_path_result(file_path, false)
		if not bool(file_path_result.get("success", false)):
			return file_path_result
		file_path = str(file_path_result.get("path", file_path))
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue

		var content = file.get_as_text()
		file.close()

		var lines = content.split("\n")
		for i in lines.size():
			var line = lines[i]
			if regex_error == OK:
				if regex.search(line):
					matches.append({
						"file": file_path,
						"line": i + 1,
						"content": line.strip_edges()
					})
			else:
				if line.contains(pattern):
					matches.append({
						"file": file_path,
						"line": i + 1,
						"content": line.strip_edges()
					})

	return _success({
		"pattern": pattern,
		"path": path,
		"count": matches.size(),
		"matches": matches
	})


func _find_and_replace(find: String, replace: String, path: String, filter: String, recursive: bool) -> Dictionary:
	if find.is_empty():
		return _error("Find pattern is required")

	var path_result := _normalize_tool_path_result(path)
	if not bool(path_result.get("success", false)):
		return path_result
	path = str(path_result.get("path", ""))

	var files: Array[String] = []
	_collect_files(path, filter, recursive, files)

	var pending_writes: Array[Dictionary] = []
	var total_replacements = 0

	for file_path in files:
		var file_path_result := _normalize_tool_path_result(file_path, false)
		if not bool(file_path_result.get("success", false)):
			return file_path_result
		file_path = str(file_path_result.get("path", file_path))

		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue

		var content = file.get_as_text()
		file.close()

		var new_content = content.replace(find, replace)
		if new_content != content:
			var protected_error := _guard_protected_plugin_write(file_path)
			if not protected_error.is_empty():
				return protected_error
			pending_writes.append({
				"path": file_path,
				"content": new_content
			})
			total_replacements += content.count(find)

	var modified_files: Array[String] = []
	for pending_write in pending_writes:
		var file_path := str(pending_write.get("path", ""))
		var write_file = FileAccess.open(file_path, FileAccess.WRITE)
		if not write_file:
			return _error("Failed to open file for replacement write: %s" % file_path, {
				"path": file_path,
				"partial_write": not modified_files.is_empty(),
				"modified_files": modified_files
			})
		write_file.store_string(str(pending_write.get("content", "")))
		write_file.flush()
		var write_error := write_file.get_error()
		write_file.close()
		if write_error != OK:
			return _error("Failed to write replacement content: %s" % file_path, {
				"path": file_path,
				"error_code": write_error,
				"partial_write": not modified_files.is_empty(),
				"modified_files": modified_files
			})
		modified_files.append(file_path)

	# Refresh filesystem
	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _success({
		"find": find,
		"replace": replace,
		"path": path,
		"files_modified": modified_files.size(),
		"total_replacements": total_replacements,
		"modified_files": modified_files
	})
