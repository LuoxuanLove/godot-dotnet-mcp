@tool
extends "res://addons/godot_dotnet_mcp/tools/lighting/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"create":
			return _create_environment(args.get("parent", ""))
		"get_info":
			return _get_environment_info(args.get("path", ""))
		"set_background":
			return _set_background_mode(args.get("path", ""), args.get("mode", ""))
		"set_background_color":
			return _set_background_color(args.get("path", ""), args.get("color", {}))
		"set_ambient":
			return _set_ambient(args)
		"set_fog":
			return _set_fog(args)
		"set_glow":
			return _set_glow(args)
		"set_ssao":
			return _set_ssao(args)
		"set_ssr":
			return _set_ssr(args)
		"set_sdfgi":
			return _set_sdfgi(args)
		"set_tonemap":
			return _set_tonemap(args)
		"set_adjustments":
			return _set_adjustments(args)
		_:
			return _error("Unknown action: %s" % action)


func _create_environment(parent_path: String) -> Dictionary:
	if parent_path.is_empty():
		return _error("Parent path is required")

	var parent = _find_active_node(parent_path)
	if not parent:
		return _error("Parent not found: %s" % parent_path)

	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky.sky_material = sky_material
	env.sky = sky
	world_env.environment = env

	parent.add_child(world_env)
	world_env.owner = _get_scene_owner()

	return _success({
		"path": _active_scene_path(world_env)
	}, "WorldEnvironment created with default sky")


func _get_environment_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not node is WorldEnvironment:
		return _error("Node is not a WorldEnvironment")

	var env = node.environment
	if not env:
		return _error("No Environment resource")

	return _success({
		"path": _active_scene_path(node),
		"background_mode": env.background_mode,
		"ambient_light_source": env.ambient_light_source,
		"ambient_light_color": _serialize_value(env.ambient_light_color),
		"ambient_light_energy": env.ambient_light_energy,
		"fog_enabled": env.fog_enabled,
		"glow_enabled": env.glow_enabled,
		"ssao_enabled": env.ssao_enabled,
		"ssr_enabled": env.ssr_enabled,
		"sdfgi_enabled": env.sdfgi_enabled,
		"tonemap_mode": env.tonemap_mode,
		"has_sky": env.sky != null
	})


func _get_environment(path: String) -> Environment:
	var node = _find_active_node(path)
	if not node or not node is WorldEnvironment:
		return null
	return node.environment


func _set_background_mode(path: String, mode: String) -> Dictionary:
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	match mode:
		"clear_color":
			env.background_mode = Environment.BG_CLEAR_COLOR
		"color":
			env.background_mode = Environment.BG_COLOR
		"sky":
			env.background_mode = Environment.BG_SKY
		"canvas":
			env.background_mode = Environment.BG_CANVAS
		"keep":
			env.background_mode = Environment.BG_KEEP
		"camera_feed":
			env.background_mode = Environment.BG_CAMERA_FEED
		_:
			return _error("Unknown background mode: %s" % mode)

	return _success({
		"path": path,
		"background_mode": mode
	}, "Background mode set")


func _set_background_color(path: String, color_dict: Dictionary) -> Dictionary:
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	var color = Color(
		color_dict.get("r", 0.3),
		color_dict.get("g", 0.3),
		color_dict.get("b", 0.3),
		color_dict.get("a", 1.0)
	)
	env.background_color = color
	env.background_mode = Environment.BG_COLOR

	return _success({
		"path": path,
		"color": _serialize_value(color)
	}, "Background color set")


func _set_ambient(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	var source = args.get("source", "")
	if not source.is_empty():
		match source:
			"background":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
			"disabled":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
			"color":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			"sky":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	if args.has("energy"):
		env.ambient_light_energy = args.get("energy")
	if args.has("color"):
		var c = args.get("color")
		env.ambient_light_color = Color(c.get("r", 1), c.get("g", 1), c.get("b", 1))

	return _success({
		"path": path,
		"source": source,
		"energy": env.ambient_light_energy
	}, "Ambient light configured")


func _set_fog(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	if args.has("enabled"):
		env.fog_enabled = args.get("enabled")
	if args.has("density"):
		env.fog_density = args.get("density")
	if args.has("color"):
		var c = args.get("color")
		env.fog_light_color = Color(c.get("r", 0.5), c.get("g", 0.6), c.get("b", 0.7))
	if args.has("light_energy"):
		env.fog_light_energy = args.get("light_energy")
	if args.has("sun_scatter"):
		env.fog_sun_scatter = args.get("sun_scatter")

	return _success({
		"path": path,
		"fog_enabled": env.fog_enabled,
		"fog_density": env.fog_density
	}, "Fog configured")


func _set_glow(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	if args.has("enabled"):
		env.glow_enabled = args.get("enabled")
	if args.has("intensity"):
		env.glow_intensity = args.get("intensity")
	if args.has("strength"):
		env.glow_strength = args.get("strength")
	if args.has("bloom"):
		env.glow_bloom = args.get("bloom")
	if args.has("blend_mode"):
		var mode = args.get("blend_mode")
		match mode:
			"additive":
				env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
			"screen":
				env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
			"softlight":
				env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			"replace":
				env.glow_blend_mode = Environment.GLOW_BLEND_MODE_REPLACE

	return _success({
		"path": path,
		"glow_enabled": env.glow_enabled,
		"glow_intensity": env.glow_intensity
	}, "Glow configured")


func _set_ssao(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	if args.has("enabled"):
		env.ssao_enabled = args.get("enabled")
	if args.has("radius"):
		env.ssao_radius = args.get("radius")
	if args.has("intensity"):
		env.ssao_intensity = args.get("intensity")
	if args.has("power"):
		env.ssao_power = args.get("power")

	return _success({
		"path": path,
		"ssao_enabled": env.ssao_enabled,
		"ssao_radius": env.ssao_radius
	}, "SSAO configured")


func _set_ssr(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	if args.has("enabled"):
		env.ssr_enabled = args.get("enabled")
	if args.has("max_steps"):
		env.ssr_max_steps = args.get("max_steps")
	if args.has("fade_in"):
		env.ssr_fade_in = args.get("fade_in")
	if args.has("fade_out"):
		env.ssr_fade_out = args.get("fade_out")

	return _success({
		"path": path,
		"ssr_enabled": env.ssr_enabled
	}, "SSR configured")


func _set_sdfgi(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	if args.has("enabled"):
		env.sdfgi_enabled = args.get("enabled")
	if args.has("use_occlusion"):
		env.sdfgi_use_occlusion = args.get("use_occlusion")
	if args.has("bounce_feedback"):
		env.sdfgi_bounce_feedback = args.get("bounce_feedback")
	if args.has("cascades"):
		env.sdfgi_cascades = args.get("cascades")
	if args.has("energy"):
		env.sdfgi_energy = args.get("energy")

	return _success({
		"path": path,
		"sdfgi_enabled": env.sdfgi_enabled
	}, "SDFGI configured")


func _set_tonemap(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	if args.has("mode"):
		var mode = args.get("mode")
		match mode:
			"linear":
				env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			"reinhardt":
				env.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
			"filmic":
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			"aces":
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
	if args.has("exposure"):
		env.tonemap_exposure = args.get("exposure")
	if args.has("white"):
		env.tonemap_white = args.get("white")

	return _success({
		"path": path,
		"tonemap_mode": env.tonemap_mode,
		"tonemap_exposure": env.tonemap_exposure
	}, "Tonemap configured")


func _set_adjustments(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var env = _get_environment(path)
	if not env:
		return _error("Environment not found")

	if args.has("enabled"):
		env.adjustment_enabled = args.get("enabled")
	if args.has("brightness"):
		env.adjustment_brightness = args.get("brightness")
	if args.has("contrast"):
		env.adjustment_contrast = args.get("contrast")
	if args.has("saturation"):
		env.adjustment_saturation = args.get("saturation")

	return _success({
		"path": path,
		"adjustment_enabled": env.adjustment_enabled,
		"brightness": env.adjustment_brightness,
		"contrast": env.adjustment_contrast,
		"saturation": env.adjustment_saturation
	}, "Adjustments configured")
