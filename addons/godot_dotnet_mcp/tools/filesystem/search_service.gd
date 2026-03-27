@tool
extends "res://addons/godot_dotnet_mcp/tools/filesystem/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"find_files":
			return _find_files(str(args.get("pattern", "*")), str(args.get("path", "res://")), bool(args.get("recursive", true)))
		"grep":
			return _grep(str(args.get("pattern", "")), str(args.get("path", "res://")), str(args.get("filter", "*")), bool(args.get("recursive", true)))
		"find_and_replace":
			return _find_and_replace(str(args.get("find", "")), str(args.get("replace", "")), str(args.get("path", "res://")), str(args.get("filter", "*")), bool(args.get("recursive", true)))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _find_files(pattern: String, path: String, recursive: bool) -> Dictionary:
	path = _normalize_tool_path(path if not path.is_empty() else "res://")

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

	path = _normalize_tool_path(path if not path.is_empty() else "res://")

	var files: Array[String] = []
	_collect_files(path, filter, recursive, files)

	var matches: Array[Dictionary] = []
	var regex := RegEx.new()
	var regex_error = regex.compile(pattern)

	for file_path in files:
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
			elif line.contains(pattern):
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

	path = _normalize_tool_path(path if not path.is_empty() else "res://")

	var files: Array[String] = []
	_collect_files(path, filter, recursive, files)

	var modified_files: Array[String] = []
	var total_replacements := 0

	for file_path in files:
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue

		var content = file.get_as_text()
		file.close()

		var new_content = content.replace(find, replace)
		if new_content == content:
			continue

		var protected_error = _guard_protected_plugin_write(file_path)
		if not protected_error.is_empty():
			return protected_error

		var write_file = FileAccess.open(file_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string(new_content)
			write_file.close()
			modified_files.append(file_path)
			total_replacements += content.count(find)

	_refresh_filesystem()
	return _success({
		"find": find,
		"replace": replace,
		"path": path,
		"files_modified": modified_files.size(),
		"total_replacements": total_replacements,
		"modified_files": modified_files
	})
