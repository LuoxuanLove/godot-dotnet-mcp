@tool
extends "res://addons/godot_dotnet_mcp/tools/physics/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"create":
			return _create_physics_body(args)
		"get_info":
			return _get_physics_body_info(args.get("path", ""))
		"set_mode":
			return _set_body_mode(args.get("path", ""), args.get("mode", ""))
		"set_mass":
			return _set_body_property(args.get("path", ""), "mass", args.get("mass", 1.0))
		"set_gravity_scale":
			return _set_body_property(args.get("path", ""), "gravity_scale", args.get("gravity_scale", 1.0))
		"set_linear_velocity":
			return _set_body_velocity(args.get("path", ""), args.get("velocity", {}), true)
		"set_angular_velocity":
			return _set_body_velocity(args.get("path", ""), args.get("velocity", {}), false)
		"apply_force":
			return _apply_body_force(args.get("path", ""), args.get("force", {}), args.get("position", {}), false)
		"apply_impulse":
			return _apply_body_force(args.get("path", ""), args.get("impulse", {}), args.get("position", {}), true)
		"set_layers":
			return _set_body_property(args.get("path", ""), "collision_layer", args.get("layers", 1))
		"set_mask":
			return _set_body_property(args.get("path", ""), "collision_mask", args.get("mask", 1))
		"freeze":
			return _set_body_property(args.get("path", ""), "freeze", args.get("frozen", true))
		_:
			return _error("Unknown action: %s" % action)


func _create_physics_body(args: Dictionary) -> Dictionary:
	var body_type = args.get("type", "")
	var parent_path = args.get("parent", "")
	var node_name = args.get("name", "")

	if body_type.is_empty():
		return _error("Body type is required")
	if parent_path.is_empty():
		return _error("Parent path is required")

	var parent = _find_active_node(parent_path)
	if not parent:
		return _error("Parent not found: %s" % parent_path)

	var body: Node
	match body_type:
		"rigid_body_2d":
			body = RigidBody2D.new()
		"rigid_body_3d":
			body = RigidBody3D.new()
		"character_body_2d":
			body = CharacterBody2D.new()
		"character_body_3d":
			body = CharacterBody3D.new()
		"static_body_2d":
			body = StaticBody2D.new()
		"static_body_3d":
			body = StaticBody3D.new()
		"area_2d":
			body = Area2D.new()
		"area_3d":
			body = Area3D.new()
		_:
			return _error("Unknown body type: %s" % body_type)

	if node_name.is_empty():
		node_name = body_type.to_pascal_case()
	body.name = node_name
	parent.add_child(body)
	body.owner = _get_scene_owner()

	return _success({
		"path": _active_scene_path(body),
		"type": body_type,
		"name": node_name
	}, "Physics body created")


func _get_physics_body_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	var info = {
		"path": _active_scene_path(node),
		"type": node.get_class(),
		"collision_layer": node.collision_layer if "collision_layer" in node else 0,
		"collision_mask": node.collision_mask if "collision_mask" in node else 0
	}

	if node is RigidBody3D:
		info["mass"] = node.mass
		info["gravity_scale"] = node.gravity_scale
		info["linear_velocity"] = _serialize_value(node.linear_velocity)
		info["angular_velocity"] = _serialize_value(node.angular_velocity)
		info["freeze"] = node.freeze
		info["freeze_mode"] = node.freeze_mode
		info["sleeping"] = node.sleeping
	elif node is RigidBody2D:
		info["mass"] = node.mass
		info["gravity_scale"] = node.gravity_scale
		info["linear_velocity"] = _serialize_value(node.linear_velocity)
		info["angular_velocity"] = node.angular_velocity
		info["freeze"] = node.freeze
		info["freeze_mode"] = node.freeze_mode
		info["sleeping"] = node.sleeping
	elif node is CharacterBody3D:
		info["velocity"] = _serialize_value(node.velocity)
		info["is_on_floor"] = node.is_on_floor()
		info["is_on_wall"] = node.is_on_wall()
		info["is_on_ceiling"] = node.is_on_ceiling()
	elif node is CharacterBody2D:
		info["velocity"] = _serialize_value(node.velocity)
		info["is_on_floor"] = node.is_on_floor()
		info["is_on_wall"] = node.is_on_wall()
		info["is_on_ceiling"] = node.is_on_ceiling()

	return _success(info)


func _set_body_mode(path: String, mode: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not (node is RigidBody2D or node is RigidBody3D):
		return _error("Node is not a RigidBody")

	var freeze_mode: int
	match mode:
		"static":
			freeze_mode = RigidBody3D.FREEZE_MODE_STATIC if node is RigidBody3D else RigidBody2D.FREEZE_MODE_STATIC
			node.freeze = true
		"kinematic":
			freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC if node is RigidBody3D else RigidBody2D.FREEZE_MODE_KINEMATIC
			node.freeze = true
		"rigid", "rigid_linear":
			node.freeze = false
		_:
			return _error("Unknown mode: %s" % mode)

	if mode in ["static", "kinematic"]:
		node.freeze_mode = freeze_mode

	return _success({
		"path": _active_scene_path(node),
		"mode": mode
	}, "Body mode set")


func _set_body_property(path: String, property: String, value) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not property in node:
		return _error("Property not found: %s" % property)

	node.set(property, value)
	return _success({
		"path": _active_scene_path(node),
		"property": property,
		"value": value
	}, "Property set")


func _set_body_velocity(path: String, velocity_dict: Dictionary, linear: bool) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	if node is RigidBody3D:
		var velocity_3d := Vector3(velocity_dict.get("x", 0), velocity_dict.get("y", 0), velocity_dict.get("z", 0))
		if linear:
			node.linear_velocity = velocity_3d
		else:
			node.angular_velocity = velocity_3d
	elif node is RigidBody2D:
		if linear:
			var velocity_2d := Vector2(velocity_dict.get("x", 0), velocity_dict.get("y", 0))
			node.linear_velocity = velocity_2d
		else:
			node.angular_velocity = velocity_dict.get("z", velocity_dict.get("value", 0))
	else:
		return _error("Node is not a RigidBody")

	return _success({
		"path": _active_scene_path(node),
		"velocity": velocity_dict,
		"type": "linear" if linear else "angular"
	}, "Velocity set")


func _apply_body_force(path: String, force_dict: Dictionary, position_dict: Dictionary, is_impulse: bool) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	if node is RigidBody3D:
		var force_3d := Vector3(force_dict.get("x", 0), force_dict.get("y", 0), force_dict.get("z", 0))
		var position_3d := Vector3(position_dict.get("x", 0), position_dict.get("y", 0), position_dict.get("z", 0))
		if is_impulse:
			if position_dict.is_empty():
				node.apply_central_impulse(force_3d)
			else:
				node.apply_impulse(force_3d, position_3d)
		else:
			if position_dict.is_empty():
				node.apply_central_force(force_3d)
			else:
				node.apply_force(force_3d, position_3d)
	elif node is RigidBody2D:
		var force_2d := Vector2(force_dict.get("x", 0), force_dict.get("y", 0))
		var position_2d := Vector2(position_dict.get("x", 0), position_dict.get("y", 0))
		if is_impulse:
			if position_dict.is_empty():
				node.apply_central_impulse(force_2d)
			else:
				node.apply_impulse(force_2d, position_2d)
		else:
			if position_dict.is_empty():
				node.apply_central_force(force_2d)
			else:
				node.apply_force(force_2d, position_2d)
	else:
		return _error("Node is not a RigidBody")

	return _success({
		"path": _active_scene_path(node),
		"force": force_dict,
		"position": position_dict,
		"type": "impulse" if is_impulse else "force"
	}, "%s applied" % ("Impulse" if is_impulse else "Force"))
