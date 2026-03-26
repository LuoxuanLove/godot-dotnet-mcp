@tool
extends "res://addons/godot_dotnet_mcp/tools/node/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	match action:
		"get_status":
			return _get_process_status(node)
		"set_process":
			return _set_process_flag(node, "process", args.get("enabled", true))
		"set_physics_process":
			return _set_process_flag(node, "physics_process", args.get("enabled", true))
		"set_input":
			return _set_process_flag(node, "input", args.get("enabled", true))
		"set_unhandled_input":
			return _set_process_flag(node, "unhandled_input", args.get("enabled", true))
		"set_unhandled_key_input":
			return _set_process_flag(node, "unhandled_key_input", args.get("enabled", true))
		"set_shortcut_input":
			return _set_process_flag(node, "shortcut_input", args.get("enabled", true))
		"set_process_mode":
			return _set_process_mode(node, args.get("mode", "inherit"))
		"set_process_priority":
			return _set_process_priority(node, args.get("priority", 0))
		"set_physics_priority":
			return _set_physics_priority(node, args.get("priority", 0))
		_:
			return _error("Unknown action: %s" % action)


func _get_process_status(node: Node) -> Dictionary:
	return _success({
		"path": _active_scene_path(node),
		"processing": node.is_processing(),
		"physics_processing": node.is_physics_processing(),
		"input_processing": node.is_processing_input(),
		"unhandled_input_processing": node.is_processing_unhandled_input(),
		"unhandled_key_input_processing": node.is_processing_unhandled_key_input(),
		"shortcut_input_processing": node.is_processing_shortcut_input(),
		"process_mode": node.process_mode,
		"process_priority": node.process_priority,
		"physics_process_priority": node.process_physics_priority,
		"can_process": node.can_process()
	})


func _set_process_flag(node: Node, flag_type: String, enabled: bool) -> Dictionary:
	match flag_type:
		"process":
			node.set_process(enabled)
		"physics_process":
			node.set_physics_process(enabled)
		"input":
			node.set_process_input(enabled)
		"unhandled_input":
			node.set_process_unhandled_input(enabled)
		"unhandled_key_input":
			node.set_process_unhandled_key_input(enabled)
		"shortcut_input":
			node.set_process_shortcut_input(enabled)
	return _success({"path": _active_scene_path(node), flag_type: enabled}, "Process flag set")


func _set_process_mode(node: Node, mode: String) -> Dictionary:
	var mode_value: Node.ProcessMode
	match mode.to_lower():
		"inherit":
			mode_value = Node.PROCESS_MODE_INHERIT
		"pausable":
			mode_value = Node.PROCESS_MODE_PAUSABLE
		"when_paused":
			mode_value = Node.PROCESS_MODE_WHEN_PAUSED
		"always":
			mode_value = Node.PROCESS_MODE_ALWAYS
		"disabled":
			mode_value = Node.PROCESS_MODE_DISABLED
		_:
			return _error("Invalid process mode: %s" % mode)
	node.process_mode = mode_value
	return _success({"path": _active_scene_path(node), "process_mode": mode}, "Process mode set")


func _set_process_priority(node: Node, priority: int) -> Dictionary:
	node.process_priority = priority
	return _success({"path": _active_scene_path(node), "process_priority": priority}, "Process priority set")


func _set_physics_priority(node: Node, priority: int) -> Dictionary:
	node.process_physics_priority = priority
	return _success({"path": _active_scene_path(node), "physics_process_priority": priority}, "Physics process priority set")
