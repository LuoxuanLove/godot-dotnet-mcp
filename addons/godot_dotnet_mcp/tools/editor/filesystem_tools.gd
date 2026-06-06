@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor filesystem tools for Godot MCP

const IMPORTABLE_RESOURCE_EXTENSIONS := {
	"bmp": true,
	"dae": true,
	"exr": true,
	"fbx": true,
	"glb": true,
	"gltf": true,
	"hdr": true,
	"jpg": true,
	"jpeg": true,
	"material": true,
	"mp3": true,
	"obj": true,
	"ogg": true,
	"otf": true,
	"png": true,
	"svg": true,
	"tga": true,
	"ttf": true,
	"wav": true,
	"webp": true
}

const NOT_IMPORTABLE_RESOURCE_EXTENSIONS := {
	"cfg": "configuration_file",
	"csproj": "project_metadata",
	"import": "import_sidecar",
	"json": "metadata_file",
	"md": "documentation_file",
	"sln": "project_metadata",
	"txt": "text_file",
	"uid": "uid_sidecar"
}


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
		var path := _normalize_project_path(str(p))
		var not_importable := _not_importable_resource_context(path)
		if not not_importable.is_empty():
			return _error("Path is not importable: %s" % path, not_importable)
		packed_paths.append(path)

	fs.reimport_files(packed_paths)

	return _success({
		"count": packed_paths.size(),
		"paths": Array(packed_paths)
	}, "Reimport triggered")


func _normalize_project_path(path: String) -> String:
	var normalized := path.strip_edges().replace("\\", "/")
	if normalized.is_empty():
		return normalized
	if normalized.contains("://") or normalized.find(":") != -1:
		return normalized
	if not normalized.begins_with("res://"):
		normalized = "res://" + normalized.trim_prefix("/")
	return normalized


func _not_importable_resource_context(path: String) -> Dictionary:
	if path.is_empty():
		return _not_importable_resource_data(path, "empty_path")
	if not path.begins_with("res://"):
		return _not_importable_resource_data(path, "outside_project")
	if path.to_lower() == "res://project.godot":
		return _not_importable_resource_data(path, "project_settings_file")
	var directory := DirAccess.open(path)
	if directory != null:
		return _not_importable_resource_data(path, "directory")
	var extension := path.get_extension().to_lower()
	if extension.is_empty():
		return _not_importable_resource_data(path, "missing_extension")
	if NOT_IMPORTABLE_RESOURCE_EXTENSIONS.has(extension):
		return _not_importable_resource_data(path, str(NOT_IMPORTABLE_RESOURCE_EXTENSIONS[extension]))
	if FileAccess.file_exists(path + ".import"):
		return {}
	if IMPORTABLE_RESOURCE_EXTENSIONS.has(extension):
		return {}
	return _not_importable_resource_data(path, "unsupported_extension")


func _not_importable_resource_data(path: String, reason: String) -> Dictionary:
	return {
		"error_type": "not_importable_resource",
		"error_code": "not_importable_resource",
		"path": path,
		"reason": reason,
		"hint": "Use scan for FileSystem refreshes. Reimport only files managed by Godot's import pipeline."
	}
