@tool
extends "res://addons/godot_dotnet_mcp/tools/lighting/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"create":
			return _create_light(args)
		"get_info":
			return _get_light_info(args.get("path", ""))
		"set_color":
			return _set_light_color(args.get("path", ""), args.get("color", {}))
		"set_energy":
			return _set_light_property(args.get("path", ""), "light_energy", args.get("energy", 1.0))
		"set_shadow":
			return _set_light_property(args.get("path", ""), "shadow_enabled", args.get("enabled", true))
		"set_range":
			return _set_light_range(args.get("path", ""), args.get("range", 5.0))
		"set_angle":
			return _set_spot_angle(args.get("path", ""), args.get("angle", 45.0))
		"set_bake_mode":
			return _set_bake_mode(args.get("path", ""), args.get("bake_mode", "disabled"))
		"list":
			return _list_lights()
		_:
			return _error("Unknown action: %s" % action)


func _create_light(args: Dictionary) -> Dictionary:
	var light_type = args.get("type", "omni_light_3d")
	var parent_path = args.get("parent", "")
	var node_name = args.get("name", "")

	if parent_path.is_empty():
		return _error("Parent path is required")

	var parent = _find_active_node(parent_path)
	if not parent:
		return _error("Parent not found: %s" % parent_path)

	var light: Node
	match light_type:
		"directional_light_3d":
			light = DirectionalLight3D.new()
		"omni_light_3d":
			light = OmniLight3D.new()
		"spot_light_3d":
			light = SpotLight3D.new()
		"directional_light_2d":
			light = DirectionalLight2D.new()
		"point_light_2d":
			light = PointLight2D.new()
		_:
			return _error("Unknown light type: %s" % light_type)

	if node_name.is_empty():
		node_name = light_type.to_pascal_case()
	light.name = node_name

	parent.add_child(light)
	light.owner = _get_scene_owner()

	return _success({
		"path": _active_scene_path(light),
		"type": light_type,
		"name": node_name
	}, "Light created")


func _get_light_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	var info = {
		"path": _active_scene_path(node),
		"type": node.get_class()
	}

	if node is Light3D:
		info["color"] = _serialize_value(node.light_color)
		info["energy"] = node.light_energy
		info["shadow_enabled"] = node.shadow_enabled
		info["bake_mode"] = node.light_bake_mode
		if node is OmniLight3D:
			info["range"] = node.omni_range
			info["attenuation"] = node.omni_attenuation
		elif node is SpotLight3D:
			info["range"] = node.spot_range
			info["angle"] = node.spot_angle
			info["angle_attenuation"] = node.spot_angle_attenuation
		elif node is DirectionalLight3D:
			info["angular_distance"] = node.light_angular_distance
	elif node is Light2D:
		info["color"] = _serialize_value(node.color)
		info["energy"] = node.energy
		info["shadow_enabled"] = node.shadow_enabled
		if node is PointLight2D:
			info["texture_scale"] = node.texture_scale
	else:
		return _error("Node is not a Light")

	return _success(info)


func _set_light_color(path: String, color_dict: Dictionary) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	var color = Color(
		color_dict.get("r", 1.0),
		color_dict.get("g", 1.0),
		color_dict.get("b", 1.0),
		color_dict.get("a", 1.0)
	)

	if node is Light3D:
		node.light_color = color
	elif node is Light2D:
		node.color = color
	else:
		return _error("Node is not a Light")

	return _success({
		"path": _active_scene_path(node),
		"color": _serialize_value(color)
	}, "Light color set")


func _set_light_property(path: String, property: String, value) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	if node is Light2D and property == "light_energy":
		property = "energy"

	if not property in node:
		return _error("Property not found: %s" % property)

	node.set(property, value)
	return _success({
		"path": _active_scene_path(node),
		"property": property,
		"value": value
	}, "Light property set")


func _set_light_range(path: String, range_val: float) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	if node is OmniLight3D:
		node.omni_range = range_val
	elif node is SpotLight3D:
		node.spot_range = range_val
	else:
		return _error("Range is only available for OmniLight3D and SpotLight3D")

	return _success({
		"path": _active_scene_path(node),
		"range": range_val
	}, "Light range set")


func _set_spot_angle(path: String, angle: float) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not node is SpotLight3D:
		return _error("Angle is only available for SpotLight3D")

	node.spot_angle = angle
	return _success({
		"path": _active_scene_path(node),
		"angle": angle
	}, "Spot angle set")


func _set_bake_mode(path: String, mode: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not node is Light3D:
		return _error("Bake mode is only available for 3D lights")

	match mode:
		"disabled":
			node.light_bake_mode = Light3D.BAKE_DISABLED
		"static":
			node.light_bake_mode = Light3D.BAKE_STATIC
		"dynamic":
			node.light_bake_mode = Light3D.BAKE_DYNAMIC
		_:
			return _error("Unknown bake mode: %s" % mode)

	return _success({
		"path": _active_scene_path(node),
		"bake_mode": mode
	}, "Bake mode set")


func _list_lights() -> Dictionary:
	var root = _get_active_root()
	if not root:
		return _error("No scene open")

	var lights: Array[Dictionary] = []
	_find_lights(root, lights)
	return _success({
		"count": lights.size(),
		"lights": lights
	})


func _find_lights(node: Node, result: Array[Dictionary]) -> void:
	if node is Light3D or node is Light2D:
		var info = {
			"path": _active_scene_path(node),
			"type": node.get_class()
		}
		if node is Light3D:
			info["energy"] = node.light_energy
			info["shadow_enabled"] = node.shadow_enabled
		else:
			info["energy"] = node.energy
			info["shadow_enabled"] = node.shadow_enabled
		result.append(info)

	for child in node.get_children():
		_find_lights(child, result)
