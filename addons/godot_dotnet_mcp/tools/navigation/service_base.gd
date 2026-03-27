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
	var normalized := _normalize_node_path(path, root)
	if normalized.is_empty() or normalized == ".":
		return root
	if normalized.begins_with("/"):
		var absolute_node = root.get_node_or_null(NodePath(normalized))
		if absolute_node != null:
			return absolute_node
	return root.get_node_or_null(NodePath(normalized))


func _collect_navigation_regions(node: Node, result: Array[Dictionary], mode: String) -> void:
	if node is NavigationRegion3D and (mode == "3d" or mode.is_empty()):
		result.append({
			"path": _get_scene_path(node),
			"type": "NavigationRegion3D",
			"enabled": node.enabled,
			"has_mesh": node.navigation_mesh != null,
			"layers": node.navigation_layers
		})
	elif node is NavigationRegion2D and (mode == "2d" or mode.is_empty()):
		result.append({
			"path": _get_scene_path(node),
			"type": "NavigationRegion2D",
			"enabled": node.enabled,
			"has_polygon": node.navigation_polygon != null,
			"layers": node.navigation_layers
		})

	for child in node.get_children():
		if child is Node:
			_collect_navigation_regions(child, result, mode)


func _collect_navigation_agents(node: Node, result: Array[Dictionary], mode: String) -> void:
	if node is NavigationAgent3D and (mode == "3d" or mode.is_empty()):
		result.append({
			"path": _get_scene_path(node),
			"type": "NavigationAgent3D",
			"target_position": _serialize_value(node.target_position),
			"radius": node.radius,
			"height": node.height,
			"path_desired_distance": node.path_desired_distance,
			"target_desired_distance": node.target_desired_distance,
			"avoidance_enabled": node.avoidance_enabled
		})
	elif node is NavigationAgent2D and (mode == "2d" or mode.is_empty()):
		result.append({
			"path": _get_scene_path(node),
			"type": "NavigationAgent2D",
			"target_position": _serialize_value(node.target_position),
			"radius": node.radius,
			"path_desired_distance": node.path_desired_distance,
			"target_desired_distance": node.target_desired_distance,
			"avoidance_enabled": node.avoidance_enabled
		})

	for child in node.get_children():
		if child is Node:
			_collect_navigation_agents(child, result, mode)
