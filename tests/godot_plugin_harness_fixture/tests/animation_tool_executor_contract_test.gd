extends RefCounted

const AnimationExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/animation/executor.gd")

var _scene_root: Node2D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = AnimationExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	var executor_tools: Array[Dictionary] = executor.get_tools()
	if executor_tools.size() != 8:
		return _failure("Animation executor should expose 8 tool definitions after the split.")
	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/animation_tools.gd"):
		return _failure("animation_tools.gd should be removed once the split executor becomes the only stable entry.")

	var expected_names := ["player", "animation", "track", "tween", "animation_tree", "state_machine", "blend_space", "blend_tree"]
	var actual_names: Array[String] = []
	for tool_def in executor_tools:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Animation executor is missing tool definition '%s'." % expected_name)

	var list_result: Dictionary = executor.execute("player", {"action": "list", "path": "Player"})
	if not bool(list_result.get("success", false)):
		return _failure("Animation player list failed through the split player service.")

	var create_anim_result: Dictionary = executor.execute("animation", {
		"action": "create",
		"path": "Player",
		"name": "run",
		"length": 0.5
	})
	if not bool(create_anim_result.get("success", false)):
		return _failure("Animation create failed through the split animation service.")

	var add_track_result: Dictionary = executor.execute("track", {
		"action": "add_property_track",
		"path": "Player",
		"animation": "idle",
		"node_path": "Sprite:position"
	})
	if not bool(add_track_result.get("success", false)):
		return _failure("Animation track creation failed through the split track service.")

	var tween_info_result: Dictionary = executor.execute("tween", {"action": "info"})
	if not bool(tween_info_result.get("success", false)):
		return _failure("Tween info failed through the split tween service.")

	var state_tree_result: Dictionary = executor.execute("animation_tree", {
		"action": "create",
		"path": ".",
		"name": "StateTree",
		"root_type": "state_machine"
	})
	if not bool(state_tree_result.get("success", false)):
		return _failure("AnimationTree create failed through the split animation_tree service.")

	var set_player_result: Dictionary = executor.execute("animation_tree", {
		"action": "set_player",
		"path": "StateTree",
		"player": "Player"
	})
	if not bool(set_player_result.get("success", false)):
		return _failure("AnimationTree set_player failed through the split animation_tree service.")

	var add_state_result: Dictionary = executor.execute("state_machine", {
		"action": "add_state",
		"path": "StateTree",
		"state": "idle",
		"animation": "idle"
	})
	if not bool(add_state_result.get("success", false)):
		return _failure("State machine add_state failed through the split state_machine service.")

	var blend_space_tree_result: Dictionary = executor.execute("animation_tree", {
		"action": "create",
		"path": ".",
		"name": "BlendSpaceTree",
		"root_type": "blend_space_1d"
	})
	if not bool(blend_space_tree_result.get("success", false)):
		return _failure("Blend space tree creation failed.")

	var add_point_result: Dictionary = executor.execute("blend_space", {
		"action": "add_point",
		"path": "BlendSpaceTree",
		"animation": "idle",
		"position": 0.0
	})
	if not bool(add_point_result.get("success", false)):
		return _failure("Blend space add_point failed through the split blend_space service.")

	var blend_tree_result: Dictionary = executor.execute("animation_tree", {
		"action": "create",
		"path": ".",
		"name": "BlendTreeGraph",
		"root_type": "blend_tree"
	})
	if not bool(blend_tree_result.get("success", false)):
		return _failure("Blend tree AnimationTree creation failed.")

	var add_node_result: Dictionary = executor.execute("blend_tree", {
		"action": "add_node",
		"path": "BlendTreeGraph",
		"name": "idle_node",
		"type": "animation",
		"animation": "idle"
	})
	if not bool(add_node_result.get("success", false)):
		return _failure("Blend tree add_node failed through the split blend_tree service.")

	return {
		"name": "animation_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": executor_tools.size(),
			"animation_count": int(list_result.get("data", {}).get("count", 0)),
			"state_tree_path": str(state_tree_result.get("data", {}).get("path", "")),
			"blend_tree_path": str(blend_tree_result.get("data", {}).get("path", ""))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node2D:
	var root := Node2D.new()
	root.name = "AnimationToolExecutorContracts"

	var sprite := Node2D.new()
	sprite.name = "Sprite"
	root.add_child(sprite)
	sprite.owner = root

	var player := AnimationPlayer.new()
	player.name = "Player"
	root.add_child(player)
	player.owner = root

	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 1.0
	library.add_animation("idle", idle)
	player.add_animation_library("", library)

	tree.root.add_child(root)
	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "animation_tool_executor_contracts",
		"success": false,
		"error": message
	}
