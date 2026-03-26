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


func _active_scene_path(node: Node) -> String:
	if not node or not node.is_inside_tree():
		return ""

	var scene_root := _get_active_root()
	if not scene_root:
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


func _node_to_active_dict(node: Node, include_children: bool = false, max_depth: int = 3) -> Dictionary:
	if not node:
		return {}

	if _scene_root_override == null:
		return _node_to_dict(node, include_children, max_depth)

	var visible = null
	var visible_in_tree = null
	if node is CanvasItem or node is Node3D:
		visible = node.visible
		visible_in_tree = node.is_visible_in_tree()

	var result = {
		"name": str(node.name),
		"type": str(node.get_class()),
		"path": _active_scene_path(node),
		"visible": visible,
		"visible_in_tree": visible_in_tree,
	}

	if node is Node2D:
		result["position"] = {"x": float(node.position.x), "y": float(node.position.y)}
		result["rotation"] = float(node.rotation)
		result["scale"] = {"x": float(node.scale.x), "y": float(node.scale.y)}
	elif node is Node3D:
		result["position"] = {"x": float(node.position.x), "y": float(node.position.y), "z": float(node.position.z)}
		result["rotation"] = {"x": float(node.rotation.x), "y": float(node.rotation.y), "z": float(node.rotation.z)}
		result["scale"] = {"x": float(node.scale.x), "y": float(node.scale.y), "z": float(node.scale.z)}

	var script = node.get_script()
	if script:
		result["script"] = str(script.resource_path)

	if include_children and max_depth > 0:
		var children: Array[Dictionary] = []
		for child in node.get_children():
			children.append(_node_to_active_dict(child, true, max_depth - 1))
		if not children.is_empty():
			result["children"] = children

	return result


func _find_nodes_by_name_in_context(pattern: String) -> Array[Node]:
	var result: Array[Node] = []
	var start := _get_active_root()
	if start == null:
		return result
	_find_nodes_recursive(start, pattern, result)
	return result


func _find_nodes_by_type_in_context(type_name: String) -> Array[Node]:
	var result: Array[Node] = []
	var start := _get_active_root()
	if start == null:
		return result
	_find_nodes_by_type_recursive(start, type_name, result)
	return result


func _find_nodes_recursive(node: Node, pattern: String, result: Array[Node]) -> void:
	if node.name.match(pattern) or str(node.name).contains(pattern):
		result.append(node)
	for child in node.get_children():
		_find_nodes_recursive(child, pattern, result)


func _find_nodes_by_type_recursive(node: Node, type_name: String, result: Array[Node]) -> void:
	if node.get_class() == type_name or node.is_class(type_name):
		result.append(node)
	for child in node.get_children():
		_find_nodes_by_type_recursive(child, type_name, result)
