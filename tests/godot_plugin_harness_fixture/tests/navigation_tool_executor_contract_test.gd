extends RefCounted

const NavigationExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/navigation/executor.gd")

var _scene_root: Node3D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = NavigationExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/navigation_tools.gd"):
		return _failure("navigation_tools.gd should be removed once the split executor becomes the only stable entry.")

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 1:
		return _failure("Navigation executor should expose 1 tool definition after the split.")
	if str(tool_defs[0].get("name", "")) != "navigation":
		return _failure("Navigation executor should expose the canonical 'navigation' tool definition.")

	var map_info_result: Dictionary = executor.execute("navigation", {
		"action": "get_map_info",
		"mode": "3d"
	})
	if not bool(map_info_result.get("success", false)):
		return _failure("Navigation get_map_info failed through the split map service.")

	var list_regions_result: Dictionary = executor.execute("navigation", {
		"action": "list_regions",
		"mode": "3d"
	})
	if not bool(list_regions_result.get("success", false)):
		return _failure("Navigation list_regions failed through the split region service.")

	var list_agents_result: Dictionary = executor.execute("navigation", {
		"action": "list_agents",
		"mode": "3d"
	})
	if not bool(list_agents_result.get("success", false)):
		return _failure("Navigation list_agents failed through the split agent service.")

	var set_target_result: Dictionary = executor.execute("navigation", {
		"action": "set_agent_target",
		"path": "AgentNode",
		"target": {"x": 3.0, "y": 0.0, "z": 4.0}
	})
	if not bool(set_target_result.get("success", false)):
		return _failure("Navigation set_agent_target failed through the split agent service.")

	var get_agent_info_result: Dictionary = executor.execute("navigation", {
		"action": "get_agent_info",
		"path": "AgentNode"
	})
	if not bool(get_agent_info_result.get("success", false)):
		return _failure("Navigation get_agent_info failed through the split agent service.")

	var set_region_enabled_result: Dictionary = executor.execute("navigation", {
		"action": "set_region_enabled",
		"path": "RegionNode",
		"enabled": false
	})
	if not bool(set_region_enabled_result.get("success", false)):
		return _failure("Navigation set_region_enabled failed through the split region service.")

	var set_agent_enabled_result: Dictionary = executor.execute("navigation", {
		"action": "set_agent_enabled",
		"path": "AgentNode",
		"enabled": false
	})
	if not bool(set_agent_enabled_result.get("success", false)):
		return _failure("Navigation set_agent_enabled failed through the split agent service.")

	var invalid_bake_result: Dictionary = executor.execute("navigation", {
		"action": "bake_mesh",
		"path": "MissingRegion"
	})
	if bool(invalid_bake_result.get("success", false)):
		return _failure("Navigation bake_mesh should fail for a missing region path.")

	return {
		"name": "navigation_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"region_count": int(list_regions_result.get("data", {}).get("count", 0)),
			"agent_count": int(list_agents_result.get("data", {}).get("count", 0)),
			"map_count_3d": int(map_info_result.get("data", {}).get("3d", {}).get("map_count", 0))
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
	root.name = "NavigationToolExecutorContracts"

	var region := NavigationRegion3D.new()
	region.name = "RegionNode"
	region.navigation_mesh = NavigationMesh.new()
	root.add_child(region)

	var agent := NavigationAgent3D.new()
	agent.name = "AgentNode"
	root.add_child(agent)

	tree.root.add_child(root)
	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "navigation_tool_executor_contracts",
		"success": false,
		"error": message
	}
