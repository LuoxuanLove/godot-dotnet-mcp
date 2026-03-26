@tool
extends "res://addons/godot_dotnet_mcp/tools/animation/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")
	match action:
		"create":
			return _create_animation_tree(args)
		"get":
			return _read_animation_tree(path)
		"set_active":
			return _set_tree_active(path, args.get("active", true))
		"set_root":
			return _set_tree_root(path, args.get("root_type", "state_machine"))
		"set_player":
			return _set_tree_player(path, args.get("player", ""))
		"set_parameter":
			return _set_tree_parameter(path, args.get("parameter", ""), args.get("value"))
		"get_parameters":
			return _get_tree_parameters(path)
		_:
			return _error("Unknown action: %s" % action)


func _create_animation_tree(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var name = args.get("name", "AnimationTree")
	var root_type = args.get("root_type", "state_machine")
	var parent = _find_active_node(path)
	if not parent:
		return _error("Parent node not found: %s" % path)
	var tree = AnimationTree.new()
	tree.name = name
	var root_node = _create_animation_node(root_type)
	if not root_node:
		return _error("Unknown root type: %s" % root_type)
	tree.tree_root = root_node
	parent.add_child(tree)
	tree.owner = parent.owner if parent.owner else parent
	return _success({"path": _active_scene_path(tree), "name": name, "root_type": root_type}, "AnimationTree created")


func _read_animation_tree(path: String) -> Dictionary:
	var tree = _get_animation_tree(path)
	if tree == null:
		return _error("Node is not an AnimationTree")
	var root_type = ""
	if tree.tree_root:
		root_type = tree.tree_root.get_class()
	return _success({
		"path": _active_scene_path(tree),
		"active": tree.active,
		"root_type": root_type,
		"anim_player": str(tree.anim_player) if tree.anim_player else "",
		"advance_expression_base_node": str(tree.advance_expression_base_node)
	})


func _set_tree_active(path: String, active: bool) -> Dictionary:
	var tree = _get_animation_tree(path)
	if tree == null:
		return _error("Node is not an AnimationTree")
	tree.active = active
	return _success({"path": _active_scene_path(tree), "active": active}, "AnimationTree %s" % ("activated" if active else "deactivated"))


func _set_tree_root(path: String, root_type: String) -> Dictionary:
	var tree = _get_animation_tree(path)
	if tree == null:
		return _error("Node is not an AnimationTree")
	var root_node = _create_animation_node(root_type)
	if not root_node:
		return _error("Unknown root type: %s" % root_type)
	tree.tree_root = root_node
	return _success({"path": _active_scene_path(tree), "root_type": root_type}, "Root node set")


func _set_tree_player(path: String, player_path: String) -> Dictionary:
	var tree = _get_animation_tree(path)
	if tree == null:
		return _error("Node is not an AnimationTree")
	var player = _get_animation_player(player_path)
	if player == null:
		return _error("Node is not an AnimationPlayer: %s" % player_path)
	tree.anim_player = tree.get_path_to(player)
	return _success({"path": _active_scene_path(tree), "player": str(tree.anim_player)}, "AnimationPlayer assigned")


func _set_tree_parameter(path: String, parameter: String, value) -> Dictionary:
	var tree = _get_animation_tree(path)
	if tree == null:
		return _error("Node is not an AnimationTree")
	if parameter.is_empty():
		return _error("Parameter path is required")
	var converted_value = _convert_track_value(value)
	tree.set(parameter, converted_value)
	return _success({"path": _active_scene_path(tree), "parameter": parameter, "value": _serialize_value(converted_value)}, "Parameter set")


func _get_tree_parameters(path: String) -> Dictionary:
	var tree = _get_animation_tree(path)
	if tree == null:
		return _error("Node is not an AnimationTree")
	var params: Array[Dictionary] = []
	for prop in tree.get_property_list():
		var prop_name = str(prop.name)
		if prop_name.begins_with("parameters/"):
			params.append({"name": prop_name, "value": _serialize_value(tree.get(prop_name)), "type": prop.type})
	return _success({"path": _active_scene_path(tree), "count": params.size(), "parameters": params})
