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


func _looks_like_resource_path(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("uid://") or path.contains(".")


func _normalize_res_path_with_extension(path: String, extension: String = "") -> String:
	if path.is_empty():
		return ""

	var normalized = path.strip_edges()
	if not normalized.begins_with("res://"):
		normalized = "res://" + normalized
	if not extension.is_empty() and not normalized.ends_with(extension):
		normalized += extension
	return normalized


func _load_shader(path: String) -> Shader:
	var resource_path := _normalize_res_path_with_extension(path, ".gdshader")
	if resource_path.is_empty():
		return null
	if ResourceLoader.exists(resource_path):
		return load(resource_path) as Shader
	return null


func _load_shader_material(path: String) -> ShaderMaterial:
	if path.is_empty():
		return null

	if not _looks_like_resource_path(path):
		var node = _find_active_node(path)
		if node != null:
			if node is GeometryInstance3D and node.get_surface_override_material(0) is ShaderMaterial:
				return node.get_surface_override_material(0)
			if node is CanvasItem and node.material is ShaderMaterial:
				return node.material

	var candidates: Array[String] = []
	var normalized = path.strip_edges()
	if normalized.begins_with("res://"):
		candidates.append(normalized)
	else:
		candidates.append("res://" + normalized)
	if not normalized.ends_with(".tres") and not normalized.ends_with(".res"):
		candidates.append(_normalize_res_path_with_extension(path, ".tres"))
		candidates.append(_normalize_res_path_with_extension(path, ".res"))

	for candidate in candidates:
		if ResourceLoader.exists(candidate):
			return load(candidate) as ShaderMaterial

	return null


func _notify_filesystem(path: String) -> void:
	var filesystem = _get_filesystem()
	if filesystem != null:
		filesystem.update_file(path)
