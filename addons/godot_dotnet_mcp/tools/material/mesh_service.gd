@tool
extends "res://addons/godot_dotnet_mcp/tools/material/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"get_info":
			return _get_mesh_info(args)
		"list_surfaces":
			return _list_mesh_surfaces(args)
		"get_surface_material":
			return _get_surface_material(args)
		"set_surface_material":
			return _set_surface_material(args)
		"create_primitive":
			return _create_primitive_mesh(args)
		"get_aabb":
			return _get_mesh_aabb(args)
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _get_mesh_info(args: Dictionary) -> Dictionary:
	var mesh = _get_mesh(str(args.get("path", "")), str(args.get("mesh_path", "")))
	if not mesh:
		return _error("Mesh not found")

	var info = {
		"type": str(mesh.get_class()),
		"path": str(mesh.resource_path) if mesh.resource_path else null,
		"surface_count": mesh.get_surface_count()
	}
	var aabb = mesh.get_aabb()
	info["aabb"] = {
		"position": _serialize_value(aabb.position),
		"size": _serialize_value(aabb.size)
	}

	if mesh is BoxMesh:
		info["size"] = _serialize_value(mesh.size)
	elif mesh is SphereMesh:
		info["radius"] = mesh.radius
		info["height"] = mesh.height
	elif mesh is CylinderMesh:
		info["top_radius"] = mesh.top_radius
		info["bottom_radius"] = mesh.bottom_radius
		info["height"] = mesh.height
	elif mesh is CapsuleMesh:
		info["radius"] = mesh.radius
		info["height"] = mesh.height
	elif mesh is PlaneMesh:
		info["size"] = _serialize_value(mesh.size)
	elif mesh is TorusMesh:
		info["inner_radius"] = mesh.inner_radius
		info["outer_radius"] = mesh.outer_radius

	var surfaces: Array[Dictionary] = []
	for index in range(mesh.get_surface_count()):
		var material = mesh.surface_get_material(index)
		surfaces.append({
			"index": index,
			"material": str(material.resource_path) if material and material.resource_path else str(material) if material else null
		})
	info["surfaces"] = surfaces
	return _success(info)


func _list_mesh_surfaces(args: Dictionary) -> Dictionary:
	var mesh = _get_mesh(str(args.get("path", "")), str(args.get("mesh_path", "")))
	if not mesh:
		return _error("Mesh not found")

	var surfaces: Array[Dictionary] = []
	for index in range(mesh.get_surface_count()):
		var material = mesh.surface_get_material(index)
		var surface_info := {
			"index": index,
			"primitive_type": mesh.surface_get_primitive_type(index),
			"material": null
		}
		if material:
			surface_info["material"] = {
				"type": str(material.get_class()),
				"path": str(material.resource_path) if material.resource_path else null
			}
		surfaces.append(surface_info)

	return _success({
		"count": surfaces.size(),
		"surfaces": surfaces
	})


func _get_surface_material(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var surface := int(args.get("surface", 0))
	if path.is_empty():
		return _error("Node path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	var material: Material = null
	if node is GeometryInstance3D:
		material = node.get_surface_override_material(surface)
		if not material and node is MeshInstance3D and node.mesh and surface < node.mesh.get_surface_count():
			material = node.mesh.surface_get_material(surface)

	if material:
		return _success({
			"surface": surface,
			"material": {
				"type": str(material.get_class()),
				"path": str(material.resource_path) if material.resource_path else null
			}
		})

	return _success({
		"surface": surface,
		"material": null
	})


func _set_surface_material(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var surface := int(args.get("surface", 0))
	var material_path := str(args.get("material_path", ""))
	if path.is_empty():
		return _error("Node path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not (node is GeometryInstance3D):
		return _error("Node is not a GeometryInstance3D")

	var material: Material = null
	if not material_path.is_empty():
		material = _load_material(material_path)
		if not material:
			return _error("Material not found: %s" % material_path)

	node.set_surface_override_material(surface, material)
	return _success({
		"node": path,
		"surface": surface,
		"material": material_path if material else null
	}, "Surface material set")


func _create_primitive_mesh(args: Dictionary) -> Dictionary:
	var primitive_type := str(args.get("type", "box"))
	var mesh: Mesh

	match primitive_type:
		"box":
			var box := BoxMesh.new()
			var size = args.get("size", {"x": 1, "y": 1, "z": 1})
			box.size = Vector3(size.get("x", 1), size.get("y", 1), size.get("z", 1))
			mesh = box
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = float(args.get("radius", 0.5))
			sphere.height = float(args.get("height", 1.0))
			mesh = sphere
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = float(args.get("top_radius", args.get("radius", 0.5)))
			cylinder.bottom_radius = float(args.get("bottom_radius", args.get("radius", 0.5)))
			cylinder.height = float(args.get("height", 2.0))
			mesh = cylinder
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = float(args.get("radius", 0.5))
			capsule.height = float(args.get("height", 2.0))
			mesh = capsule
		"plane":
			var plane := PlaneMesh.new()
			var plane_size = args.get("size", {"x": 2, "y": 2})
			plane.size = Vector2(plane_size.get("x", 2), plane_size.get("y", 2))
			mesh = plane
		"prism":
			var prism := PrismMesh.new()
			prism.left_to_right = float(args.get("left_to_right", 0.5))
			var prism_size = args.get("size", {"x": 1, "y": 1, "z": 1})
			prism.size = Vector3(prism_size.get("x", 1), prism_size.get("y", 1), prism_size.get("z", 1))
			mesh = prism
		"torus":
			var torus := TorusMesh.new()
			torus.inner_radius = float(args.get("inner_radius", 0.5))
			torus.outer_radius = float(args.get("outer_radius", 1.0))
			mesh = torus
		"quad":
			var quad := QuadMesh.new()
			var quad_size = args.get("size", {"x": 1, "y": 1})
			quad.size = Vector2(quad_size.get("x", 1), quad_size.get("y", 1))
			mesh = quad
		_:
			return _error("Invalid primitive type: %s" % primitive_type)

	var save_path := str(args.get("save_path", ""))
	if not save_path.is_empty():
		var normalized_save_path := save_path
		if not normalized_save_path.begins_with("res://"):
			normalized_save_path = "res://" + normalized_save_path
		if not normalized_save_path.ends_with(".tres") and not normalized_save_path.ends_with(".res"):
			normalized_save_path += ".tres"

		var save_error = ResourceSaver.save(mesh, normalized_save_path)
		if save_error != OK:
			return _error("Failed to save: %s" % error_string(save_error))
		return _success({
			"type": primitive_type,
			"mesh_type": str(mesh.get_class()),
			"path": normalized_save_path
		}, "Primitive mesh created and saved")

	var node_path := str(args.get("node_path", ""))
	if not node_path.is_empty():
		var node = _find_active_node(node_path)
		if node is MeshInstance3D or node is MeshInstance2D:
			node.mesh = mesh
			return _success({
				"type": primitive_type,
				"mesh_type": str(mesh.get_class()),
				"assigned_to": node_path
			}, "Primitive mesh created and assigned")

	return _success({
		"type": primitive_type,
		"mesh_type": str(mesh.get_class()),
		"note": "Mesh created in memory"
	}, "Primitive mesh created")


func _get_mesh_aabb(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if path.is_empty():
		return _error("Node path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)

	var aabb: AABB
	if node is MeshInstance3D and node.mesh:
		aabb = node.mesh.get_aabb()
	elif node is VisualInstance3D:
		aabb = node.get_aabb()
	else:
		return _error("Node does not have an AABB")

	return _success({
		"aabb": {
			"position": _serialize_value(aabb.position),
			"size": _serialize_value(aabb.size),
			"end": _serialize_value(aabb.end)
		}
	})
