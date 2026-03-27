@tool
extends "res://addons/godot_dotnet_mcp/tools/resource/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"copy":
			return _copy_resource(_normalize_resource_path(str(args.get("source", ""))), _normalize_resource_path(str(args.get("dest", ""))))
		"move":
			return _move_resource(_normalize_resource_path(str(args.get("source", ""))), _normalize_resource_path(str(args.get("dest", ""))))
		"delete":
			return _delete_resource(_normalize_resource_path(str(args.get("path", ""))))
		"reload":
			return _reload_resource(_normalize_resource_path(str(args.get("path", ""))))
		_:
			return _error("Unknown action: %s" % action)


func _copy_resource(source: String, dest: String) -> Dictionary:
	if source.is_empty():
		return _error("Source path is required")
	if dest.is_empty():
		return _error("Destination path is required")
	if not FileAccess.file_exists(source):
		return _error("Source not found: %s" % source)

	_ensure_parent_directory(dest)
	var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(dest))
	if error != OK:
		return _error("Failed to copy resource: %s" % error_string(error))

	_refresh_filesystem()
	return _success({
		"source": source,
		"dest": dest
	}, "Resource copied")


func _move_resource(source: String, dest: String) -> Dictionary:
	if source.is_empty():
		return _error("Source path is required")
	if dest.is_empty():
		return _error("Destination path is required")
	if not FileAccess.file_exists(source):
		return _error("Source not found: %s" % source)

	_ensure_parent_directory(dest)
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(dest))
	if error != OK:
		return _error("Failed to move resource: %s" % error_string(error))

	_refresh_filesystem()
	return _success({
		"source": source,
		"dest": dest
	}, "Resource moved")


func _delete_resource(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if not FileAccess.file_exists(path):
		return _error("Resource not found: %s" % path)

	var absolute_path := ProjectSettings.globalize_path(path)
	var error := DirAccess.remove_absolute(absolute_path)
	if error != OK:
		return _error("Failed to delete resource: %s" % error_string(error))

	var import_path := absolute_path + ".import"
	if FileAccess.file_exists(import_path):
		DirAccess.remove_absolute(import_path)

	_refresh_filesystem()
	return _success({"deleted": path}, "Resource deleted")


func _reload_resource(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if not ResourceLoader.exists(path):
		return _error("Resource not found: %s" % path)

	var resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		return _error("Failed to reload resource: %s" % path)

	return _success({
		"path": path,
		"type": str(resource.get_class())
	}, "Resource reloaded")
