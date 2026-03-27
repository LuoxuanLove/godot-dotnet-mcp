extends RefCounted

const LightingExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/lighting/executor.gd")

var _scene_root: Node3D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = LightingExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/lighting_tools.gd"):
		return _failure("lighting_tools.gd should be removed once the split executor becomes the only stable entry.")

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 3:
		return _failure("Lighting executor should expose 3 tool definitions after the split.")

	var expected_names := ["light", "environment", "sky"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Lighting executor is missing tool definition '%s'." % expected_name)

	var create_light_result: Dictionary = executor.execute("light", {
		"action": "create",
		"type": "omni_light_3d",
		"parent": ".",
		"name": "KeyLight"
	})
	if not bool(create_light_result.get("success", false)):
		return _failure("Lighting create failed through the split light service.")

	var light_path := str(create_light_result.get("data", {}).get("path", ""))
	var set_color_result: Dictionary = executor.execute("light", {
		"action": "set_color",
		"path": light_path,
		"color": {"r": 1.0, "g": 0.9, "b": 0.8, "a": 1.0}
	})
	if not bool(set_color_result.get("success", false)):
		return _failure("Lighting set_color failed through the split light service.")

	var list_result: Dictionary = executor.execute("light", {"action": "list"})
	if not bool(list_result.get("success", false)):
		return _failure("Lighting list failed through the split light service.")
	if int(list_result.get("data", {}).get("count", 0)) < 1:
		return _failure("Lighting list should report at least one light after creation.")

	var create_environment_result: Dictionary = executor.execute("environment", {
		"action": "create",
		"parent": "."
	})
	if not bool(create_environment_result.get("success", false)):
		return _failure("Environment create failed through the split environment service.")

	var environment_path := str(create_environment_result.get("data", {}).get("path", ""))
	var background_result: Dictionary = executor.execute("environment", {
		"action": "set_background",
		"path": environment_path,
		"mode": "color"
	})
	if not bool(background_result.get("success", false)):
		return _failure("Environment set_background failed through the split environment service.")

	var create_sky_result: Dictionary = executor.execute("sky", {
		"action": "create",
		"path": environment_path,
		"type": "procedural"
	})
	if not bool(create_sky_result.get("success", false)):
		return _failure("Sky create failed through the split sky service.")

	var sky_info_result: Dictionary = executor.execute("sky", {
		"action": "get_info",
		"path": environment_path
	})
	if not bool(sky_info_result.get("success", false)):
		return _failure("Sky get_info failed through the split sky service.")

	return {
		"name": "lighting_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"light_path": light_path,
			"environment_path": environment_path,
			"listed_lights": int(list_result.get("data", {}).get("count", 0)),
			"sky_type": str(sky_info_result.get("data", {}).get("type", ""))
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
	root.name = "LightingToolExecutorContracts"
	tree.root.add_child(root)
	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "lighting_tool_executor_contracts",
		"success": false,
		"error": message
	}
