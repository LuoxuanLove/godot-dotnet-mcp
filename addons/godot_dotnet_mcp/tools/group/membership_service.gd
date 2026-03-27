@tool
extends "res://addons/godot_dotnet_mcp/tools/group/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"add":
			return _add_to_group(str(args.get("path", "")), str(args.get("group", "")))
		"remove":
			return _remove_from_group(str(args.get("path", "")), str(args.get("group", "")))
		_:
			return _error("Unknown action: %s" % action)


func _add_to_group(path: String, group_name: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if group_name.is_empty():
		return _error("Group name is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	if node.is_in_group(group_name):
		return _success({
			"path": path,
			"group": group_name,
			"already_in_group": true
		}, "Node already in group")

	node.add_to_group(group_name, true)
	return _success({
		"path": path,
		"group": group_name
	}, "Added to group")


func _remove_from_group(path: String, group_name: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if group_name.is_empty():
		return _error("Group name is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not node.is_in_group(group_name):
		return _error("Node is not in group: %s" % group_name)

	node.remove_from_group(group_name)
	return _success({
		"path": path,
		"group": group_name
	}, "Removed from group")
