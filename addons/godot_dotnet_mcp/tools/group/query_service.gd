@tool
extends "res://addons/godot_dotnet_mcp/tools/group/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"list":
			return _list_node_groups(str(args.get("path", "")))
		"is_in":
			return _is_in_group(str(args.get("path", "")), str(args.get("group", "")))
		"get_nodes":
			return _get_nodes_in_group_result(str(args.get("group", "")))
		_:
			return _error("Unknown action: %s" % action)


func _list_node_groups(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var groups: Array[String] = []
	for group_name in node.get_groups():
		var normalized_group := str(group_name)
		if not normalized_group.begins_with("_"):
			groups.append(normalized_group)

	return _success({
		"path": path,
		"count": groups.size(),
		"groups": groups
	})


func _is_in_group(path: String, group_name: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if group_name.is_empty():
		return _error("Group name is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	return _success({
		"path": path,
		"group": group_name,
		"is_in_group": node.is_in_group(group_name)
	})


func _get_nodes_in_group_result(group_name: String) -> Dictionary:
	if group_name.is_empty():
		return _error("Group name is required")

	var nodes := _get_group_nodes(group_name)
	var node_list: Array[Dictionary] = []
	for node in nodes:
		node_list.append({
			"path": _get_scene_path(node),
			"type": node.get_class(),
			"name": str(node.name)
		})

	return _success({
		"group": group_name,
		"count": node_list.size(),
		"nodes": node_list
	})
