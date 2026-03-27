@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

var _scene_root_override: Node = null


func configure_context(context: Dictionary = {}) -> void:
	_scene_root_override = context.get("scene_root", null)


func _get_active_root() -> Node:
	if _scene_root_override != null and is_instance_valid(_scene_root_override):
		return _scene_root_override
	return _get_edited_scene_root()


func _find_active_node(path: String) -> Node:
	var root := _get_active_root()
	if root == null:
		return null
	if _scene_root_override == null:
		return _find_node_by_path(path)
	var normalized := _normalize_active_path(path, root)
	if normalized.is_empty() or normalized == ".":
		return root
	if normalized.begins_with("/"):
		var absolute_node = root.get_node_or_null(NodePath(normalized))
		if absolute_node != null:
			return absolute_node
	return root.get_node_or_null(NodePath(normalized))


func _normalize_active_path(path: String, root: Node = null) -> String:
	if root == null:
		root = _get_active_root()
	if root == null:
		return path.strip_edges()

	var normalized = path.strip_edges()
	if normalized.is_empty() or normalized == "/" or normalized == ".":
		return "."

	var root_name = str(root.name)
	var root_path = str(root.get_path())
	var absolute_tree_prefix = "/root/"

	if normalized == "/root":
		return "."
	if normalized.begins_with(absolute_tree_prefix):
		normalized = normalized.substr(absolute_tree_prefix.length())
		if normalized == root_name:
			return "."
		if normalized.begins_with(root_name + "/"):
			return normalized.substr(root_name.length() + 1)
		if normalized.is_empty():
			return "."

	if normalized == root_name or normalized == "/" + root_name:
		return "."
	if normalized == root_path:
		return "."
	if normalized.begins_with(root_path + "/"):
		return normalized.substr(root_path.length() + 1)
	if normalized.begins_with(root_name + "/"):
		return normalized.substr(root_name.length() + 1)
	if normalized.begins_with("/" + root_name + "/"):
		return normalized.substr(root_name.length() + 2)
	if normalized.begins_with("./"):
		return normalized.substr(2)
	if normalized.begins_with("/"):
		return normalized.trim_prefix("/")
	return normalized


func _normalize_resource_path(path: String) -> String:
	if path.is_empty():
		return path
	return _normalize_res_path(path if path.begins_with("res://") else "res://" + path)


func _ensure_parent_directory(path: String) -> void:
	var dir_path := path.get_base_dir()
	var absolute_dir := ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		DirAccess.make_dir_recursive_absolute(absolute_dir)


func _refresh_filesystem() -> void:
	var fs := _get_filesystem()
	if fs != null:
		fs.scan()


func _resource_matches_type_filter(file_type: String, file_path: String, type_filter: String) -> bool:
	if file_type.is_empty():
		file_type = _infer_resource_type_from_path(file_path)
	if type_filter.is_empty():
		return true
	if file_type == type_filter:
		return true
	if ClassDB.class_exists(file_type) and ClassDB.class_exists(type_filter) and ClassDB.is_parent_class(file_type, type_filter):
		return true
	return false


func _infer_resource_type_from_path(path: String) -> String:
	var normalized := _normalize_resource_path(path)
	var extension := normalized.get_extension().to_lower()
	match extension:
		"tscn", "scn":
			return "PackedScene"
		"gd", "cs":
			return "Script"
		"png", "jpg", "jpeg", "svg", "webp", "bmp", "tga", "hdr", "exr":
			return "Texture2D"
		"wav", "ogg", "mp3":
			return "AudioStream"
		"gdshader":
			return "Shader"
		"material":
			return "Material"
		"ttf", "otf":
			return "FontFile"
		"anim":
			return "Animation"
		"tres", "res":
			return _infer_serialized_resource_type(normalized)
		_:
			return ""


func _infer_serialized_resource_type(path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return ""

	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return ""

	var line := file.get_line().strip_edges()
	file.close()

	var type_marker := 'type="'
	var marker_index := line.find(type_marker)
	if marker_index == -1:
		return "Resource"

	var type_start := marker_index + type_marker.length()
	var type_end := line.find('"', type_start)
	if type_end == -1:
		return "Resource"
	return line.substr(type_start, type_end - type_start)


func _append_directory_resources(absolute_dir: String, root_res_path: String, type_filter: String, recursive: bool, results: Array[Dictionary]) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue

		var child_absolute := absolute_dir.path_join(entry)
		var child_res_path := _normalize_resource_path(root_res_path.path_join(entry))
		if dir.current_is_dir():
			if recursive:
				_append_directory_resources(child_absolute, child_res_path, type_filter, recursive, results)
		else:
			var file_type := _infer_resource_type_from_path(child_res_path)
			if _resource_matches_type_filter(file_type, child_res_path, type_filter):
				results.append({
					"path": child_res_path,
					"type": file_type,
					"name": entry
				})
	dir.list_dir_end()
