@tool
extends "res://addons/godot_dotnet_mcp/tools/node/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	match action:
		"find_by_name":
			return _find_by_name(args.get("pattern", ""))
		"find_by_type":
			return _find_by_type(args.get("type", ""))
		"find_children":
			return _find_children(args)
		"find_parent":
			return _find_parent(args.get("path", ""), args.get("pattern", ""))
		"get_info":
			return _get_node_info(args.get("path", ""))
		"get_children":
			return _get_node_children(args.get("path", ""))
		"get_path_to":
			return _get_path_to(args.get("from_path", ""), args.get("to_path", ""))
		"tree_string":
			return _get_tree_string(args.get("path", ""))
		_:
			return _error("Unknown action: %s" % action)


func _find_by_name(pattern: String) -> Dictionary:
	if pattern.is_empty():
		return _error("Pattern is required")
	var nodes = _find_nodes_by_name_in_context(pattern)
	var results: Array[Dictionary] = []
	for node in nodes:
		results.append(_node_to_active_dict(node, false))
	return _success({"count": results.size(), "nodes": results})


func _find_by_type(type_name: String) -> Dictionary:
	if type_name.is_empty():
		return _error("Type is required")
	var nodes = _find_nodes_by_type_in_context(type_name)
	var results: Array[Dictionary] = []
	for node in nodes:
		results.append(_node_to_active_dict(node, false))
	return _success({"count": results.size(), "nodes": results})


func _find_children(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var pattern = args.get("pattern", "*")
	var type_filter = args.get("type", "")
	var recursive = args.get("recursive", true)
	var owned = args.get("owned", true)
	var node = _find_active_node(path) if not path.is_empty() else _get_active_root()
	if not node:
		return _error("Node not found: %s" % path)
	var found = node.find_children(pattern, type_filter, recursive, owned)
	var results: Array[Dictionary] = []
	for child in found:
		results.append(_node_to_active_dict(child, false))
	return _success({"count": results.size(), "nodes": results})


func _find_parent(path: String, pattern: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if pattern.is_empty():
		return _error("Pattern is required")
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	var found = node.find_parent(pattern)
	if found:
		return _success(_node_to_active_dict(found, false))
	return _success({"found": false, "message": "No parent matching pattern found"})


func _get_node_info(path: String) -> Dictionary:
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	var info = _node_to_active_dict(node, true, 1)
	info["class_name"] = str(node.get_class())
	info["child_count"] = node.get_child_count()
	info["has_script"] = node.get_script() != null
	info["is_inside_tree"] = node.is_inside_tree()
	info["is_ready"] = node.is_node_ready()
	var groups: Array[String] = []
	for group in node.get_groups():
		groups.append(str(group))
	info["groups"] = groups
	info["processing"] = node.is_processing()
	info["physics_processing"] = node.is_physics_processing()
	info["process_mode"] = node.process_mode
	var owner = node.owner
	info["owner"] = _active_scene_path(owner) if owner else null
	return _success(info)


func _get_node_children(path: String) -> Dictionary:
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	var children: Array[Dictionary] = []
	for child in node.get_children():
		children.append(_node_to_active_dict(child, false))
	return _success({"path": path, "count": children.size(), "children": children})


func _get_path_to(from_path: String, to_path: String) -> Dictionary:
	var from_node = _find_active_node(from_path)
	if not from_node:
		return _error("From node not found: %s" % from_path)
	var to_node = _find_active_node(to_path)
	if not to_node:
		return _error("To node not found: %s" % to_path)
	var relative_path = from_node.get_path_to(to_node)
	return _success({
		"from": from_path,
		"to": to_path,
		"relative_path": str(relative_path)
	})


func _get_tree_string(path: String) -> Dictionary:
	var node = _find_active_node(path) if not path.is_empty() else _get_active_root()
	if not node:
		return _error("Node not found")
	return _success({"tree": _build_tree_string(node, 0)})


func _build_tree_string(node: Node, depth: int) -> String:
	var indent = "  ".repeat(depth)
	var result = indent + str(node.name) + " (" + str(node.get_class()) + ")\n"
	for child in node.get_children():
		result += _build_tree_string(child, depth + 1)
	return result
