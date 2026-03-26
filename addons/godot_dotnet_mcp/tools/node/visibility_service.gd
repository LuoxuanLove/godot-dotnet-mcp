@tool
extends "res://addons/godot_dotnet_mcp/tools/node/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	match action:
		"show":
			return _set_visible(node, true)
		"hide":
			return _set_visible(node, false)
		"toggle":
			return _toggle_visible(node)
		"is_visible":
			return _is_visible(node)
		"set_z_index":
			return _set_z_index(node, int(args.get("value", 0)))
		"set_z_relative":
			return _set_z_relative(node, bool(args.get("enabled", true)))
		"set_y_sort":
			return _set_y_sort(node, bool(args.get("enabled", true)))
		"set_modulate":
			return _set_modulate(node, args.get("color", {}))
		"set_self_modulate":
			return _set_self_modulate(node, args.get("color", {}))
		"set_visibility_layer":
			return _set_visibility_layer(node, int(args.get("value", 1)))
		_:
			return _error("Unknown action: %s" % action)


func _set_visible(node: Node, visible: bool) -> Dictionary:
	if node is CanvasItem or node is Node3D:
		node.visible = visible
		return _success({"path": _active_scene_path(node), "visible": node.visible}, "Visibility set")
	return _error("Node does not support visibility")


func _toggle_visible(node: Node) -> Dictionary:
	if node is CanvasItem or node is Node3D:
		node.visible = not node.visible
		return _success({"path": _active_scene_path(node), "visible": node.visible}, "Visibility toggled")
	return _error("Node does not support visibility")


func _is_visible(node: Node) -> Dictionary:
	if node is CanvasItem or node is Node3D:
		return _success({
			"path": _active_scene_path(node),
			"visible": node.visible,
			"visible_in_tree": node.is_visible_in_tree()
		})
	return _error("Node does not support visibility")


func _set_z_index(node: Node, z_index: int) -> Dictionary:
	if node is CanvasItem:
		node.z_index = z_index
		return _success({"path": _active_scene_path(node), "z_index": z_index}, "Z-index set")
	return _error("Node does not support z_index")


func _set_z_relative(node: Node, enabled: bool) -> Dictionary:
	if node is CanvasItem:
		node.z_as_relative = enabled
		return _success({"path": _active_scene_path(node), "z_as_relative": enabled}, "Relative z-index set")
	return _error("Node does not support relative z-index")


func _set_y_sort(node: Node, enabled: bool) -> Dictionary:
	if node is Node2D:
		node.y_sort_enabled = enabled
		return _success({"path": _active_scene_path(node), "y_sort_enabled": enabled}, "Y-sort set")
	return _error("Node does not support y-sort")


func _set_modulate(node: Node, color_dict: Dictionary) -> Dictionary:
	if not (node is CanvasItem):
		return _error("Node does not support modulate")
	var color := Color(
		float(color_dict.get("r", 1.0)),
		float(color_dict.get("g", 1.0)),
		float(color_dict.get("b", 1.0)),
		float(color_dict.get("a", 1.0))
	)
	node.modulate = color
	return _success({"path": _active_scene_path(node), "modulate": _serialize_value(color)}, "Modulate set")


func _set_self_modulate(node: Node, color_dict: Dictionary) -> Dictionary:
	if not (node is CanvasItem):
		return _error("Node does not support self_modulate")
	var color := Color(
		float(color_dict.get("r", 1.0)),
		float(color_dict.get("g", 1.0)),
		float(color_dict.get("b", 1.0)),
		float(color_dict.get("a", 1.0))
	)
	node.self_modulate = color
	return _success({"path": _active_scene_path(node), "self_modulate": _serialize_value(color)}, "Self modulate set")


func _set_visibility_layer(node: Node, layer: int) -> Dictionary:
	if node is VisualInstance3D:
		node.layers = layer
		return _success({"path": _active_scene_path(node), "visibility_layer": layer}, "Visibility layer set")
	if node is CanvasItem:
		node.visibility_layer = layer
		return _success({"path": _active_scene_path(node), "visibility_layer": layer}, "Visibility layer set")
	return _error("Node does not support visibility layers")
