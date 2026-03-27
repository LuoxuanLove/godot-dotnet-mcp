@tool
extends "res://addons/godot_dotnet_mcp/tools/lighting/environment_service.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"create":
			return _create_sky(args)
		"get_info":
			return _get_sky_info(args.get("path", ""))
		"set_procedural":
			return _set_procedural_sky(args)
		"set_physical":
			return _set_physical_sky(args)
		"set_panorama":
			return _set_panorama_sky(args)
		"set_radiance_size":
			return _set_sky_radiance(args.get("path", ""), args.get("size", 256))
		"set_process_mode":
			return _set_sky_process_mode(args.get("path", ""), args.get("mode", "automatic"))
		_:
			return _error("Unknown action: %s" % action)


func _create_sky(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var sky_type = args.get("type", "procedural")
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	var sky = Sky.new()
	var material
	match sky_type:
		"procedural":
			material = ProceduralSkyMaterial.new()
		"physical":
			material = PhysicalSkyMaterial.new()
		"panorama":
			material = PanoramaSkyMaterial.new()
		_:
			return _error("Unknown sky type: %s" % sky_type)

	sky.sky_material = material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	return _success({
		"path": path,
		"sky_type": sky_type
	}, "Sky created")


func _get_sky_info(path: String) -> Dictionary:
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")
	if not env.sky:
		return _error("No sky configured")

	var sky = env.sky
	var info = {
		"path": path,
		"radiance_size": sky.radiance_size,
		"process_mode": sky.process_mode
	}

	if sky.sky_material is ProceduralSkyMaterial:
		var mat: ProceduralSkyMaterial = sky.sky_material
		info["type"] = "procedural"
		info["sky_top_color"] = _serialize_value(mat.sky_top_color)
		info["sky_horizon_color"] = _serialize_value(mat.sky_horizon_color)
		info["ground_bottom_color"] = _serialize_value(mat.ground_bottom_color)
		info["ground_horizon_color"] = _serialize_value(mat.ground_horizon_color)
		info["sun_angle_max"] = mat.sun_angle_max
		info["sun_curve"] = mat.sun_curve
	elif sky.sky_material is PhysicalSkyMaterial:
		var physical: PhysicalSkyMaterial = sky.sky_material
		info["type"] = "physical"
		info["rayleigh_coefficient"] = physical.rayleigh_coefficient
		info["mie_coefficient"] = physical.mie_coefficient
		info["turbidity"] = physical.turbidity
		info["sun_disk_scale"] = physical.sun_disk_scale
	elif sky.sky_material is PanoramaSkyMaterial:
		var panorama: PanoramaSkyMaterial = sky.sky_material
		info["type"] = "panorama"
		info["has_texture"] = panorama.panorama != null

	return _success(info)


func _set_procedural_sky(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env or not env.sky:
		return _error("Environment/sky not found")

	var mat = env.sky.sky_material
	if not mat is ProceduralSkyMaterial:
		mat = ProceduralSkyMaterial.new()
		env.sky.sky_material = mat

	if args.has("sky_top_color"):
		var c = args.get("sky_top_color")
		mat.sky_top_color = Color(c.get("r", 0.4), c.get("g", 0.6), c.get("b", 1.0))
	if args.has("sky_horizon_color"):
		var c = args.get("sky_horizon_color")
		mat.sky_horizon_color = Color(c.get("r", 0.6), c.get("g", 0.8), c.get("b", 1.0))
	if args.has("ground_bottom_color"):
		var c = args.get("ground_bottom_color")
		mat.ground_bottom_color = Color(c.get("r", 0.2), c.get("g", 0.17), c.get("b", 0.13))
	if args.has("ground_horizon_color"):
		var c = args.get("ground_horizon_color")
		mat.ground_horizon_color = Color(c.get("r", 0.6), c.get("g", 0.7), c.get("b", 0.9))
	if args.has("sun_angle_max"):
		mat.sun_angle_max = args.get("sun_angle_max")
	if args.has("sun_curve"):
		mat.sun_curve = args.get("sun_curve")

	return _success({
		"path": path,
		"type": "procedural"
	}, "Procedural sky configured")


func _set_physical_sky(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env or not env.sky:
		return _error("Environment/sky not found")

	var mat = env.sky.sky_material
	if not mat is PhysicalSkyMaterial:
		mat = PhysicalSkyMaterial.new()
		env.sky.sky_material = mat

	if args.has("rayleigh_coefficient"):
		mat.rayleigh_coefficient = args.get("rayleigh_coefficient")
	if args.has("mie_coefficient"):
		mat.mie_coefficient = args.get("mie_coefficient")
	if args.has("turbidity"):
		mat.turbidity = args.get("turbidity")
	if args.has("sun_disk_scale"):
		mat.sun_disk_scale = args.get("sun_disk_scale")
	if args.has("ground_color"):
		var c = args.get("ground_color")
		mat.ground_color = Color(c.get("r", 0.1), c.get("g", 0.07), c.get("b", 0.03))

	return _success({
		"path": path,
		"type": "physical"
	}, "Physical sky configured")


func _set_panorama_sky(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var texture_path = args.get("texture", "")
	var env = _get_environment(path)
	if not env or not env.sky:
		return _error("Environment/sky not found")

	var mat = env.sky.sky_material
	if not mat is PanoramaSkyMaterial:
		mat = PanoramaSkyMaterial.new()
		env.sky.sky_material = mat

	if not texture_path.is_empty():
		var texture = load(texture_path)
		if texture:
			mat.panorama = texture
		else:
			return _error("Failed to load texture: %s" % texture_path)

	return _success({
		"path": path,
		"type": "panorama",
		"texture": texture_path
	}, "Panorama sky configured")


func _set_sky_radiance(path: String, size: int) -> Dictionary:
	var env = _get_environment(path)
	if not env or not env.sky:
		return _error("Environment/sky not found")

	var valid_sizes = [32, 64, 128, 256, 512, 1024, 2048]
	if not size in valid_sizes:
		return _error("Invalid radiance size. Valid: %s" % str(valid_sizes))

	env.sky.radiance_size = size
	return _success({
		"path": path,
		"radiance_size": size
	}, "Radiance size set")


func _set_sky_process_mode(path: String, mode: String) -> Dictionary:
	var env = _get_environment(path)
	if not env or not env.sky:
		return _error("Environment/sky not found")

	match mode:
		"automatic":
			env.sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
		"quality":
			env.sky.process_mode = Sky.PROCESS_MODE_QUALITY
		"incremental":
			env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		"realtime":
			env.sky.process_mode = Sky.PROCESS_MODE_REALTIME
		_:
			return _error("Unknown process mode: %s" % mode)

	return _success({
		"path": path,
		"process_mode": mode
	}, "Process mode set")
