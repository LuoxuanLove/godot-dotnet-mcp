@tool
extends "res://addons/godot_dotnet_mcp/tools/filesystem/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"delete":
			return _delete_file(str(args.get("path", "")))
		"copy":
			return _copy_file(str(args.get("source", "")), str(args.get("dest", "")))
		"move":
			return _move_file(str(args.get("source", "")), str(args.get("dest", "")))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _delete_file(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	path = _normalize_tool_path(path)
	var protected_error = _guard_protected_plugin_write(path)
	if not protected_error.is_empty():
		return protected_error

	if not FileAccess.file_exists(path):
		return _error("File not found: %s" % path)

	var error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return _error("Failed to delete file: %s" % error_string(error))

	_refresh_filesystem()
	return _success({"path": path}, "File deleted")


func _copy_file(source: String, dest: String) -> Dictionary:
	if source.is_empty() or dest.is_empty():
		return _error("Source and destination paths are required")

	source = _normalize_tool_path(source)
	dest = _normalize_tool_path(dest)

	var protected_error = _guard_protected_plugin_write(dest)
	if not protected_error.is_empty():
		return protected_error
	if not FileAccess.file_exists(source):
		return _error("Source file not found: %s" % source)

	_ensure_parent_directory(dest)

	var error = DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(dest))
	if error != OK:
		return _error("Failed to copy file: %s" % error_string(error))

	_refresh_filesystem()
	return _success({
		"source": source,
		"dest": dest
	}, "File copied")


func _move_file(source: String, dest: String) -> Dictionary:
	if source.is_empty() or dest.is_empty():
		return _error("Source and destination paths are required")

	source = _normalize_tool_path(source)
	dest = _normalize_tool_path(dest)

	var source_error = _guard_protected_plugin_write(source)
	if not source_error.is_empty():
		return source_error
	var dest_error = _guard_protected_plugin_write(dest)
	if not dest_error.is_empty():
		return dest_error
	if not FileAccess.file_exists(source):
		return _error("Source file not found: %s" % source)

	_ensure_parent_directory(dest)

	var error = DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(dest))
	if error != OK:
		return _error("Failed to move file: %s" % error_string(error))

	_refresh_filesystem()
	return _success({
		"source": source,
		"dest": dest
	}, "File moved")
