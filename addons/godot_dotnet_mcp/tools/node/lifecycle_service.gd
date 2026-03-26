@tool
extends "res://addons/godot_dotnet_mcp/tools/node/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	match action:
		"create":
			return _create_node(args.get("type", "Node"), args.get("name", ""), args.get("parent_path", ""))
		"delete":
			return _delete_node(args.get("path", ""))
		"duplicate":
			return _duplicate_node(args.get("path", ""), args.get("new_name", ""), args.get("flags", []))
		"instantiate":
			return _instantiate_scene(args.get("scene_path", ""), args.get("parent_path", ""), args.get("name", ""))
		"replace":
			return _replace_node(args.get("path", ""), args.get("new_node_path", ""))
		"request_ready":
			return _request_ready(args.get("path", ""))
		"attach_script":
			return _attach_script(args)
		"rename":
			return _rename_node(args)
		_:
			return _error("Unknown action: %s" % action)


func _create_node(type_name: String, node_name: String, parent_path: String) -> Dictionary:
	if type_name.is_empty():
		return _error("Type is required")
	var parent = _find_active_node(parent_path) if not parent_path.is_empty() else _get_active_root()
	if not parent:
		return _error("Parent node not found: %s" % parent_path)
	var node = ClassDB.instantiate(type_name)
	if not node:
		return _error("Failed to create node of type: %s" % type_name)
	if not node_name.is_empty():
		node.name = node_name
	parent.add_child(node)
	node.owner = _get_active_root()
	return _success({
		"path": _active_scene_path(node),
		"type": type_name,
		"name": str(node.name)
	}, "Node created: %s" % str(node.name))


func _delete_node(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if node == _get_active_root():
		return _error("Cannot delete scene root node")
	var name = str(node.name)
	node.queue_free()
	return _success({"deleted": path}, "Node deleted: %s" % name)


func _duplicate_node(path: String, new_name: String, flags: Array) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	var flag_value = 0
	if "signals" in flags or flags.is_empty():
		flag_value |= Node.DUPLICATE_SIGNALS
	if "groups" in flags or flags.is_empty():
		flag_value |= Node.DUPLICATE_GROUPS
	if "scripts" in flags or flags.is_empty():
		flag_value |= Node.DUPLICATE_SCRIPTS
	var duplicated = node.duplicate(flag_value)
	if not duplicated:
		return _error("Failed to duplicate node")
	if not new_name.is_empty():
		duplicated.name = new_name
	var parent = node.get_parent()
	parent.add_child(duplicated)
	duplicated.owner = _get_active_root()
	return _success({
		"original": path,
		"new_path": _active_scene_path(duplicated),
		"name": str(duplicated.name)
	}, "Node duplicated: %s" % str(duplicated.name))


func _instantiate_scene(scene_path: String, parent_path: String, instance_name: String) -> Dictionary:
	if scene_path.is_empty():
		return _error("Scene path is required")
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path
	if not ResourceLoader.exists(scene_path):
		return _error("Scene not found: %s" % scene_path)
	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		return _error("Failed to load scene: %s" % scene_path)
	var instance = packed_scene.instantiate()
	if not instance:
		return _error("Failed to instantiate scene")
	if not instance_name.is_empty():
		instance.name = instance_name
	var parent = _find_active_node(parent_path) if not parent_path.is_empty() else _get_active_root()
	if not parent:
		instance.queue_free()
		return _error("Parent node not found: %s" % parent_path)
	parent.add_child(instance)
	instance.owner = _get_active_root()
	return _success({
		"scene": scene_path,
		"path": _active_scene_path(instance),
		"name": str(instance.name)
	}, "Scene instantiated: %s" % str(instance.name))


func _replace_node(path: String, new_node_path: String) -> Dictionary:
	if path.is_empty() or new_node_path.is_empty():
		return _error("Both paths are required")
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	var new_node = _find_active_node(new_node_path)
	if not new_node:
		return _error("New node not found: %s" % new_node_path)
	node.replace_by(new_node)
	return _success({
		"replaced": path,
		"replacement": _active_scene_path(new_node)
	}, "Node replaced")


func _request_ready(path: String) -> Dictionary:
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	node.request_ready()
	return _success({"path": path}, "Ready requested")


func _attach_script(args: Dictionary) -> Dictionary:
	var node_path := str(args.get("node_path", ""))
	var script_path := str(args.get("script_path", ""))
	if node_path.is_empty():
		return _error("node_path is required")
	if script_path.is_empty():
		return _error("script_path is required")
	var node = _find_active_node(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)
	var script = load(script_path)
	if script == null:
		return _error("Cannot load script: %s" % script_path)
	node.set_script(script)
	return _success({"node_path": node_path, "script_path": script_path}, "Script attached: %s -> %s" % [script_path, node_path])


func _rename_node(args: Dictionary) -> Dictionary:
	var node_path := str(args.get("node_path", ""))
	var new_name := str(args.get("new_name", "")).strip_edges()
	if node_path.is_empty():
		return _error("node_path is required")
	if new_name.is_empty():
		return _error("new_name is required")
	var node = _find_active_node(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)
	var old_name := str(node.name)
	node.name = new_name
	return _success({"old_name": old_name, "new_name": str(node.name)}, "Node renamed: %s -> %s" % [old_name, str(node.name)])
