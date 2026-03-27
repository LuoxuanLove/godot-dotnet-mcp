@tool
extends "res://addons/godot_dotnet_mcp/tools/filesystem/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"read":
			return _read_file(str(args.get("path", "")))
		"exists":
			return _file_exists(str(args.get("path", "")))
		"get_info":
			return _get_file_info(str(args.get("path", "")))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _read_file(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	path = _normalize_tool_path(path)
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


func _file_exists(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	path = _normalize_tool_path(path)
	return _success({
		"path": path,
		"exists": FileAccess.file_exists(path)
	})


func _get_file_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	path = _normalize_tool_path(path)
	if not FileAccess.file_exists(path):
		return _error("File not found: %s" % path)

	return _success({
		"path": path,
		"name": path.get_file(),
		"extension": path.get_extension(),
		"directory": path.get_base_dir(),
		"modified_time": FileAccess.get_modified_time(path)
	})
