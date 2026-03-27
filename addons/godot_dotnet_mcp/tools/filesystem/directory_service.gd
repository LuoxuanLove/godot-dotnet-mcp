@tool
extends "res://addons/godot_dotnet_mcp/tools/filesystem/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var path = str(args.get("path", ""))

	if path.is_empty():
		return _error("Path is required")

	path = _normalize_tool_path(path)

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
			return _get_files(path, str(args.get("filter", "*")), bool(args.get("recursive", false)))
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

	var absolute_path = ProjectSettings.globalize_path(path)
	var error = DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK:
		return _error("Failed to create directory: %s" % error_string(error))

	_refresh_filesystem()
	return _success({"path": path}, "Directory created")


func _delete_directory(path: String) -> Dictionary:
	var protected_error = _guard_protected_plugin_write(path)
	if not protected_error.is_empty():
		return protected_error

	var absolute_path = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return _error("Directory not found: %s" % path)

	var error = DirAccess.remove_absolute(absolute_path)
	if error != OK:
		return _error("Failed to delete directory (must be empty): %s" % error_string(error))

	_refresh_filesystem()
	return _success({"path": path}, "Directory deleted")


func _directory_exists(path: String) -> Dictionary:
	var absolute_path = ProjectSettings.globalize_path(path)
	return _success({
		"path": path,
		"exists": DirAccess.dir_exists_absolute(absolute_path)
	})


func _get_files(path: String, filter: String, recursive: bool) -> Dictionary:
	var files: Array[String] = []
	_collect_files(path, filter, recursive, files)
	return _success({
		"path": path,
		"filter": filter,
		"recursive": recursive,
		"count": files.size(),
		"files": files
	})
