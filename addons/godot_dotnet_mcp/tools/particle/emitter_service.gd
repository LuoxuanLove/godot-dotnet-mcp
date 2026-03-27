@tool
extends "res://addons/godot_dotnet_mcp/tools/particle/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))

	match action:
		"create":
			return _create_particles(args)
		"get_info":
			return _get_particles_info(str(args.get("path", "")))
		"set_emitting":
			return _set_particle_property(str(args.get("path", "")), "emitting", args.get("emitting", true))
		"restart":
			return _restart_particles(str(args.get("path", "")))
		"set_amount":
			return _set_particle_property(str(args.get("path", "")), "amount", args.get("amount", 8))
		"set_lifetime":
			return _set_particle_property(str(args.get("path", "")), "lifetime", args.get("lifetime", 1.0))
		"set_one_shot":
			return _set_particle_property(str(args.get("path", "")), "one_shot", args.get("one_shot", false))
		"set_explosiveness":
			return _set_particle_property(str(args.get("path", "")), "explosiveness", args.get("explosiveness", 0.0))
		"set_randomness":
			return _set_particle_property(str(args.get("path", "")), "randomness", args.get("randomness", 0.0))
		"set_speed_scale":
			return _set_particle_property(str(args.get("path", "")), "speed_scale", args.get("speed_scale", 1.0))
		"set_draw_order":
			return _set_draw_order(str(args.get("path", "")), str(args.get("draw_order", "index")))
		"convert_to_cpu":
			return _convert_to_cpu(str(args.get("path", "")))
		_:
			return _error("Unknown action: %s" % action)


func _create_particles(args: Dictionary) -> Dictionary:
	var particle_type := str(args.get("type", "gpu_particles_3d"))
	var parent_path := str(args.get("parent", ""))
	var node_name := str(args.get("name", ""))

	if parent_path.is_empty():
		return _error("Parent path is required")

	var parent := _find_active_node(parent_path)
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var particles: Node = null
	match particle_type:
		"gpu_particles_2d":
			particles = GPUParticles2D.new()
		"gpu_particles_3d":
			particles = GPUParticles3D.new()
		"cpu_particles_2d":
			particles = CPUParticles2D.new()
		"cpu_particles_3d":
			particles = CPUParticles3D.new()
		_:
			return _error("Unknown particle type: %s" % particle_type)

	if node_name.is_empty():
		node_name = particle_type.to_pascal_case()
	particles.name = node_name

	if particles is GPUParticles2D or particles is GPUParticles3D:
		var material := ParticleProcessMaterial.new()
		material.direction = Vector3(0, 1, 0) if particles is GPUParticles3D else Vector3(0, -1, 0)
		material.gravity = Vector3(0, -9.8, 0) if particles is GPUParticles3D else Vector3(0, 98, 0)
		particles.process_material = material

	parent.add_child(particles)
	particles.owner = _get_scene_owner()

	return _success({
		"path": _active_scene_path(particles),
		"type": particle_type,
		"name": node_name
	}, "Particle emitter created")


func _get_particles_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not _is_particle_emitter(node):
		return _error("Node is not a particle emitter")

	var info := {
		"path": path,
		"type": node.get_class()
	}

	if node is GPUParticles2D or node is GPUParticles3D:
		info["emitting"] = node.emitting
		info["amount"] = node.amount
		info["lifetime"] = node.lifetime
		info["one_shot"] = node.one_shot
		info["preprocess"] = node.preprocess
		info["speed_scale"] = node.speed_scale
		info["explosiveness"] = node.explosiveness
		info["randomness"] = node.randomness
		info["fixed_fps"] = node.fixed_fps
		info["interpolate"] = node.interpolate
		info["has_process_material"] = node.process_material != null
		info["has_draw_passes"] = node.draw_passes > 0 if node is GPUParticles3D else (node.texture != null)
	elif node is CPUParticles2D or node is CPUParticles3D:
		info["emitting"] = node.emitting
		info["amount"] = node.amount
		info["lifetime"] = node.lifetime
		info["one_shot"] = node.one_shot
		info["preprocess"] = node.preprocess
		info["speed_scale"] = node.speed_scale
		info["explosiveness"] = node.explosiveness
		info["randomness"] = node.randomness
		info["direction"] = _serialize_value(node.direction)
		info["spread"] = node.spread
		info["gravity"] = _serialize_value(node.gravity)

	return _success(info)


func _set_particle_property(path: String, property: String, value) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not property in node:
		return _error("Property not found: %s" % property)

	node.set(property, value)
	return _success({
		"path": path,
		"property": property,
		"value": value
	}, "Property set")


func _restart_particles(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not _is_particle_emitter(node):
		return _error("Node is not a particle emitter")

	node.restart()
	return _success({"path": path}, "Particles restarted")


func _set_draw_order(path: String, order: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	if node is GPUParticles3D:
		match order:
			"index":
				node.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
			"lifetime":
				node.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
			"reverse_lifetime":
				node.draw_order = GPUParticles3D.DRAW_ORDER_REVERSE_LIFETIME
			"view_depth":
				node.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
			_:
				return _error("Unknown draw order: %s" % order)
	elif node is GPUParticles2D:
		match order:
			"index":
				node.draw_order = GPUParticles2D.DRAW_ORDER_INDEX
			"lifetime":
				node.draw_order = GPUParticles2D.DRAW_ORDER_LIFETIME
			"reverse_lifetime":
				node.draw_order = GPUParticles2D.DRAW_ORDER_REVERSE_LIFETIME
			_:
				return _error("Unknown draw order: %s" % order)
	else:
		return _error("Draw order only available for GPUParticles")

	return _success({
		"path": path,
		"draw_order": order
	}, "Draw order set")


func _convert_to_cpu(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node := _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	if node is GPUParticles3D:
		var cpu := CPUParticles3D.new()
		cpu.name = node.name + "_CPU"
		cpu.convert_from_particles(node)
		node.get_parent().add_child(cpu)
		cpu.owner = _get_scene_owner()
		cpu.global_transform = node.global_transform
		return _success({
			"original": path,
			"cpu_path": _active_scene_path(cpu)
		}, "Converted to CPUParticles3D")

	if node is GPUParticles2D:
		var cpu2d := CPUParticles2D.new()
		cpu2d.name = node.name + "_CPU"
		cpu2d.convert_from_particles(node)
		node.get_parent().add_child(cpu2d)
		cpu2d.owner = _get_scene_owner()
		cpu2d.global_transform = node.global_transform
		return _success({
			"original": path,
			"cpu_path": _active_scene_path(cpu2d)
		}, "Converted to CPUParticles2D")

	return _error("Node is not a GPUParticles node")
