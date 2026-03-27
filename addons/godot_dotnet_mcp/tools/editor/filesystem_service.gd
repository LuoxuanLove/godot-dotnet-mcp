@tool
extends "res://addons/godot_dotnet_mcp/tools/editor/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")

	match action:
		"select_file":
			var path := _normalize_res_path(str(args.get("path", "")))
			if path.is_empty():
				return _error("Path is required")
			editor_interface.select_file(path)
			return _success({"path": path}, "File selected in FileSystem dock")
		"get_selected":
			var paths = editor_interface.get_selected_paths()
			return _success({"count": paths.size(), "paths": Array(paths)})
		"get_current_path":
			return _success({
				"current_path": str(editor_interface.get_current_path()),
				"current_directory": str(editor_interface.get_current_directory())
			})
		"scan":
			var fs = editor_interface.get_resource_filesystem()
			if fs == null:
				return _error("Filesystem not available")
			fs.scan()
			return _success(null, "Filesystem scan triggered")
		"reimport":
			var fs = editor_interface.get_resource_filesystem()
			if fs == null:
				return _error("Filesystem not available")
			var paths: Array = args.get("paths", [])
			if paths.is_empty():
				return _error("Paths are required")
			var packed_paths := PackedStringArray()
			for path in paths:
				packed_paths.append(_normalize_res_path(str(path)))
			fs.reimport_files(packed_paths)
			return _success({"count": packed_paths.size(), "paths": Array(packed_paths)}, "Reimport triggered")
		_:
			return _error("Unknown action: %s" % action)
