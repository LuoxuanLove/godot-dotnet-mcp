@tool
extends RefCounted
class_name MCPNodeUtils


func get_editor_interface() -> EditorInterface:
	if Engine.has_singleton("EditorInterface"):
		return Engine.get_singleton("EditorInterface")
	return null


func get_edited_scene_root() -> Node:
	var ei = get_editor_interface()
	if ei:
		return ei.get_edited_scene_root()
	return null


func get_selection() -> EditorSelection:
	var ei = get_editor_interface()
	if ei:
		return ei.get_selection()
	return null


func get_filesystem() -> EditorFileSystem:
	var ei = get_editor_interface()
	if ei:
		return ei.get_resource_filesystem()
	return null


func get_scene_path(node: Node) -> String:
	if not node or not node.is_inside_tree():
		return ""

	var scene_root = get_edited_scene_root()
	if not scene_root:
		return str(node.get_path())
	if node == scene_root:
		return str(node.name)

	var node_path_str = str(node.get_path())
	var scene_path_str = str(scene_root.get_path())
	if node_path_str.begins_with(scene_path_str + "/"):
		return node_path_str.substr(scene_path_str.length() + 1)
	if node_path_str == scene_path_str:
		return str(node.name)
	return node_path_str


func node_to_dict(node: Node, include_children: bool = false, max_depth: int = 3) -> Dictionary:
	if not node:
		return {}

	var visible = null
	var visible_in_tree = null
	if node is CanvasItem or node is Node3D:
		visible = node.visible
		visible_in_tree = node.is_visible_in_tree()

	var result = {
		"name": str(node.name),
		"type": str(node.get_class()),
		"path": get_scene_path(node),
		"visible": visible,
		"visible_in_tree": visible_in_tree,
	}

	if node is Node2D:
		result["position"] = {"x": float(node.position.x), "y": float(node.position.y)}
		result["rotation"] = float(node.rotation)
		result["scale"] = {"x": float(node.scale.x), "y": float(node.scale.y)}

	if node is Node3D:
		result["position"] = {"x": float(node.position.x), "y": float(node.position.y), "z": float(node.position.z)}
		result["rotation"] = {"x": float(node.rotation.x), "y": float(node.rotation.y), "z": float(node.rotation.z)}
		result["scale"] = {"x": float(node.scale.x), "y": float(node.scale.y), "z": float(node.scale.z)}

	var script = node.get_script()
	if script:
		result["script"] = str(script.resource_path)

	if include_children and max_depth > 0:
		var children: Array[Dictionary] = []
		for child in node.get_children():
			children.append(node_to_dict(child, true, max_depth - 1))
		if not children.is_empty():
			result["children"] = children

	return result


func find_node_by_path(path: String) -> Node:
	var root = get_edited_scene_root()
	if not root:
		return null

	var normalized_path = normalize_node_path(path, root)
	if normalized_path.is_empty() or normalized_path == ".":
		return root
	if normalized_path.begins_with("/"):
		var absolute_node = root.get_node_or_null(NodePath(normalized_path))
		if absolute_node:
			return absolute_node
	return root.get_node_or_null(NodePath(normalized_path))


func normalize_node_path(path: String, root: Node = null) -> String:
	if root == null:
		root = get_edited_scene_root()
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


func find_nodes_by_name(name_pattern: String, parent: Node = null) -> Array[Node]:
	var result: Array[Node] = []
	var start = parent if parent else get_edited_scene_root()
	if not start:
		return result

	_find_nodes_recursive(start, name_pattern, result)
	return result


func find_nodes_by_type(type_name: String, parent: Node = null) -> Array[Node]:
	var result: Array[Node] = []
	var start = parent if parent else get_edited_scene_root()
	if not start:
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
