@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

var _scene_root_override: Node = null


func configure_context(context: Dictionary = {}) -> void:
	_scene_root_override = context.get("scene_root", null)


func _get_active_root() -> Node:
	if _scene_root_override != null and is_instance_valid(_scene_root_override):
		return _scene_root_override
	return _get_edited_scene_root()


func _get_scene_owner() -> Node:
	var active_root := _get_active_root()
	if active_root != null and is_instance_valid(active_root):
		return active_root
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


func _active_scene_path(node: Node) -> String:
	if not node or not node.is_inside_tree():
		return ""

	var scene_root := _get_active_root()
	if scene_root == null:
		return str(node.get_path())
	if node == scene_root:
		return str(node.name)

	var node_path_str := str(node.get_path())
	var scene_path_str := str(scene_root.get_path())
	if node_path_str.begins_with(scene_path_str + "/"):
		return node_path_str.substr(scene_path_str.length() + 1)
	if node_path_str == scene_path_str:
		return str(node.name)
	return node_path_str


func _find_particle_node(path: String) -> Node:
	var node := _find_active_node(path)
	if node != null and _is_particle_emitter(node):
		return node
	return null


func _is_particle_emitter(node: Node) -> bool:
	return node is GPUParticles2D or node is GPUParticles3D or node is CPUParticles2D or node is CPUParticles3D


func _get_particle_process_material(node: Node) -> ParticleProcessMaterial:
	if node is GPUParticles2D or node is GPUParticles3D:
		return node.process_material as ParticleProcessMaterial
	return null


func _build_particle_vector(values: Dictionary, node: Node, default_y: float = 0.0):
	if node is CPUParticles2D:
		return Vector2(values.get("x", 0.0), values.get("y", default_y))
	return Vector3(values.get("x", 0.0), values.get("y", default_y), values.get("z", 0.0))
