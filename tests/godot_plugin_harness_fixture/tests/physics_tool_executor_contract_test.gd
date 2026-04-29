extends RefCounted

const PhysicsExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/physics/executor.gd")

var _scene_root: Node3D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = PhysicsExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/physics_tools.gd"):
		return _failure("physics_tools.gd should be removed once the split executor becomes the only stable entry.")

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 4:
		return _failure("Physics executor should expose 4 tool definitions after the split.")

	var expected_names := ["physics_body", "collision_shape", "physics_joint", "physics_query"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Physics executor is missing tool definition '%s'." % expected_name)

	var body_a_result: Dictionary = executor.execute("physics_body", {
		"action": "create",
		"type": "rigid_body_3d",
		"parent": ".",
		"name": "BodyA"
	})
	if not bool(body_a_result.get("success", false)):
		return _failure("Physics body create failed for BodyA.")

	var body_b_result: Dictionary = executor.execute("physics_body", {
		"action": "create",
		"type": "static_body_3d",
		"parent": ".",
		"name": "BodyB"
	})
	if not bool(body_b_result.get("success", false)):
		return _failure("Physics body create failed for BodyB.")

	var shape_result: Dictionary = executor.execute("collision_shape", {
		"action": "create",
		"parent": "BodyA"
	})
	if not bool(shape_result.get("success", false)):
		return _failure("Collision shape create failed through the split shape service.")

	var shape_path := str(shape_result.get("data", {}).get("path", ""))
	var box_result: Dictionary = executor.execute("collision_shape", {
		"action": "create_box",
		"path": shape_path,
		"size": {"x": 1.0, "y": 1.0, "z": 1.0}
	})
	if not bool(box_result.get("success", false)):
		return _failure("Collision shape create_box failed through the split shape service.")

	var joint_result: Dictionary = executor.execute("physics_joint", {
		"action": "create",
		"type": "pin_joint_3d",
		"parent": ".",
		"name": "Link"
	})
	if not bool(joint_result.get("success", false)):
		return _failure("Physics joint create failed through the split joint service.")

	var set_nodes_result: Dictionary = executor.execute("physics_joint", {
		"action": "set_nodes",
		"path": "Link",
		"node_a": "../BodyA",
		"node_b": "../BodyB"
	})
	if not bool(set_nodes_result.get("success", false)):
		return _failure("Physics joint set_nodes failed through the split joint service.")

	var raycast_result: Dictionary = executor.execute("physics_query", {
		"action": "raycast",
		"mode": "3d",
		"from": {"x": 50.0, "y": 10.0, "z": 0.0},
		"to": {"x": 50.0, "y": -10.0, "z": 0.0}
	})
	if not bool(raycast_result.get("success", false)):
		return _failure("Physics raycast failed through the split query service.")

	return {
		"name": "physics_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"body_a_path": str(body_a_result.get("data", {}).get("path", "")),
			"shape_path": shape_path,
			"joint_path": str(joint_result.get("data", {}).get("path", "")),
			"raycast_hit": bool(raycast_result.get("data", {}).get("hit", false))
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
	root.name = "PhysicsToolExecutorContracts"
	tree.root.add_child(root)
	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "physics_tool_executor_contracts",
		"success": false,
		"error": message
	}
