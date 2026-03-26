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
		"set_position":
			return _set_position(node, args)
		"set_rotation":
			return _set_rotation(node, args.get("radians", 0.0), args)
		"set_rotation_degrees":
			return _set_rotation(node, deg_to_rad(args.get("degrees", 0.0)), args)
		"set_scale":
			return _set_scale(node, args)
		"get_transform":
			return _get_transform(node)
		"move":
			return _move_node(node, args)
		"rotate":
			return _rotate_node(node, args)
		"look_at":
			return _look_at(node, args)
		"reset":
			return _reset_transform(node)
		_:
			return _error("Unknown action: %s" % action)


func _set_position(node: Node, args: Dictionary) -> Dictionary:
	var x = args.get("x", 0.0)
	var y = args.get("y", 0.0)
	var z = args.get("z", 0.0)
	var use_global = args.get("global", false)
	if not (x is float or x is int) or not (y is float or y is int) or not (z is float or z is int):
		return _error("Coordinates (x, y, z) must be numbers")
	if node is Node2D:
		if use_global:
			node.global_position = Vector2(x, y)
		else:
			node.position = Vector2(x, y)
	elif node is Node3D:
		if use_global:
			node.global_position = Vector3(x, y, z)
		else:
			node.position = Vector3(x, y, z)
	elif node is Control:
		if use_global:
			node.global_position = Vector2(x, y)
		else:
			node.position = Vector2(x, y)
	else:
		return _error("Node does not support position")
	return _success({"path": _active_scene_path(node), "position": _get_position_dict(node), "global": use_global}, "Position set")


func _set_rotation(node: Node, radians: float, args: Dictionary) -> Dictionary:
	var use_global = args.get("global", false)
	if node is Node2D:
		if use_global:
			node.global_rotation = radians
		else:
			node.rotation = radians
	elif node is Node3D:
		var rx = args.get("x", 0.0)
		var ry = args.get("y", 0.0)
		var rz = args.get("z", 0.0)
		if args.has("x") or args.has("y") or args.has("z"):
			if use_global:
				node.global_rotation = Vector3(rx, ry, rz)
			else:
				node.rotation = Vector3(rx, ry, rz)
		else:
			node.rotation.y = radians
	elif node is Control:
		node.rotation = radians
	else:
		return _error("Node does not support rotation")
	return _success({"path": _active_scene_path(node), "rotation": _get_rotation_dict(node)}, "Rotation set")


func _set_scale(node: Node, args: Dictionary) -> Dictionary:
	var x = args.get("x", 1.0)
	var y = args.get("y", 1.0)
	var z = args.get("z", 1.0)
	if node is Node2D:
		node.scale = Vector2(x, y)
	elif node is Node3D:
		node.scale = Vector3(x, y, z)
	elif node is Control:
		node.scale = Vector2(x, y)
	else:
		return _error("Node does not support scale")
	return _success({"path": _active_scene_path(node), "scale": _get_scale_dict(node)}, "Scale set")


func _get_transform(node: Node) -> Dictionary:
	var result = {"path": _active_scene_path(node)}
	if node is Node2D:
		result["position"] = {"x": node.position.x, "y": node.position.y}
		result["global_position"] = {"x": node.global_position.x, "y": node.global_position.y}
		result["rotation"] = node.rotation
		result["rotation_degrees"] = node.rotation_degrees
		result["scale"] = {"x": node.scale.x, "y": node.scale.y}
	elif node is Node3D:
		result["position"] = {"x": node.position.x, "y": node.position.y, "z": node.position.z}
		result["global_position"] = {"x": node.global_position.x, "y": node.global_position.y, "z": node.global_position.z}
		result["rotation"] = {"x": node.rotation.x, "y": node.rotation.y, "z": node.rotation.z}
		result["rotation_degrees"] = {"x": node.rotation_degrees.x, "y": node.rotation_degrees.y, "z": node.rotation_degrees.z}
		result["scale"] = {"x": node.scale.x, "y": node.scale.y, "z": node.scale.z}
	elif node is Control:
		result["position"] = {"x": node.position.x, "y": node.position.y}
		result["global_position"] = {"x": node.global_position.x, "y": node.global_position.y}
		result["rotation"] = node.rotation
		result["scale"] = {"x": node.scale.x, "y": node.scale.y}
		result["size"] = {"x": node.size.x, "y": node.size.y}
	else:
		return _error("Node does not support transform")
	return _success(result)


func _move_node(node: Node, args: Dictionary) -> Dictionary:
	var x = args.get("x", 0.0)
	var y = args.get("y", 0.0)
	var z = args.get("z", 0.0)
	if node is Node2D:
		node.position += Vector2(x, y)
	elif node is Node3D:
		node.position += Vector3(x, y, z)
	elif node is Control:
		node.position += Vector2(x, y)
	else:
		return _error("Node does not support position")
	return _success({"path": _active_scene_path(node), "new_position": _get_position_dict(node)}, "Node moved")


func _rotate_node(node: Node, args: Dictionary) -> Dictionary:
	var radians = args.get("radians", 0.0)
	if args.has("degrees"):
		radians = deg_to_rad(args.get("degrees", 0.0))
	if node is Node2D:
		node.rotation += radians
	elif node is Node3D:
		node.rotation.y += radians
	elif node is Control:
		node.rotation += radians
	else:
		return _error("Node does not support rotation")
	return _success({"path": _active_scene_path(node), "new_rotation": _get_rotation_dict(node)}, "Node rotated")


func _look_at(node: Node, args: Dictionary) -> Dictionary:
	var x = args.get("x", 0.0)
	var y = args.get("y", 0.0)
	var z = args.get("z", 0.0)
	if node is Node2D:
		node.look_at(Vector2(x, y))
	elif node is Node3D:
		node.look_at(Vector3(x, y, z))
	else:
		return _error("Node does not support look_at")
	return _success({"path": _active_scene_path(node), "looking_at": {"x": x, "y": y, "z": z}}, "Node looking at target")


func _reset_transform(node: Node) -> Dictionary:
	if node is Node2D:
		node.position = Vector2.ZERO
		node.rotation = 0
		node.scale = Vector2.ONE
	elif node is Node3D:
		node.position = Vector3.ZERO
		node.rotation = Vector3.ZERO
		node.scale = Vector3.ONE
	elif node is Control:
		node.position = Vector2.ZERO
		node.rotation = 0
		node.scale = Vector2.ONE
	else:
		return _error("Node does not support transform")
	return _success({"path": _active_scene_path(node)}, "Transform reset")


func _get_position_dict(node: Node) -> Dictionary:
	if node is Node2D or node is Control:
		return {"x": node.position.x, "y": node.position.y}
	if node is Node3D:
		return {"x": node.position.x, "y": node.position.y, "z": node.position.z}
	return {}


func _get_rotation_dict(node: Node) -> Variant:
	if node is Node2D or node is Control:
		return node.rotation
	if node is Node3D:
		return {"x": node.rotation.x, "y": node.rotation.y, "z": node.rotation.z}
	return 0


func _get_scale_dict(node: Node) -> Dictionary:
	if node is Node2D or node is Control:
		return {"x": node.scale.x, "y": node.scale.y}
	if node is Node3D:
		return {"x": node.scale.x, "y": node.scale.y, "z": node.scale.z}
	return {}
