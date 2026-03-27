@tool
extends "res://addons/godot_dotnet_mcp/tools/scene/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"get_tree":
			return _get_scene_tree(int(args.get("depth", -1)), bool(args.get("include_internal", false)))
		"get_selected":
			return _get_selected_nodes()
		"select":
			return _select_nodes(args.get("paths", []))
		_:
			return _error("Unknown action: %s" % action)


func _get_scene_tree(max_depth: int, include_internal: bool) -> Dictionary:
	var root := _get_active_root()
	if root == null:
		return _error("No scene open")

	return _success({
		"scene_path": _get_active_scene_path(),
		"root": _build_tree_recursive(root, 0, max_depth, include_internal)
	})


func _get_selected_nodes() -> Dictionary:
	var selection = _get_active_selection()
	if selection == null:
		return _error("Selection not available")

	var nodes: Array[Dictionary] = []
	for node in selection.get_selected_nodes():
		nodes.append(_scene_node_to_dict(node))

	return _success({
		"count": nodes.size(),
		"nodes": nodes
	})


func _select_nodes(paths: Array) -> Dictionary:
	var selection = _get_active_selection()
	if selection == null:
		return _error("Selection not available")

	selection.clear()

	var selected_count := 0
	var errors: Array[String] = []
	for path in paths:
		var node = _find_active_node(str(path))
		if node != null:
			selection.add_node(node)
			selected_count += 1
		else:
			errors.append("Node not found: %s" % str(path))

	return _success({
		"selected": selected_count,
		"requested": paths.size(),
		"errors": errors
	}, "Selected %d nodes" % selected_count)


func _build_tree_recursive(node: Node, current_depth: int, max_depth: int, include_internal: bool) -> Dictionary:
	var result := _scene_node_to_dict(node)
	if max_depth >= 0 and current_depth >= max_depth:
		result["children_truncated"] = node.get_child_count(include_internal) > 0
		return result

	var children: Array[Dictionary] = []
	for i in node.get_child_count(include_internal):
		children.append(_build_tree_recursive(node.get_child(i, include_internal), current_depth + 1, max_depth, include_internal))

	if not children.is_empty():
		result["children"] = children
	return result
