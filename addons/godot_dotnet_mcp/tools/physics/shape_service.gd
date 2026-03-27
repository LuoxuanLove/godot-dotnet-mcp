@tool
extends "res://addons/godot_dotnet_mcp/tools/physics/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"create":
			return _create_collision_shape(args)
		"get_info":
			return _get_shape_info(args.get("path", ""))
		"set_disabled":
			return _set_shape_disabled(args.get("path", ""), args.get("disabled", false))
		"create_box":
			return _create_box_shape(args)
		"create_sphere":
			return _create_sphere_shape(args)
		"create_capsule":
			return _create_capsule_shape(args)
		"create_cylinder":
			return _create_cylinder_shape(args)
		"create_polygon":
			return _create_polygon_shape(args)
		"set_size":
			return _set_shape_size(args)
		"make_convex_from_siblings":
			return _make_convex_from_siblings(args.get("path", ""))
		_:
			return _error("Unknown action: %s" % action)


func _create_collision_shape(args: Dictionary) -> Dictionary:
	var parent_path = args.get("parent", "")
	var node_name = args.get("name", "")
	var mode = args.get("mode", "")

	if parent_path.is_empty():
		return _error("Parent path is required")

	var parent = _find_active_node(parent_path)
	if not parent:
		return _error("Parent not found: %s" % parent_path)

	if mode.is_empty():
		mode = _detect_dimension_mode(parent)

	var shape_node: Node
	if mode == "2d":
		shape_node = CollisionShape2D.new()
		if node_name.is_empty():
			node_name = "CollisionShape2D"
	else:
		shape_node = CollisionShape3D.new()
		if node_name.is_empty():
			node_name = "CollisionShape3D"

	shape_node.name = node_name
	parent.add_child(shape_node)
	shape_node.owner = _get_scene_owner()

	var size_example = {"x": 1, "y": 1} if mode == "2d" else {"x": 1, "y": 1, "z": 1}
	return _success({
		"path": _active_scene_path(shape_node),
		"mode": mode,
		"name": node_name,
		"warning": "CollisionShape has no shape until you assign one.",
		"next_step": "Use create_box, create_sphere, create_capsule, create_cylinder, or create_polygon.",
		"example": {"action": "create_box", "path": _active_scene_path(shape_node), "size": size_example}
	}, "Collision shape node created")


func _get_shape_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	var info = {
		"path": _active_scene_path(node),
		"type": node.get_class(),
		"disabled": node.disabled if "disabled" in node else false
	}

	if node is CollisionShape3D and node.shape:
		info["shape_type"] = node.shape.get_class()
		if node.shape is BoxShape3D:
			info["size"] = _serialize_value(node.shape.size)
		elif node.shape is SphereShape3D:
			info["radius"] = node.shape.radius
		elif node.shape is CapsuleShape3D or node.shape is CylinderShape3D:
			info["radius"] = node.shape.radius
			info["height"] = node.shape.height
	elif node is CollisionShape2D and node.shape:
		info["shape_type"] = node.shape.get_class()
		if node.shape is RectangleShape2D:
			info["size"] = _serialize_value(node.shape.size)
		elif node.shape is CircleShape2D:
			info["radius"] = node.shape.radius
		elif node.shape is CapsuleShape2D:
			info["radius"] = node.shape.radius
			info["height"] = node.shape.height

	return _success(info)


func _set_shape_disabled(path: String, disabled: bool) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not (node is CollisionShape2D or node is CollisionShape3D):
		return _error("Node is not a CollisionShape")

	node.disabled = disabled
	return _success({
		"path": _active_scene_path(node),
		"disabled": disabled
	}, "Shape %s" % ("disabled" if disabled else "enabled"))


func _create_box_shape(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var size_dict = args.get("size", {"x": 1, "y": 1, "z": 1})

	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	if node is CollisionShape3D:
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(size_dict.get("x", 1), size_dict.get("y", 1), size_dict.get("z", 1))
		node.shape = box_shape
	elif node is CollisionShape2D:
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(size_dict.get("x", 1), size_dict.get("y", 1))
		node.shape = rect_shape
	else:
		return _error("Node is not a CollisionShape")

	return _success({
		"path": _active_scene_path(node),
		"shape": "box",
		"size": size_dict
	}, "Box shape created")


func _create_sphere_shape(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var radius = args.get("radius", 0.5)

	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	if node is CollisionShape3D:
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = radius
		node.shape = sphere_shape
	elif node is CollisionShape2D:
		var circle_shape := CircleShape2D.new()
		circle_shape.radius = radius
		node.shape = circle_shape
	else:
		return _error("Node is not a CollisionShape")

	return _success({
		"path": _active_scene_path(node),
		"shape": "sphere",
		"radius": radius
	}, "Sphere shape created")


func _create_capsule_shape(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var radius = args.get("radius", 0.5)
	var height = args.get("height", 2.0)

	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	if node is CollisionShape3D:
		var capsule_shape_3d := CapsuleShape3D.new()
		capsule_shape_3d.radius = radius
		capsule_shape_3d.height = height
		node.shape = capsule_shape_3d
	elif node is CollisionShape2D:
		var capsule_shape_2d := CapsuleShape2D.new()
		capsule_shape_2d.radius = radius
		capsule_shape_2d.height = height
		node.shape = capsule_shape_2d
	else:
		return _error("Node is not a CollisionShape")

	return _success({
		"path": _active_scene_path(node),
		"shape": "capsule",
		"radius": radius,
		"height": height
	}, "Capsule shape created")


func _create_cylinder_shape(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var radius = args.get("radius", 0.5)
	var height = args.get("height", 2.0)

	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not node is CollisionShape3D:
		return _error("Cylinder shape is only available for 3D")

	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = radius
	cylinder_shape.height = height
	node.shape = cylinder_shape

	return _success({
		"path": _active_scene_path(node),
		"shape": "cylinder",
		"radius": radius,
		"height": height
	}, "Cylinder shape created")


func _create_polygon_shape(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var points = args.get("points", [])

	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not node is CollisionShape2D:
		return _error("Polygon shape is only available for 2D")

	var shape := ConvexPolygonShape2D.new()
	var point_array: PackedVector2Array = []
	for point_value in points:
		point_array.append(Vector2(point_value.get("x", 0), point_value.get("y", 0)))
	shape.points = point_array
	node.shape = shape

	return _success({
		"path": _active_scene_path(node),
		"shape": "polygon",
		"point_count": points.size()
	}, "Polygon shape created")


func _set_shape_size(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")

	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not (node is CollisionShape2D or node is CollisionShape3D):
		return _error("Node is not a CollisionShape")
	if not node.shape:
		return _error("Shape has no shape resource")

	var shape = node.shape
	if shape is BoxShape3D:
		var size_3d = args.get("size", {})
		shape.size = Vector3(size_3d.get("x", shape.size.x), size_3d.get("y", shape.size.y), size_3d.get("z", shape.size.z))
	elif shape is RectangleShape2D:
		var size_2d = args.get("size", {})
		shape.size = Vector2(size_2d.get("x", shape.size.x), size_2d.get("y", shape.size.y))
	elif shape is SphereShape3D or shape is CircleShape2D:
		shape.radius = args.get("radius", shape.radius)
	elif shape is CapsuleShape3D or shape is CapsuleShape2D or shape is CylinderShape3D:
		if args.has("radius"):
			shape.radius = args.get("radius")
		if args.has("height"):
			shape.height = args.get("height")
	else:
		return _error("Unsupported shape type for resizing")

	return _success({
		"path": _active_scene_path(node),
		"shape_type": shape.get_class()
	}, "Shape size updated")


func _make_convex_from_siblings(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not node is CollisionShape3D:
		return _error("Only CollisionShape3D supports this operation")

	var parent = node.get_parent()
	var mesh_instance: MeshInstance3D = null
	for sibling in parent.get_children():
		if sibling is MeshInstance3D and sibling.mesh:
			mesh_instance = sibling
			break

	if not mesh_instance:
		return _error("No MeshInstance3D sibling found")

	node.shape = mesh_instance.mesh.create_convex_shape()
	return _success({
		"path": _active_scene_path(node),
		"mesh_source": _active_scene_path(mesh_instance)
	}, "Convex shape created from mesh")
