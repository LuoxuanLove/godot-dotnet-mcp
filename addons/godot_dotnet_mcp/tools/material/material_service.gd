@tool
extends "res://addons/godot_dotnet_mcp/tools/material/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"create":
			return _create_material(args)
		"get_info":
			return _get_material_info(str(args.get("path", "")))
		"assign_to_node":
			return _assign_material_to_node(str(args.get("material_path", "")), str(args.get("node_path", "")), int(args.get("surface", 0)))
		"duplicate":
			return _duplicate_material(str(args.get("path", "")), str(args.get("save_path", "")))
		"save":
			return _save_material(str(args.get("path", "")), str(args.get("save_path", "")))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _create_material(args: Dictionary) -> Dictionary:
	var type_name := str(args.get("type", "StandardMaterial3D"))
	var material_name := str(args.get("name", "NewMaterial"))

	var material: Material
	match type_name:
		"StandardMaterial3D":
			material = StandardMaterial3D.new()
		"ORMMaterial3D":
			material = ORMMaterial3D.new()
		"ShaderMaterial":
			material = ShaderMaterial.new()
		"CanvasItemMaterial":
			material = CanvasItemMaterial.new()
		_:
			return _error("Invalid material type: %s" % type_name)

	material.resource_name = material_name
	var save_path := str(args.get("save_path", ""))
	if save_path.is_empty():
		return _success({
			"type": type_name,
			"name": material_name,
			"note": "Material created in memory. Use 'save' to persist."
		}, "Material created")

	var normalized_save_path := save_path
	if not normalized_save_path.begins_with("res://"):
		normalized_save_path = "res://" + normalized_save_path
	if not normalized_save_path.ends_with(".tres") and not normalized_save_path.ends_with(".res"):
		normalized_save_path += ".tres"

	var error = ResourceSaver.save(material, normalized_save_path)
	if error != OK:
		return _error("Failed to save material: %s" % error_string(error))

	return _success({
		"type": type_name,
		"name": material_name,
		"path": normalized_save_path
	}, "Material created and saved")


func _get_material_info(path: String) -> Dictionary:
	var material = _load_material(path)
	if not material:
		return _error("Material not found: %s" % path)

	var info = {
		"type": str(material.get_class()),
		"name": str(material.resource_name),
		"path": str(material.resource_path) if material.resource_path else null
	}

	if material is StandardMaterial3D or material is ORMMaterial3D:
		info["albedo_color"] = _serialize_value(material.albedo_color)
		info["metallic"] = material.metallic
		info["roughness"] = material.roughness
		info["emission_enabled"] = material.emission_enabled
		if material.emission_enabled:
			info["emission"] = _serialize_value(material.emission)
			info["emission_energy_multiplier"] = material.emission_energy_multiplier
		info["normal_enabled"] = material.normal_enabled
		info["transparency"] = material.transparency
		info["cull_mode"] = material.cull_mode
		info["albedo_texture"] = str(material.albedo_texture.resource_path) if material.albedo_texture else null
		info["metallic_texture"] = str(material.metallic_texture.resource_path) if material.metallic_texture else null
		info["roughness_texture"] = str(material.roughness_texture.resource_path) if material.roughness_texture else null
		info["normal_texture"] = str(material.normal_texture.resource_path) if material.normal_texture else null
	elif material is ShaderMaterial:
		info["shader"] = str(material.shader.resource_path) if material.shader else null
	elif material is CanvasItemMaterial:
		info["blend_mode"] = material.blend_mode
		info["light_mode"] = material.light_mode
		info["particles_animation"] = material.particles_animation

	return _success(info)


func _assign_material_to_node(material_path: String, node_path: String, surface: int) -> Dictionary:
	if material_path.is_empty() or node_path.is_empty():
		return _error("Both material_path and node_path are required")

	var material = _load_material(material_path)
	if not material:
		return _error("Material not found: %s" % material_path)

	var node = _find_active_node(node_path)
	if not node:
		return _error("Node not found: %s" % node_path)

	if node is GeometryInstance3D:
		node.set_surface_override_material(surface, material)
		return _success({
			"node": node_path,
			"surface": surface,
			"material": material_path
		}, "Material assigned to surface %d" % surface)
	if node is MeshInstance2D:
		node.material = material
		return _success({
			"node": node_path,
			"material": material_path
		}, "Material assigned")
	if node is CanvasItem and "material" in node:
		node.material = material
		return _success({
			"node": node_path,
			"material": material_path
		}, "Material assigned")

	return _error("Node does not support material assignment")


func _duplicate_material(path: String, save_path: String) -> Dictionary:
	var material = _load_material(path)
	if not material:
		return _error("Material not found: %s" % path)

	var duplicated = material.duplicate(true)
	if save_path.is_empty():
		return _success({
			"original": path,
			"note": "Material duplicated in memory"
		}, "Material duplicated")

	var normalized_save_path := save_path
	if not normalized_save_path.begins_with("res://"):
		normalized_save_path = "res://" + normalized_save_path
	if not normalized_save_path.ends_with(".tres") and not normalized_save_path.ends_with(".res"):
		normalized_save_path += ".tres"

	var error = ResourceSaver.save(duplicated, normalized_save_path)
	if error != OK:
		return _error("Failed to save: %s" % error_string(error))

	return _success({
		"original": path,
		"duplicate": normalized_save_path
	}, "Material duplicated and saved")


func _save_material(path: String, save_path: String) -> Dictionary:
	var material = _load_material(path)
	if not material:
		return _error("Material not found: %s" % path)

	var resolved_save_path := save_path
	if resolved_save_path.is_empty():
		resolved_save_path = material.resource_path
	if resolved_save_path.is_empty():
		return _error("Save path is required")

	if not resolved_save_path.begins_with("res://"):
		resolved_save_path = "res://" + resolved_save_path
	if not resolved_save_path.ends_with(".tres") and not resolved_save_path.ends_with(".res"):
		resolved_save_path += ".tres"

	var error = ResourceSaver.save(material, resolved_save_path)
	if error != OK:
		return _error("Failed to save: %s" % error_string(error))

	return _success({"path": resolved_save_path}, "Material saved")
