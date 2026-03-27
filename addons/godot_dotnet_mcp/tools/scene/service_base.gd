@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const TEMP_SCENE_DIR := "res://Tmp/godot_dotnet_mcp_scene_temp"

var _scene_root_override: Node = null
var _scene_path_override := ""
var _editor_interface_override = null
var _selection_override = null


func configure_context(context: Dictionary = {}) -> void:
	_scene_root_override = context.get("scene_root", null)
	_scene_path_override = str(context.get("scene_path", ""))
	_editor_interface_override = context.get("editor_interface", null)
	_selection_override = context.get("selection", null)


func _get_active_root() -> Node:
	if _scene_root_override != null and is_instance_valid(_scene_root_override):
		return _scene_root_override
	return _get_edited_scene_root()


func _get_active_editor_interface():
	if _editor_interface_override != null:
		return _editor_interface_override
	return _get_editor_interface()


func _get_active_selection():
	if _selection_override != null:
		return _selection_override
	return _get_selection()


func _get_active_scene_path() -> String:
	var root := _get_active_root()
	if root == null:
		return ""
	if not _scene_path_override.is_empty():
		return _scene_path_override
	return str(root.scene_file_path)


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


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


func _scene_node_to_dict(node: Node) -> Dictionary:
	if _scene_root_override == null:
		var result := _node_to_dict(node, false)
		result["path"] = _active_scene_path(node)
		return result

	var result := {
		"name": str(node.name),
		"type": str(node.get_class()),
		"path": _active_scene_path(node),
	}
	var script = node.get_script()
	if script != null:
		result["script"] = str(script.resource_path)
	if node is Node2D:
		result["position"] = {"x": float(node.position.x), "y": float(node.position.y)}
		result["rotation"] = float(node.rotation)
		result["scale"] = {"x": float(node.scale.x), "y": float(node.scale.y)}
	elif node is Node3D:
		result["position"] = {"x": float(node.position.x), "y": float(node.position.y), "z": float(node.position.z)}
		result["rotation"] = {"x": float(node.rotation.x), "y": float(node.rotation.y), "z": float(node.rotation.z)}
		result["scale"] = {"x": float(node.scale.x), "y": float(node.scale.y), "z": float(node.scale.z)}
	return result
