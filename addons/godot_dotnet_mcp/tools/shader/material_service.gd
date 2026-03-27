@tool
extends "res://addons/godot_dotnet_mcp/tools/shader/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"create":
			return _create_shader_material(args)
		"get_info":
			return _get_shader_material_info(str(args.get("path", "")))
		"set_shader":
			return _set_material_shader(str(args.get("path", "")), str(args.get("shader_path", "")))
		"get_param":
			return _get_shader_param(str(args.get("path", "")), str(args.get("param", "")))
		"set_param":
			return _set_shader_param(str(args.get("path", "")), str(args.get("param", "")), args.get("value"))
		"list_params":
			return _list_shader_params(str(args.get("path", "")))
		"assign_to_node":
			return _assign_shader_material(str(args.get("material_path", "")), str(args.get("node_path", "")), int(args.get("surface", 0)))
		_:
			return _error("Unknown action: %s" % action)


func _create_shader_material(args: Dictionary) -> Dictionary:
	var shader_path := str(args.get("shader_path", ""))
	var save_path := str(args.get("save_path", ""))
	var material := ShaderMaterial.new()

	if not shader_path.is_empty():
		var shader = _load_shader(shader_path)
		if shader == null:
			return _error("Shader not found: %s" % shader_path)
		material.shader = shader

	if save_path.is_empty():
		return _success({
			"shader": shader_path if not shader_path.is_empty() else null,
			"note": "Material created in memory"
		}, "ShaderMaterial created")

	var resource_path := _normalize_material_save_path(save_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(resource_path.get_base_dir()))
	var error = ResourceSaver.save(material, resource_path)
	if error != OK:
		return _error("Failed to save material: %s" % error_string(error))
	_notify_filesystem(resource_path)

	return _success({
		"path": resource_path,
		"shader": shader_path if not shader_path.is_empty() else null
	}, "ShaderMaterial created and saved")


func _get_shader_material_info(path: String) -> Dictionary:
	var material := _load_shader_material(path)
	if material == null:
		return _error("ShaderMaterial not found: %s" % path)

	var info: Dictionary = {
		"path": str(material.resource_path) if not material.resource_path.is_empty() else null,
		"shader": str(material.shader.resource_path) if material.shader != null and not material.shader.resource_path.is_empty() else null
	}

	if material.shader != null:
		var params := {}
		for prop in material.get_property_list():
			var prop_name = str(prop.name)
			if prop_name.begins_with("shader_parameter/"):
				params[prop_name.substr(17)] = _serialize_value(material.get(prop_name))
		info["parameters"] = params

	return _success(info)


func _set_material_shader(path: String, shader_path: String) -> Dictionary:
	var material := _load_shader_material(path)
	if material == null:
		return _error("ShaderMaterial not found: %s" % path)

	if shader_path.is_empty():
		material.shader = null
		_persist_material_if_possible(material)
		return _success({"shader": null}, "Shader removed")

	var shader = _load_shader(shader_path)
	if shader == null:
		return _error("Shader not found: %s" % shader_path)

	material.shader = shader
	_persist_material_if_possible(material)
	return _success({"shader": _normalize_res_path_with_extension(shader_path, ".gdshader")}, "Shader set")


func _get_shader_param(path: String, param: String) -> Dictionary:
	if param.is_empty():
		return _error("Parameter name is required")

	var material := _load_shader_material(path)
	if material == null:
		return _error("ShaderMaterial not found: %s" % path)

	return _success({
		"param": param,
		"value": _serialize_value(material.get_shader_parameter(param))
	})


func _set_shader_param(path: String, param: String, value) -> Dictionary:
	if param.is_empty():
		return _error("Parameter name is required")

	var material := _load_shader_material(path)
	if material == null:
		return _error("ShaderMaterial not found: %s" % path)

	material.set_shader_parameter(param, _coerce_shader_param_value(value))
	_persist_material_if_possible(material)

	return _success({
		"param": param,
		"value": _serialize_value(material.get_shader_parameter(param))
	}, "Parameter set")


func _list_shader_params(path: String) -> Dictionary:
	var material := _load_shader_material(path)
	if material == null:
		return _error("ShaderMaterial not found: %s" % path)

	if material.shader == null:
		return _success({
			"count": 0,
			"parameters": [],
			"note": "No shader assigned"
		})

	var params: Array[Dictionary] = []
	for prop in material.get_property_list():
		var prop_name = str(prop.name)
		if prop_name.begins_with("shader_parameter/"):
			params.append({
				"name": prop_name.substr(17),
				"type": _type_to_string(prop.type),
				"value": _serialize_value(material.get(prop_name))
			})

	return _success({
		"count": params.size(),
		"parameters": params
	})


func _assign_shader_material(material_path: String, node_path: String, surface: int) -> Dictionary:
	if material_path.is_empty() or node_path.is_empty():
		return _error("Both material_path and node_path are required")

	var material := _load_shader_material(material_path)
	if material == null:
		return _error("ShaderMaterial not found: %s" % material_path)

	var node := _find_active_node(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)

	if node is GeometryInstance3D:
		node.set_surface_override_material(surface, material)
		return _success({
			"node": node_path,
			"surface": surface,
			"material": material_path
		}, "Material assigned to surface %d" % surface)
	if node is CanvasItem and "material" in node:
		node.material = material
		return _success({
			"node": node_path,
			"material": material_path
		}, "Material assigned")

	return _error("Node does not support material assignment")


func _coerce_shader_param_value(value):
	if value is Dictionary:
		if value.has("r") and value.has("g") and value.has("b"):
			return Color(float(value.get("r", 1.0)), float(value.get("g", 1.0)), float(value.get("b", 1.0)), float(value.get("a", 1.0)))
		if value.has("x") and value.has("y"):
			if value.has("z"):
				if value.has("w"):
					return Vector4(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)), float(value.get("w", 0.0)))
				return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
			return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))

	if value is String and str(value).begins_with("res://") and ResourceLoader.exists(value):
		var resource = load(value)
		if resource != null:
			return resource

	return value


func _normalize_material_save_path(path: String) -> String:
	var normalized := path.strip_edges()
	if not normalized.begins_with("res://"):
		normalized = "res://" + normalized
	if not normalized.ends_with(".tres") and not normalized.ends_with(".res"):
		normalized += ".tres"
	return normalized


func _persist_material_if_possible(material: ShaderMaterial) -> void:
	if material == null or material.resource_path.is_empty():
		return
	var error = ResourceSaver.save(material, material.resource_path)
	if error == OK:
		_notify_filesystem(material.resource_path)
