@tool
extends "res://addons/godot_dotnet_mcp/tools/animation/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")
	var node_path = args.get("node", "")
	if path.is_empty():
		return _error("Path is required")
	var tree = _get_animation_tree(path)
	if tree == null:
		return _error("Node is not an AnimationTree")
	var blend_space = _get_blend_space_from_tree(tree, node_path)
	if not blend_space:
		if tree.tree_root is AnimationNodeBlendSpace1D or tree.tree_root is AnimationNodeBlendSpace2D:
			blend_space = tree.tree_root
		else:
			return _error("Blend space not found")
	var is_2d = blend_space is AnimationNodeBlendSpace2D
	match action:
		"add_point":
			return _add_blend_point(blend_space, is_2d, args)
		"remove_point":
			return _remove_blend_point(blend_space, args.get("point_index", 0))
		"set_blend_mode":
			return _set_blend_mode(blend_space, is_2d, args.get("blend_mode", "interpolated"))
		"get_points":
			return _get_blend_points(blend_space, is_2d)
		"set_min_max":
			return _set_blend_bounds(blend_space, is_2d, args)
		"set_snap":
			return _set_blend_snap(blend_space, is_2d, args.get("snap", 0.1))
		"triangulate":
			if is_2d:
				return _success({"note": "Triangulation is automatic in Godot 4"})
			return _error("Triangulate is only for 2D blend spaces")
		_:
			return _error("Unknown action: %s" % action)


func _add_blend_point(blend_space, is_2d: bool, args: Dictionary) -> Dictionary:
	var animation = args.get("animation", "")
	var position = args.get("position")
	if animation.is_empty():
		return _error("Animation name is required")
	var anim_node = AnimationNodeAnimation.new()
	anim_node.animation = animation
	if is_2d:
		var pos = Vector2.ZERO
		if position is Dictionary:
			pos = Vector2(position.get("x", 0), position.get("y", 0))
		elif position is float or position is int:
			pos = Vector2(position, 0)
		blend_space.add_blend_point(anim_node, pos)
		var idx = _find_blend_point_index(blend_space, anim_node, pos, true)
		return _success({"point_index": idx, "animation": animation, "position": {"x": pos.x, "y": pos.y}}, "Blend point added")
	var pos1d = 0.0
	if position is float or position is int:
		pos1d = float(position)
	elif position is Dictionary:
		pos1d = float(position.get("x", 0))
	blend_space.add_blend_point(anim_node, pos1d)
	var idx1d = _find_blend_point_index(blend_space, anim_node, pos1d, false)
	return _success({"point_index": idx1d, "animation": animation, "position": pos1d}, "Blend point added")


func _remove_blend_point(blend_space, index: int) -> Dictionary:
	if index < 0 or index >= blend_space.get_blend_point_count():
		return _error("Point index out of range")
	blend_space.remove_blend_point(index)
	return _success({"removed_index": index}, "Blend point removed")


func _set_blend_mode(blend_space, is_2d: bool, mode: String) -> Dictionary:
	if not is_2d:
		return _error("Blend mode is only for 2D blend spaces")
	match mode:
		"interpolated":
			blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
		"discrete":
			blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE
		"discrete_carry":
			blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE_CARRY
		_:
			return _error("Unknown blend mode: %s" % mode)
	return _success({"blend_mode": mode}, "Blend mode set")


func _get_blend_points(blend_space, is_2d: bool) -> Dictionary:
	var points: Array[Dictionary] = []
	var count = blend_space.get_blend_point_count()
	for i in range(count):
		var node = blend_space.get_blend_point_node(i)
		var anim_name = ""
		if node is AnimationNodeAnimation:
			anim_name = node.animation
		var pos = blend_space.get_blend_point_position(i)
		if is_2d:
			points.append({"index": i, "animation": anim_name, "position": {"x": pos.x, "y": pos.y}})
		else:
			points.append({"index": i, "animation": anim_name, "position": pos})
	return _success({"count": count, "points": points})


func _set_blend_bounds(blend_space, is_2d: bool, args: Dictionary) -> Dictionary:
	if is_2d:
		if args.has("min_x"):
			blend_space.min_space.x = args.get("min_x", -1)
		if args.has("max_x"):
			blend_space.max_space.x = args.get("max_x", 1)
		if args.has("min_y"):
			blend_space.min_space.y = args.get("min_y", -1)
		if args.has("max_y"):
			blend_space.max_space.y = args.get("max_y", 1)
		return _success({"min_space": {"x": blend_space.min_space.x, "y": blend_space.min_space.y}, "max_space": {"x": blend_space.max_space.x, "y": blend_space.max_space.y}}, "Bounds set")
	blend_space.min_space = args.get("min", -1)
	blend_space.max_space = args.get("max", 1)
	return _success({"min_space": blend_space.min_space, "max_space": blend_space.max_space}, "Bounds set")


func _set_blend_snap(blend_space, is_2d: bool, snap: float) -> Dictionary:
	if is_2d:
		blend_space.snap = Vector2(snap, snap)
	else:
		blend_space.snap = snap
	return _success({"snap": snap}, "Snap set")
