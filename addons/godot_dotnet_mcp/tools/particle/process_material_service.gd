@tool
extends "res://addons/godot_dotnet_mcp/tools/particle/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))

	match action:
		"create":
			return _create_particle_material(str(args.get("path", "")))
		"get_info":
			return _get_material_info(str(args.get("path", "")))
		"set_direction":
			return _set_material_direction(str(args.get("path", "")), args.get("direction", {}))
		"set_spread":
			return _set_material_property(str(args.get("path", "")), "spread", args.get("spread", 45.0))
		"set_gravity":
			return _set_material_gravity(str(args.get("path", "")), args.get("gravity", {}))
		"set_velocity":
			return _set_material_velocity(str(args.get("path", "")), float(args.get("min", 0.0)), float(args.get("max", 0.0)))
		"set_angular_velocity":
			return _set_material_range(str(args.get("path", "")), "angular_velocity", float(args.get("min", 0.0)), float(args.get("max", 0.0)))
		"set_orbit_velocity":
			return _set_material_range(str(args.get("path", "")), "orbit_velocity", float(args.get("min", 0.0)), float(args.get("max", 0.0)))
		"set_linear_accel":
			return _set_material_range(str(args.get("path", "")), "linear_accel", float(args.get("min", 0.0)), float(args.get("max", 0.0)))
		"set_radial_accel":
			return _set_material_range(str(args.get("path", "")), "radial_accel", float(args.get("min", 0.0)), float(args.get("max", 0.0)))
		"set_tangential_accel":
			return _set_material_range(str(args.get("path", "")), "tangential_accel", float(args.get("min", 0.0)), float(args.get("max", 0.0)))
		"set_damping":
			return _set_material_range(str(args.get("path", "")), "damping", float(args.get("min", 0.0)), float(args.get("max", 0.0)))
		"set_scale":
			return _set_material_range(str(args.get("path", "")), "scale", float(args.get("min", 1.0)), float(args.get("max", 1.0)))
		"set_color":
			return _set_material_color(str(args.get("path", "")), args.get("color", {}))
		"set_emission_shape":
			return _set_emission_shape(str(args.get("path", "")), str(args.get("shape", "point")))
		"set_emission_sphere":
			return _set_emission_sphere(str(args.get("path", "")), float(args.get("radius", 1.0)))
		"set_emission_box":
			return _set_emission_box(str(args.get("path", "")), args.get("extents", {}))
		_:
			return _error("Unknown action: %s" % action)


func _create_particle_material(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not (node is GPUParticles2D or node is GPUParticles3D):
		return _error("Node is not a GPUParticles node")

	var material := ParticleProcessMaterial.new()
	node.process_material = material
	return _success({
		"path": path,
		"material_type": "ParticleProcessMaterial"
	}, "Particle material created")


func _get_material_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var material := _get_particle_process_material(node)
	if material == null:
		if node is CPUParticles2D or node is CPUParticles3D:
			return _success({
				"path": path,
				"type": "CPUParticles (no separate material)",
				"direction": _serialize_value(node.direction),
				"spread": node.spread,
				"gravity": _serialize_value(node.gravity),
				"initial_velocity_min": node.initial_velocity_min,
				"initial_velocity_max": node.initial_velocity_max,
				"scale_amount_min": node.scale_amount_min,
				"scale_amount_max": node.scale_amount_max,
				"color": _serialize_value(node.color)
			})
		return _error("No process material found")

	return _success({
		"path": path,
		"type": "ParticleProcessMaterial",
		"direction": _serialize_value(material.direction),
		"spread": material.spread,
		"flatness": material.flatness,
		"gravity": _serialize_value(material.gravity),
		"initial_velocity_min": material.initial_velocity_min,
		"initial_velocity_max": material.initial_velocity_max,
		"angular_velocity_min": material.angular_velocity_min,
		"angular_velocity_max": material.angular_velocity_max,
		"scale_min": material.scale_min,
		"scale_max": material.scale_max,
		"color": _serialize_value(material.color),
		"emission_shape": material.emission_shape
	})


func _set_material_direction(path: String, direction: Dictionary) -> Dictionary:
	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var value = _build_particle_vector(direction, node, 1.0)
	var material := _get_particle_process_material(node)

	if material != null:
		material.direction = value
	elif node is CPUParticles2D or node is CPUParticles3D:
		node.direction = value
	else:
		return _error("Node is not a particle emitter")

	return _success({
		"path": path,
		"direction": _serialize_value(value)
	}, "Direction set")


func _set_material_property(path: String, property: String, value) -> Dictionary:
	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var material := _get_particle_process_material(node)
	if material != null:
		if property in material:
			material.set(property, value)
		else:
			return _error("Property not found in material: %s" % property)
	elif node is CPUParticles2D or node is CPUParticles3D:
		if property in node:
			node.set(property, value)
		else:
			return _error("Property not found: %s" % property)
	else:
		return _error("Node is not a particle emitter")

	return _success({
		"path": path,
		"property": property,
		"value": value
	}, "Property set")


func _set_material_gravity(path: String, gravity: Dictionary) -> Dictionary:
	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var value = _build_particle_vector(gravity, node, -9.8)
	var material := _get_particle_process_material(node)

	if material != null:
		material.gravity = value
	elif node is CPUParticles2D or node is CPUParticles3D:
		node.gravity = value
	else:
		return _error("Node is not a particle emitter")

	return _success({
		"path": path,
		"gravity": _serialize_value(value)
	}, "Gravity set")


func _set_material_velocity(path: String, min_val: float, max_val: float) -> Dictionary:
	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var material := _get_particle_process_material(node)
	if material != null:
		material.initial_velocity_min = min_val
		material.initial_velocity_max = max_val
	elif node is CPUParticles2D or node is CPUParticles3D:
		node.initial_velocity_min = min_val
		node.initial_velocity_max = max_val
	else:
		return _error("Node is not a particle emitter")

	return _success({
		"path": path,
		"velocity_min": min_val,
		"velocity_max": max_val
	}, "Velocity set")


func _set_material_range(path: String, property: String, min_val: float, max_val: float) -> Dictionary:
	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var min_prop := property + "_min"
	var max_prop := property + "_max"
	if property == "scale":
		min_prop = "scale_amount_min" if (node is CPUParticles2D or node is CPUParticles3D) else "scale_min"
		max_prop = "scale_amount_max" if (node is CPUParticles2D or node is CPUParticles3D) else "scale_max"

	var material := _get_particle_process_material(node)
	if material != null:
		if min_prop in material:
			material.set(min_prop, min_val)
			material.set(max_prop, max_val)
		else:
			return _error("Property not found: %s" % property)
	elif node is CPUParticles2D or node is CPUParticles3D:
		if min_prop in node:
			node.set(min_prop, min_val)
			node.set(max_prop, max_val)
		else:
			return _error("Property not found: %s" % property)
	else:
		return _error("Node is not a particle emitter")

	return _success({
		"path": path,
		"property": property,
		"min": min_val,
		"max": max_val
	}, "%s range set" % property.capitalize())


func _set_material_color(path: String, color_dict: Dictionary) -> Dictionary:
	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var color := Color(
		color_dict.get("r", 1.0),
		color_dict.get("g", 1.0),
		color_dict.get("b", 1.0),
		color_dict.get("a", 1.0)
	)
	var material := _get_particle_process_material(node)

	if material != null:
		material.color = color
	elif node is CPUParticles2D or node is CPUParticles3D:
		node.color = color
	else:
		return _error("Node is not a particle emitter")

	return _success({
		"path": path,
		"color": _serialize_value(color)
	}, "Color set")


func _set_emission_shape(path: String, shape: String) -> Dictionary:
	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var material := _get_particle_process_material(node)
	var shape_enum := -1

	if material != null:
		match shape:
			"point":
				shape_enum = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			"sphere":
				shape_enum = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			"sphere_surface":
				shape_enum = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
			"box":
				shape_enum = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			"ring":
				shape_enum = ParticleProcessMaterial.EMISSION_SHAPE_RING
			_:
				return _error("Unknown shape: %s" % shape)
		material.emission_shape = shape_enum
	elif node is CPUParticles2D or node is CPUParticles3D:
		match shape:
			"point":
				shape_enum = CPUParticles3D.EMISSION_SHAPE_POINT if node is CPUParticles3D else CPUParticles2D.EMISSION_SHAPE_POINT
			"sphere":
				shape_enum = CPUParticles3D.EMISSION_SHAPE_SPHERE if node is CPUParticles3D else CPUParticles2D.EMISSION_SHAPE_SPHERE
			"sphere_surface":
				shape_enum = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE if node is CPUParticles3D else CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
			"box":
				shape_enum = CPUParticles3D.EMISSION_SHAPE_BOX if node is CPUParticles3D else CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			"ring":
				shape_enum = CPUParticles3D.EMISSION_SHAPE_RING if node is CPUParticles3D else CPUParticles2D.EMISSION_SHAPE_POINTS
			_:
				return _error("Unknown shape: %s" % shape)
		node.emission_shape = shape_enum
	else:
		return _error("Node is not a particle emitter")

	return _success({
		"path": path,
		"shape": shape
	}, "Emission shape set")


func _set_emission_sphere(path: String, radius: float) -> Dictionary:
	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var material := _get_particle_process_material(node)
	if material != null:
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = radius
	elif node is CPUParticles3D:
		node.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		node.emission_sphere_radius = radius
	elif node is CPUParticles2D:
		node.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		node.emission_sphere_radius = radius
	else:
		return _error("Node is not a particle emitter")

	return _success({
		"path": path,
		"shape": "sphere",
		"radius": radius
	}, "Sphere emission set")


func _set_emission_box(path: String, extents: Dictionary) -> Dictionary:
	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var ext := Vector3(extents.get("x", 1.0), extents.get("y", 1.0), extents.get("z", 1.0))
	var material := _get_particle_process_material(node)

	if material != null:
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		material.emission_box_extents = ext
	elif node is CPUParticles3D:
		node.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		node.emission_box_extents = ext
	elif node is CPUParticles2D:
		node.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		node.emission_rect_extents = Vector2(ext.x, ext.y)
	else:
		return _error("Node is not a particle emitter")

	return _success({
		"path": path,
		"shape": "box",
		"extents": _serialize_value(ext)
	}, "Box emission set")
