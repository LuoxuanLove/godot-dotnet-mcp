@tool
extends "res://addons/godot_dotnet_mcp/tools/physics/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"create":
			return _create_joint(args)
		"get_info":
			return _get_joint_info(args.get("path", ""))
		"set_nodes":
			return _set_joint_nodes(args.get("path", ""), args.get("node_a", ""), args.get("node_b", ""))
		"set_param":
			return _set_joint_param(args.get("path", ""), args.get("param", ""), args.get("value"))
		"get_param":
			return _get_joint_param(args.get("path", ""), args.get("param", ""))
		_:
			return _error("Unknown action: %s" % action)


func _create_joint(args: Dictionary) -> Dictionary:
	var joint_type = args.get("type", "")
	var parent_path = args.get("parent", "")
	var node_name = args.get("name", "")

	if joint_type.is_empty():
		return _error("Joint type is required")
	if parent_path.is_empty():
		return _error("Parent path is required")

	var parent = _find_active_node(parent_path)
	if not parent:
		return _error("Parent not found: %s" % parent_path)

	var joint: Node
	match joint_type:
		"pin_joint_2d":
			joint = PinJoint2D.new()
		"groove_joint_2d":
			joint = GrooveJoint2D.new()
		"damped_spring_joint_2d":
			joint = DampedSpringJoint2D.new()
		"pin_joint_3d":
			joint = PinJoint3D.new()
		"hinge_joint_3d":
			joint = HingeJoint3D.new()
		"slider_joint_3d":
			joint = SliderJoint3D.new()
		"cone_twist_joint_3d":
			joint = ConeTwistJoint3D.new()
		"generic_6dof_joint_3d":
			joint = Generic6DOFJoint3D.new()
		_:
			return _error("Unknown joint type: %s" % joint_type)

	if node_name.is_empty():
		node_name = joint_type.to_pascal_case()
	joint.name = node_name
	parent.add_child(joint)
	joint.owner = _get_scene_owner()

	return _success({
		"path": _active_scene_path(joint),
		"type": joint_type,
		"name": node_name
	}, "Joint created")


func _get_joint_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	var info = {
		"path": _active_scene_path(node),
		"type": node.get_class()
	}

	if node is Joint2D:
		info["node_a"] = str(node.node_a) if node.node_a else ""
		info["node_b"] = str(node.node_b) if node.node_b else ""
		info["bias"] = node.bias
		info["disable_collision"] = node.disable_collision
	elif node is Joint3D:
		info["node_a"] = str(node.node_a) if node.node_a else ""
		info["node_b"] = str(node.node_b) if node.node_b else ""
		info["exclude_from_collision"] = node.exclude_nodes_from_collision

	return _success(info)


func _set_joint_nodes(path: String, node_a_path: String, node_b_path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not (node is Joint2D or node is Joint3D):
		return _error("Node is not a Joint")

	if not node_a_path.is_empty():
		node.node_a = NodePath(node_a_path)
	if not node_b_path.is_empty():
		node.node_b = NodePath(node_b_path)

	return _success({
		"path": _active_scene_path(node),
		"node_a": node_a_path,
		"node_b": node_b_path
	}, "Joint nodes set")


func _set_joint_param(path: String, param: String, value) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if param.is_empty():
		return _error("Parameter name is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	var property_name = param.replace("/", "_")
	if not property_name in node:
		return _error("Parameter not found: %s" % param)

	node.set(property_name, value)
	return _success({
		"path": _active_scene_path(node),
		"param": param,
		"value": value
	}, "Joint parameter set")


func _get_joint_param(path: String, param: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if param.is_empty():
		return _error("Parameter name is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	var property_name = param.replace("/", "_")
	if not property_name in node:
		return _error("Parameter not found: %s" % param)

	return _success({
		"path": _active_scene_path(node),
		"param": param,
		"value": node.get(property_name)
	})
