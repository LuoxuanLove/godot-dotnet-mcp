extends RefCounted

const ParticleExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/particle/executor.gd")

var _scene_root: Node3D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = ParticleExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/particle_tools.gd"):
		return _failure("particle_tools.gd should be removed once the split executor becomes the only stable entry.")

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 2:
		return _failure("Particle executor should expose 2 tool definitions after the split.")

	var expected_names := ["particles", "particle_material"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Particle executor is missing tool definition '%s'." % expected_name)

	var create_result: Dictionary = executor.execute("particles", {
		"action": "create",
		"type": "gpu_particles_3d",
		"parent": ".",
		"name": "EmitterNode"
	})
	if not bool(create_result.get("success", false)):
		return _failure("Particle create failed through the split emitter service.")

	var emitter_path := str(create_result.get("data", {}).get("path", ""))
	if emitter_path.is_empty():
		return _failure("Particle create did not return a usable emitter path.")

	var emitting_result: Dictionary = executor.execute("particles", {
		"action": "set_emitting",
		"path": emitter_path,
		"emitting": true
	})
	if not bool(emitting_result.get("success", false)):
		return _failure("Particle set_emitting failed through the split emitter service.")

	var amount_result: Dictionary = executor.execute("particles", {
		"action": "set_amount",
		"path": emitter_path,
		"amount": 64
	})
	if not bool(amount_result.get("success", false)):
		return _failure("Particle set_amount failed through the split emitter service.")

	var draw_order_result: Dictionary = executor.execute("particles", {
		"action": "set_draw_order",
		"path": emitter_path,
		"draw_order": "lifetime"
	})
	if not bool(draw_order_result.get("success", false)):
		return _failure("Particle set_draw_order failed through the split emitter service.")

	var info_result: Dictionary = executor.execute("particles", {
		"action": "get_info",
		"path": emitter_path
	})
	if not bool(info_result.get("success", false)):
		return _failure("Particle get_info failed through the split emitter service.")

	var material_create_result: Dictionary = executor.execute("particle_material", {
		"action": "create",
		"path": emitter_path
	})
	if not bool(material_create_result.get("success", false)):
		return _failure("Particle material create failed through the split process material service.")

	var gravity_result: Dictionary = executor.execute("particle_material", {
		"action": "set_gravity",
		"path": emitter_path,
		"gravity": {"x": 0.0, "y": -4.0, "z": 1.5}
	})
	if not bool(gravity_result.get("success", false)):
		return _failure("Particle material set_gravity failed through the split process material service.")

	var velocity_result: Dictionary = executor.execute("particle_material", {
		"action": "set_velocity",
		"path": emitter_path,
		"min": 2.0,
		"max": 5.0
	})
	if not bool(velocity_result.get("success", false)):
		return _failure("Particle material set_velocity failed through the split process material service.")

	var scale_result: Dictionary = executor.execute("particle_material", {
		"action": "set_scale",
		"path": emitter_path,
		"min": 0.5,
		"max": 1.25
	})
	if not bool(scale_result.get("success", false)):
		return _failure("Particle material set_scale failed through the split process material service.")

	var color_result: Dictionary = executor.execute("particle_material", {
		"action": "set_color",
		"path": emitter_path,
		"color": {"r": 1.0, "g": 0.4, "b": 0.2, "a": 1.0}
	})
	if not bool(color_result.get("success", false)):
		return _failure("Particle material set_color failed through the split process material service.")

	var box_result: Dictionary = executor.execute("particle_material", {
		"action": "set_emission_box",
		"path": emitter_path,
		"extents": {"x": 1.0, "y": 2.0, "z": 3.0}
	})
	if not bool(box_result.get("success", false)):
		return _failure("Particle material set_emission_box failed through the split process material service.")

	var material_info_result: Dictionary = executor.execute("particle_material", {
		"action": "get_info",
		"path": emitter_path
	})
	if not bool(material_info_result.get("success", false)):
		return _failure("Particle material get_info failed through the split process material service.")

	var convert_result: Dictionary = executor.execute("particles", {
		"action": "convert_to_cpu",
		"path": emitter_path
	})
	if not bool(convert_result.get("success", false)):
		return _failure("Particle convert_to_cpu failed through the split emitter service.")

	var cpu_path := str(convert_result.get("data", {}).get("cpu_path", ""))
	if cpu_path.is_empty():
		return _failure("Particle convert_to_cpu did not return a CPU particle path.")

	var invalid_shape_result: Dictionary = executor.execute("particle_material", {
		"action": "set_emission_shape",
		"path": emitter_path,
		"shape": "invalid_shape"
	})
	if bool(invalid_shape_result.get("success", false)):
		return _failure("Particle material invalid shape should fail through the split process material service.")

	return {
		"name": "particle_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"emitter_path": emitter_path,
			"cpu_path": cpu_path,
			"emitter_type": str(info_result.get("data", {}).get("type", "")),
			"material_type": str(material_info_result.get("data", {}).get("type", ""))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node3D:
	var root := Node3D.new()
	root.name = "ParticleToolExecutorContracts"
	tree.root.add_child(root)
	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "particle_tool_executor_contracts",
		"success": false,
		"error": message
	}
