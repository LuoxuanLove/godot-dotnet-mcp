@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const _PLUGIN_ROOT := "res://addons/godot_dotnet_mcp"

var _context: Dictionary = {}


func configure_context(context: Dictionary = {}) -> void:
	_context = context.duplicate(true)


func _normalize_tool_path(path: String) -> String:
	var normalized = path.strip_edges().replace("\\", "/")
	if normalized.is_empty():
		return ""
	if not normalized.begins_with("res://") and not normalized.begins_with("user://"):
		normalized = "res://" + normalized
	return normalized


func _guard_protected_plugin_write(path: String) -> Dictionary:
	if path == _PLUGIN_ROOT or path.begins_with(_PLUGIN_ROOT + "/"):
		return _error("Writes to plugin files are blocked: %s" % path)
	return {}


func _refresh_filesystem() -> void:
	var fs = _get_filesystem()
	if fs:
		fs.scan()


func _ensure_parent_directory(path: String) -> void:
	var dir_path = path.get_base_dir()
	if dir_path.is_empty():
		return
	var absolute_dir = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		DirAccess.make_dir_recursive_absolute(absolute_dir)


func _collect_files(path: String, filter: String, recursive: bool, results: Array[String]) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			if recursive and not file_name.begins_with("."):
				_collect_files(full_path, filter, recursive, results)
		elif file_name.match(filter):
			results.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
