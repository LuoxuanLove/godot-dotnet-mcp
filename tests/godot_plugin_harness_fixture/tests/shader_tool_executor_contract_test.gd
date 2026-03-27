extends RefCounted

const ShaderExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/shader/executor.gd")

const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_shader_contracts"
const SHADER_PATH := "res://Tmp/godot_dotnet_mcp_shader_contracts/shaders/contract_canvas_shader.gdshader"
const MATERIAL_PATH := "res://Tmp/godot_dotnet_mcp_shader_contracts/materials/contract_shader_material.tres"

var _scene_root: Node2D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = ShaderExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/shader_tools.gd"):
		return _failure("shader_tools.gd should be removed once the split executor becomes the only stable entry.")

	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 2:
		return _failure("Shader executor should expose 2 tool definitions after the split.")

	var expected_names := ["shader", "shader_material"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Shader executor is missing tool definition '%s'." % expected_name)

	var create_shader_result: Dictionary = executor.execute("shader", {
		"action": "create",
		"path": SHADER_PATH,
		"type": "canvas_item"
	})
	if not bool(create_shader_result.get("success", false)):
		return _failure("Shader create failed through the split shader service.")

	var read_result: Dictionary = executor.execute("shader", {
		"action": "read",
		"path": SHADER_PATH
	})
	if not bool(read_result.get("success", false)):
		return _failure("Shader read failed through the split shader service.")

	var info_result: Dictionary = executor.execute("shader", {
		"action": "get_info",
		"path": SHADER_PATH
	})
	if not bool(info_result.get("success", false)):
		return _failure("Shader get_info failed through the split shader service.")
	if str(info_result.get("data", {}).get("type", "")) != "canvas_item":
		return _failure("Shader get_info should report canvas_item after the split.")

	var uniforms_result: Dictionary = executor.execute("shader", {
		"action": "get_uniforms",
		"path": SHADER_PATH
	})
	if not bool(uniforms_result.get("success", false)):
		return _failure("Shader get_uniforms failed through the split shader service.")

	var set_default_result: Dictionary = executor.execute("shader", {
		"action": "set_default",
		"path": SHADER_PATH,
		"uniform": "modulate_color",
		"value": "vec4(0.2, 0.4, 0.8, 1.0)"
	})
	if not bool(set_default_result.get("success", false)):
		return _failure("Shader set_default failed through the split shader service.")

	var reread_result: Dictionary = executor.execute("shader", {
		"action": "read",
		"path": SHADER_PATH
	})
	if not bool(reread_result.get("success", false)):
		return _failure("Shader read after set_default failed through the split shader service.")
	if not str(reread_result.get("data", {}).get("code", "")).contains("vec4(0.2, 0.4, 0.8, 1.0)"):
		return _failure("Shader set_default should update the uniform default in the saved shader code.")

	var create_material_result: Dictionary = executor.execute("shader_material", {
		"action": "create",
		"shader_path": SHADER_PATH,
		"save_path": MATERIAL_PATH
	})
	if not bool(create_material_result.get("success", false)):
		return _failure("ShaderMaterial create failed through the split material service.")

	var material_info_result: Dictionary = executor.execute("shader_material", {
		"action": "get_info",
		"path": MATERIAL_PATH
	})
	if not bool(material_info_result.get("success", false)):
		return _failure("ShaderMaterial get_info failed through the split material service.")

	var list_params_result: Dictionary = executor.execute("shader_material", {
		"action": "list_params",
		"path": MATERIAL_PATH
	})
	if not bool(list_params_result.get("success", false)):
		return _failure("ShaderMaterial list_params failed through the split material service.")

	var set_param_result: Dictionary = executor.execute("shader_material", {
		"action": "set_param",
		"path": MATERIAL_PATH,
		"param": "modulate_color",
		"value": {
			"r": 0.9,
			"g": 0.5,
			"b": 0.3,
			"a": 1.0
		}
	})
	if not bool(set_param_result.get("success", false)):
		return _failure("ShaderMaterial set_param failed through the split material service.")

	var get_param_result: Dictionary = executor.execute("shader_material", {
		"action": "get_param",
		"path": MATERIAL_PATH,
		"param": "modulate_color"
	})
	if not bool(get_param_result.get("success", false)):
		return _failure("ShaderMaterial get_param failed through the split material service.")

	var assign_result: Dictionary = executor.execute("shader_material", {
		"action": "assign_to_node",
		"material_path": MATERIAL_PATH,
		"node_path": "SpriteNode"
	})
	if not bool(assign_result.get("success", false)):
		return _failure("ShaderMaterial assign_to_node failed through the split material service.")

	var sprite := _scene_root.get_node_or_null("SpriteNode") as Sprite2D
	if sprite == null or not (sprite.material is ShaderMaterial):
		return _failure("ShaderMaterial assign_to_node should assign the material to the SpriteNode fixture.")

	return {
		"name": "shader_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"uniform_count": int(uniforms_result.get("data", {}).get("count", 0)),
			"parameter_count": int(list_params_result.get("data", {}).get("count", 0))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	_remove_tree(TEMP_ROOT)
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node2D:
	var root := Node2D.new()
	root.name = "ShaderToolExecutorContracts"
	var sprite := Sprite2D.new()
	sprite.name = "SpriteNode"
	root.add_child(sprite)
	tree.root.add_child(root)
	return root


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_tree_absolute(absolute_path)


func _remove_tree_absolute(absolute_path: String) -> void:
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree_absolute(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "shader_tool_executor_contracts",
		"success": false,
		"error": message
	}
