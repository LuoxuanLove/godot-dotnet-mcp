@tool
extends "res://addons/godot_dotnet_mcp/tools/navigation/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"list_agents":
			return _list_agents(str(args.get("mode", "")))
		"set_agent_target":
			return _set_agent_target(str(args.get("path", "")), args.get("target", {}))
		"get_agent_info":
			return _get_agent_info(str(args.get("path", "")))
		"set_agent_enabled":
			return _set_agent_enabled(str(args.get("path", "")), bool(args.get("enabled", true)))
		_:
			return _error("Unknown action: %s" % action)


func _list_agents(mode: String) -> Dictionary:
	var root := _get_active_root()
	if root == null:
		return _error("No scene open")

	var agents: Array[Dictionary] = []
	_collect_navigation_agents(root, agents, mode)
	return _success({
		"count": agents.size(),
		"agents": agents
	})


func _set_agent_target(path: String, target_dict: Dictionary) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if target_dict.is_empty():
		return _error("Target position is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	if node is NavigationAgent3D:
		var target := Vector3(target_dict.get("x", 0), target_dict.get("y", 0), target_dict.get("z", 0))
		node.target_position = target
		return _success({
			"path": path,
			"target": _serialize_value(target)
		}, "Agent target set")
	elif node is NavigationAgent2D:
		var target_2d := Vector2(target_dict.get("x", 0), target_dict.get("y", 0))
		node.target_position = target_2d
		return _success({
			"path": path,
			"target": _serialize_value(target_2d)
		}, "Agent target set")

	return _error("Node is not a NavigationAgent")


func _get_agent_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	if node is NavigationAgent3D:
		return _success({
			"path": path,
			"type": "NavigationAgent3D",
			"target_position": _serialize_value(node.target_position),
			"is_target_reached": node.is_target_reached(),
			"is_target_reachable": node.is_target_reachable(),
			"is_navigation_finished": node.is_navigation_finished(),
			"distance_to_target": node.distance_to_target(),
			"next_path_position": _serialize_value(node.get_next_path_position()),
			"current_navigation_path_index": node.get_current_navigation_path_index(),
			"velocity": _serialize_value(node.velocity),
			"radius": node.radius,
			"height": node.height,
			"max_speed": node.max_speed,
			"avoidance_enabled": node.avoidance_enabled
		})
	elif node is NavigationAgent2D:
		return _success({
			"path": path,
			"type": "NavigationAgent2D",
			"target_position": _serialize_value(node.target_position),
			"is_target_reached": node.is_target_reached(),
			"is_target_reachable": node.is_target_reachable(),
			"is_navigation_finished": node.is_navigation_finished(),
			"distance_to_target": node.distance_to_target(),
			"next_path_position": _serialize_value(node.get_next_path_position()),
			"current_navigation_path_index": node.get_current_navigation_path_index(),
			"velocity": _serialize_value(node.velocity),
			"radius": node.radius,
			"max_speed": node.max_speed,
			"avoidance_enabled": node.avoidance_enabled
		})

	return _error("Node is not a NavigationAgent")


func _set_agent_enabled(path: String, enabled: bool) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not (node is NavigationAgent3D or node is NavigationAgent2D):
		return _error("Node is not a NavigationAgent")

	node.avoidance_enabled = enabled
	return _success({
		"path": path,
		"avoidance_enabled": enabled
	}, "Agent avoidance %s" % ("enabled" if enabled else "disabled"))
