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
		"reparent":
			return _reparent_node(node, args.get("new_parent", ""), args.get("keep_global", true))
		"reorder":
			return _reorder_node(node, args.get("index", 0))
		"move_up":
			return _move_sibling(node, -1)
		"move_down":
			return _move_sibling(node, 1)
		"move_to_front":
			return _move_to_front(node)
		"move_to_back":
			return _move_to_back(node)
		"set_owner":
			return _set_owner(node, args.get("owner_path", ""))
		"get_owner":
			return _get_owner(node)
		_:
			return _error("Unknown action: %s" % action)


func _reparent_node(node: Node, new_parent_path: String, keep_global: bool) -> Dictionary:
	if new_parent_path.is_empty():
		return _error("New parent path is required")
	var new_parent = _find_active_node(new_parent_path)
	if not new_parent:
		return _error("New parent not found: %s" % new_parent_path)
	if node == _get_active_root():
		return _error("Cannot reparent scene root")
	var old_parent_path = _active_scene_path(node.get_parent())
	node.reparent(new_parent, keep_global)
	node.owner = _get_active_root()
	return _success({
		"path": _active_scene_path(node),
		"old_parent": old_parent_path,
		"new_parent": new_parent_path,
		"keep_global": keep_global
	}, "Node reparented")


func _reorder_node(node: Node, index: int) -> Dictionary:
	var parent = node.get_parent()
	if not parent:
		return _error("Node has no parent")
	parent.move_child(node, index)
	return _success({"path": _active_scene_path(node), "new_index": node.get_index()}, "Node reordered")


func _move_sibling(node: Node, direction: int) -> Dictionary:
	var parent = node.get_parent()
	if not parent:
		return _error("Node has no parent")
	var current_index = node.get_index()
	var new_index = current_index + direction
	if new_index < 0 or new_index >= parent.get_child_count():
		return _error("Cannot move node further in that direction")
	parent.move_child(node, new_index)
	return _success({"path": _active_scene_path(node), "old_index": current_index, "new_index": node.get_index()}, "Node moved")


func _move_to_front(node: Node) -> Dictionary:
	var parent = node.get_parent()
	if not parent:
		return _error("Node has no parent")
	parent.move_child(node, parent.get_child_count() - 1)
	return _success({"path": _active_scene_path(node), "new_index": node.get_index()}, "Node moved to front")


func _move_to_back(node: Node) -> Dictionary:
	var parent = node.get_parent()
	if not parent:
		return _error("Node has no parent")
	parent.move_child(node, 0)
	return _success({"path": _active_scene_path(node), "new_index": node.get_index()}, "Node moved to back")


func _set_owner(node: Node, owner_path: String) -> Dictionary:
	var new_owner = _find_active_node(owner_path) if not owner_path.is_empty() else _get_active_root()
	if not new_owner:
		return _error("Owner not found: %s" % owner_path)
	node.owner = new_owner
	return _success({"path": _active_scene_path(node), "owner": _active_scene_path(new_owner)}, "Owner set")


func _get_owner(node: Node) -> Dictionary:
	var owner = node.owner
	return _success({"path": _active_scene_path(node), "owner": _active_scene_path(owner) if owner else null})
