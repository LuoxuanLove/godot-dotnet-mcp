@tool
extends "res://addons/godot_dotnet_mcp/tools/shader/service_base.gd"

var _rx_shader_type: RegEx
var _rx_render_mode: RegEx
var _rx_uniform_count: RegEx
var _rx_function_name: RegEx
var _rx_uniform_def: RegEx
var _rx_uniform_statement: RegEx
var _regex_init_error := ""


func _init() -> void:
	_rx_shader_type = _compile_regex("shader_type\\s+(\\w+)")
	_rx_render_mode = _compile_regex("render_mode\\s+([^;]+)")
	_rx_uniform_count = _compile_regex("uniform\\s+")
	_rx_function_name = _compile_regex("void\\s+(\\w+)\\s*\\(")
	_rx_uniform_def = _compile_regex("uniform\\s+(\\w+)\\s+(\\w+)\\s*(?::\\s*([^=;]+))?\\s*(?:=\\s*([^;]+))?")
	_rx_uniform_statement = _compile_regex("uniform\\s+\\w+\\s+\\w+\\s*(?::\\s*[^=;]+)?\\s*(?:=\\s*[^;]+)?;")


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	if not _regex_init_error.is_empty():
		return _error("Shader tool regex initialization failed", {"details": _regex_init_error})

	var action = str(args.get("action", ""))
	match action:
		"create":
			return _create_shader(args)
		"read":
			return _read_shader(str(args.get("path", "")))
		"write":
			return _write_shader(str(args.get("path", "")), str(args.get("code", "")))
		"get_info":
			return _get_shader_info(str(args.get("path", "")))
		"get_uniforms":
			return _get_shader_uniforms(str(args.get("path", "")))
		"set_default":
			return _set_uniform_default(str(args.get("path", "")), str(args.get("uniform", "")), args.get("value"))
		_:
			return _error("Unknown action: %s" % action)


func _create_shader(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var shader_type := str(args.get("type", "spatial"))
	if path.is_empty():
		return _error("Path is required")

	var resource_path := _normalize_res_path_with_extension(path, ".gdshader")
	var code := _get_shader_template(shader_type)
	if code.is_empty():
		return _error("Invalid shader type: %s" % shader_type)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(resource_path.get_base_dir()))

	var file = FileAccess.open(resource_path, FileAccess.WRITE)
	if file == null:
		return _error("Failed to create shader file: %s" % resource_path)
	file.store_string(code)
	file.close()
	_notify_filesystem(resource_path)

	return _success({
		"path": resource_path,
		"type": shader_type
	}, "Shader created")


func _read_shader(path: String) -> Dictionary:
	var resource_path := _normalize_res_path_with_extension(path, ".gdshader")
	if resource_path.is_empty():
		return _error("Path is required")

	var file = FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		return _error("Failed to read shader: %s" % resource_path)
	var code := file.get_as_text()
	file.close()

	return _success({
		"path": resource_path,
		"code": code,
		"length": code.length()
	})


func _write_shader(path: String, code: String) -> Dictionary:
	var resource_path := _normalize_res_path_with_extension(path, ".gdshader")
	if resource_path.is_empty():
		return _error("Path is required")
	if code.is_empty():
		return _error("Code is required")

	var file = FileAccess.open(resource_path, FileAccess.WRITE)
	if file == null:
		return _error("Failed to write shader: %s" % resource_path)
	file.store_string(code)
	file.close()
	_notify_filesystem(resource_path)

	return _success({
		"path": resource_path,
		"length": code.length()
	}, "Shader written")


func _get_shader_info(path: String) -> Dictionary:
	var resource_path := _normalize_res_path_with_extension(path, ".gdshader")
	var shader := _load_shader(resource_path)
	if shader == null:
		return _error("Shader not found: %s" % resource_path)

	var code := shader.code
	var info: Dictionary = {
		"path": resource_path,
		"mode": shader.get_mode()
	}

	var match_result = _rx_shader_type.search(code)
	if match_result != null:
		info["type"] = match_result.get_string(1)

	match_result = _rx_render_mode.search(code)
	if match_result != null:
		info["render_modes"] = match_result.get_string(1).split(",")

	info["uniform_count"] = _rx_uniform_count.search_all(code).size()
	var functions: Array[String] = []
	for function_match in _rx_function_name.search_all(code):
		functions.append(function_match.get_string(1))
	info["functions"] = functions

	return _success(info)


func _get_shader_uniforms(path: String) -> Dictionary:
	var resource_path := _normalize_res_path_with_extension(path, ".gdshader")
	var shader := _load_shader(resource_path)
	if shader == null:
		return _error("Shader not found: %s" % resource_path)

	var uniforms: Array[Dictionary] = []
	for statement_match in _rx_uniform_statement.search_all(shader.code):
		var statement = shader.code.substr(statement_match.get_start(), statement_match.get_end() - statement_match.get_start())
		var uniform_match = _rx_uniform_def.search(statement)
		if uniform_match == null:
			continue
		var uniform: Dictionary = {
			"type": uniform_match.get_string(1),
			"name": uniform_match.get_string(2)
		}
		if not uniform_match.get_string(3).is_empty():
			uniform["hint"] = uniform_match.get_string(3).strip_edges()
		if not uniform_match.get_string(4).is_empty():
			uniform["default"] = uniform_match.get_string(4).strip_edges()
		uniforms.append(uniform)

	return _success({
		"path": resource_path,
		"count": uniforms.size(),
		"uniforms": uniforms
	})


func _set_uniform_default(path: String, uniform_name: String, value) -> Dictionary:
	if uniform_name.is_empty():
		return _error("Uniform name is required")

	var resource_path := _normalize_res_path_with_extension(path, ".gdshader")
	var file = FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		return _error("Failed to read shader: %s" % resource_path)
	var code := file.get_as_text()
	file.close()

	var uniform_match := _find_uniform_match(code, uniform_name)
	if uniform_match.is_empty():
		return _error("Uniform not found: %s" % uniform_name)

	var replacement := str(value)
	var match_result: RegExMatch = uniform_match["match"]
	if not match_result.get_string(4).is_empty():
		var value_start = int(uniform_match["statement_start"]) + match_result.get_start(4)
		var value_end = int(uniform_match["statement_start"]) + match_result.get_end(4)
		code = code.substr(0, value_start) + replacement + code.substr(value_end)
	else:
		var statement_end = int(uniform_match["statement_end"])
		code = code.substr(0, statement_end - 1) + " = " + replacement + code.substr(statement_end - 1)

	file = FileAccess.open(resource_path, FileAccess.WRITE)
	if file == null:
		return _error("Failed to write shader: %s" % resource_path)
	file.store_string(code)
	file.close()
	_notify_filesystem(resource_path)

	return _success({
		"uniform": uniform_name,
		"value": value
	}, "Uniform default updated")


func _compile_regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		var message = "Failed to compile regex: %s" % pattern
		if _regex_init_error.is_empty():
			_regex_init_error = message
		else:
			_regex_init_error += "\n" + message
	return regex


func _find_uniform_match(code: String, uniform_name: String) -> Dictionary:
	for statement_match in _rx_uniform_statement.search_all(code):
		var statement_start = statement_match.get_start()
		var statement_end = statement_match.get_end()
		var statement = code.substr(statement_start, statement_end - statement_start)
		var uniform_match = _rx_uniform_def.search(statement)
		if uniform_match == null:
			continue
		if uniform_match.get_string(2) != uniform_name:
			continue
		return {
			"statement_start": statement_start,
			"statement_end": statement_end,
			"match": uniform_match
		}
	return {}


func _get_shader_template(shader_type: String) -> String:
	match shader_type:
		"spatial":
			return """shader_type spatial;

// Uniforms
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ALBEDO = albedo_color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
"""
		"canvas_item":
			return """shader_type canvas_item;

// Uniforms
uniform vec4 modulate_color : source_color = vec4(1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = tex_color * modulate_color;
}
"""
		"particles":
			return """shader_type particles;

uniform float spread : hint_range(0.0, 180.0) = 45.0;
uniform float initial_speed : hint_range(0.0, 100.0) = 10.0;

void start() {
	float angle = (randf() - 0.5) * spread * PI / 180.0;
	VELOCITY = vec3(sin(angle), cos(angle), 0.0) * initial_speed;
}

void process() {
	// Process particles here
}
"""
		"sky":
			return """shader_type sky;

uniform vec3 sky_color : source_color = vec3(0.4, 0.6, 1.0);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.9, 1.0);
uniform vec3 ground_color : source_color = vec3(0.3, 0.25, 0.2);

void sky() {
	float y = EYEDIR.y;
	if (y > 0.0) {
		COLOR = mix(horizon_color, sky_color, y);
	} else {
		COLOR = mix(horizon_color, ground_color, -y);
	}
}
"""
		"fog":
			return """shader_type fog;

uniform vec4 fog_color : source_color = vec4(0.5, 0.6, 0.7, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.1;

void fog() {
	DENSITY = density;
	ALBEDO = fog_color.rgb;
}
"""
		_:
			return ""
