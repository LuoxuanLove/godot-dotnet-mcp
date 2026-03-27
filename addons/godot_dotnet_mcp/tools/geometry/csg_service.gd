@tool
extends "res://addons/godot_dotnet_mcp/tools/geometry/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"create":
			return _create_csg(args)
		"get_info":
			return _get_csg_info(args.get("path", ""))
		"set_operation":
			return _set_csg_operation(args.get("path", ""), args.get("operation", ""))
		"set_material":
			return _set_csg_material(args.get("path", ""), args.get("material", ""))
		"set_size":
			return _set_csg_size(args)
		"set_use_collision":
			return _set_csg_collision(args.get("path", ""), args.get("use_collision", true))
		"bake_mesh":
			return _bake_csg_mesh(args.get("path", ""))
		"list":
			return _list_csg_nodes()
		_:
			return _error("Unknown action: %s" % action)


func _create_csg(args: Dictionary) -> Dictionary:
	var csg_type = args.get("type", "csg_box_3d")
	var parent_path = args.get("parent", "")
	var node_name = args.get("name", "")

	if parent_path.is_empty():
		return _error("Parent path is required")

	var parent = _find_active_node(parent_path)
	if not parent:
		return _error("Parent not found: %s" % parent_path)

	var csg: CSGShape3D
	match csg_type:
		"csg_box_3d":
			csg = CSGBox3D.new()
		"csg_sphere_3d":
			csg = CSGSphere3D.new()
		"csg_cylinder_3d":
			csg = CSGCylinder3D.new()
		"csg_torus_3d":
			csg = CSGTorus3D.new()
		"csg_polygon_3d":
			csg = CSGPolygon3D.new()
		"csg_mesh_3d":
			csg = CSGMesh3D.new()
		"csg_combiner_3d":
			csg = CSGCombiner3D.new()
		_:
			return _error("Unknown CSG type: %s" % csg_type)

	if node_name.is_empty():
		node_name = csg_type.to_pascal_case()
	csg.name = node_name
	parent.add_child(csg)
	csg.owner = _get_scene_owner()

	return _success({
		"path": _active_scene_path(csg),
		"type": csg_type,
		"name": node_name
	}, "CSG node created")


func _get_csg_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is CSGShape3D:
		return _error("CSG node not found: %s" % path)

	var info = {
		"path": _active_scene_path(node),
		"type": node.get_class(),
		"operation": node.operation,
		"use_collision": node.use_collision,
		"has_material": node.material != null
	}

	if node is CSGBox3D:
		info["size"] = _serialize_value(node.size)
	elif node is CSGSphere3D:
		info["radius"] = node.radius
		info["rings"] = node.rings
		info["radial_segments"] = node.radial_segments
	elif node is CSGCylinder3D:
		info["radius"] = node.radius
		info["height"] = node.height
		info["sides"] = node.sides
	elif node is CSGTorus3D:
		info["inner_radius"] = node.inner_radius
		info["outer_radius"] = node.outer_radius

	return _success(info)


func _set_csg_operation(path: String, operation: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is CSGShape3D:
		return _error("CSG node not found: %s" % path)

	match operation:
		"union":
			node.operation = CSGShape3D.OPERATION_UNION
		"intersection":
			node.operation = CSGShape3D.OPERATION_INTERSECTION
		"subtraction":
			node.operation = CSGShape3D.OPERATION_SUBTRACTION
		_:
			return _error("Unknown operation: %s" % operation)

	return _success({
		"path": _active_scene_path(node),
		"operation": operation
	}, "CSG operation set")


func _set_csg_material(path: String, material_path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is CSGShape3D:
		return _error("CSG node not found: %s" % path)

	if material_path.is_empty():
		node.material = null
	else:
		var material = load(material_path)
		if not material:
			return _error("Failed to load material: %s" % material_path)
		node.material = material

	return _success({
		"path": _active_scene_path(node),
		"material": material_path
	}, "Material set")


func _set_csg_size(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is CSGShape3D:
		return _error("CSG node not found: %s" % path)

	if node is CSGBox3D:
		var size = args.get("size", {})
		node.size = Vector3(size.get("x", node.size.x), size.get("y", node.size.y), size.get("z", node.size.z))
	elif node is CSGSphere3D:
		if args.has("radius"):
			node.radius = args.get("radius")
	elif node is CSGCylinder3D:
		if args.has("radius"):
			node.radius = args.get("radius")
		if args.has("height"):
			node.height = args.get("height")
	elif node is CSGTorus3D:
		if args.has("inner_radius"):
			node.inner_radius = args.get("inner_radius")
		if args.has("outer_radius"):
			node.outer_radius = args.get("outer_radius")
	else:
		return _error("Size not applicable for this CSG type")

	return _success({"path": _active_scene_path(node)}, "Size updated")


func _set_csg_collision(path: String, use_collision: bool) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is CSGShape3D:
		return _error("CSG node not found: %s" % path)

	node.use_collision = use_collision
	return _success({
		"path": _active_scene_path(node),
		"use_collision": use_collision
	}, "Collision %s" % ("enabled" if use_collision else "disabled"))


func _bake_csg_mesh(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is CSGShape3D:
		return _error("CSG node not found: %s" % path)

	var meshes = node.get_meshes()
	if meshes.is_empty():
		return _error("No mesh to bake")

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node.name + "_Baked"
	mesh_instance.mesh = meshes[1]
	mesh_instance.transform = meshes[0]
	node.get_parent().add_child(mesh_instance)
	mesh_instance.owner = _get_scene_owner()

	return _success({
		"original": _active_scene_path(node),
		"baked_path": _active_scene_path(mesh_instance)
	}, "CSG baked to mesh")


func _list_csg_nodes() -> Dictionary:
	var root = _get_active_root()
	if not root:
		return _error("No scene open")

	var nodes: Array[Dictionary] = []
	_find_csg_nodes(root, nodes)
	return _success({
		"count": nodes.size(),
		"nodes": nodes
	})


func _find_csg_nodes(node: Node, result: Array[Dictionary]) -> void:
	if node is CSGShape3D:
		result.append({
			"path": _active_scene_path(node),
			"type": node.get_class(),
			"operation": node.operation
		})

	for child in node.get_children():
		_find_csg_nodes(child, result)
