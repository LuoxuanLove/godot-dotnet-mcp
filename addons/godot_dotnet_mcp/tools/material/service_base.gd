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


func _load_material(path: String) -> Material:
	if path.is_empty():
		return null

	if path.contains("/"):
		var node = _find_active_node(path)
		if node:
			if node is GeometryInstance3D and node.get_surface_override_material(0):
				return node.get_surface_override_material(0)
			if node is MeshInstance3D and node.mesh:
				return node.mesh.surface_get_material(0) if node.mesh.get_surface_count() > 0 else null
			if node is CanvasItem and "material" in node:
				return node.material

	var resource_path := path
	if not resource_path.begins_with("res://"):
		resource_path = "res://" + resource_path

	if ResourceLoader.exists(resource_path):
		var resource = load(resource_path)
		if resource is Material:
			return resource

	return null


func _get_mesh(path: String = "", mesh_path: String = "") -> Mesh:
	if not path.is_empty():
		var node = _find_active_node(path)
		if node is MeshInstance3D and node.mesh:
			return node.mesh
		if node is MeshInstance2D and node.mesh:
			return node.mesh

	if not mesh_path.is_empty():
		var normalized_mesh_path := mesh_path
		if not normalized_mesh_path.begins_with("res://"):
			normalized_mesh_path = "res://" + normalized_mesh_path
		if ResourceLoader.exists(normalized_mesh_path):
			return load(normalized_mesh_path) as Mesh

	return null
