@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor filesystem tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	if not ei:
		return _error("Editor interface not available")

	match action:
		"select_file":
			return _select_file(ei, args.get("path", ""))
		"get_selected":
			return _get_selected_files(ei)
		"get_current_path":
			return _get_current_filesystem_path(ei)
		"scan":
			return _scan_filesystem(ei)
		"reimport":
			return _reimport_files(ei, args.get("paths", []))
		_:
			return _error("Unknown action: %s" % action)


func _select_file(ei, path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	if not path.begins_with("res://"):
		path = "res://" + path

	ei.select_file(path)

	return _success({"path": path}, "File selected in FileSystem dock")


func _get_selected_files(ei) -> Dictionary:
	var paths = ei.get_selected_paths()

	return _success({
		"count": paths.size(),
		"paths": Array(paths)
	})


func _get_current_filesystem_path(ei) -> Dictionary:
	var current_path = ei.get_current_path()
	var current_dir = ei.get_current_directory()

	return _success({
		"current_path": str(current_path),
		"current_directory": str(current_dir)
	})


func _scan_filesystem(ei) -> Dictionary:
	var fs = ei.get_resource_filesystem()
	if not fs:
		return _error("Filesystem not available")

	fs.scan()

	return _success(null, "Filesystem scan triggered")


func _reimport_files(ei, paths: Array) -> Dictionary:
	if paths.is_empty():
		return _error("Paths are required")

	var fs = ei.get_resource_filesystem()
	if not fs:
		return _error("Filesystem not available")

	var packed_paths = PackedStringArray()
	for p in paths:
		if not p.begins_with("res://"):
			p = "res://" + p
		packed_paths.append(p)

	fs.reimport_files(packed_paths)

	return _success({
		"count": packed_paths.size(),
		"paths": Array(packed_paths)
	}, "Reimport triggered")
