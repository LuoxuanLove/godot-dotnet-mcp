@tool
extends "res://addons/godot_dotnet_mcp/tools/filesystem/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"write":
			return _write_file(str(args.get("path", "")), str(args.get("content", "")))
		"append":
			return _append_file(str(args.get("path", "")), str(args.get("content", "")))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _write_file(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	path = _normalize_tool_path(path)
	var protected_error = _guard_protected_plugin_write(path)
	if not protected_error.is_empty():
		return protected_error

	_ensure_parent_directory(path)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return _error("Cannot write file: %s" % path)

	file.store_string(content)
	file.close()

	_refresh_filesystem()
	return _success({
		"path": path,
		"size": content.length()
	}, "File written")


func _append_file(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	path = _normalize_tool_path(path)

	var existing := ""
	if FileAccess.file_exists(path):
		var read_file = FileAccess.open(path, FileAccess.READ)
		if read_file:
			existing = read_file.get_as_text()
			read_file.close()

	return _write_file(path, existing + content)
