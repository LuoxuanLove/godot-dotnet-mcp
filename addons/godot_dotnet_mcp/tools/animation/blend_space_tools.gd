@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Blend space tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")
	var node_path = args.get("node", "")

	if path.is_empty():
		return _error("Path is required")

	var tree = _find_node_by_path(path)
	if not tree:
		return _error("Node not found: %s" % path)

	if not tree is AnimationTree:
		return _error("Node is not an AnimationTree")

	# Get blend space node
	var blend_space = _get_blend_space_from_tree(tree, node_path)
	if not blend_space:
		# Check if root is blend space
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
			else:
				return _error("Triangulate is only for 2D blend spaces")
		_:
			return _error("Unknown action: %s" % action)


func _get_blend_space_from_tree(tree: AnimationTree, node_path: String) -> AnimationRootNode:
	if node_path.is_empty():
		return null

	# Parse parameter path like "parameters/locomotion"
	var parts = node_path.split("/")
	if parts.size() < 2:
		return null

	# Navigate through the tree
	var current: AnimationRootNode = tree.tree_root
	for i in range(1, parts.size()):  # Skip "parameters"
		if current is AnimationNodeBlendTree:
			current = current.get_node(parts[i])
		elif current is AnimationNodeStateMachine:
			current = current.get_node(parts[i])
		else:
			return null

	return current


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
		return _success({
			"point_index": idx,
			"animation": animation,
			"position": {"x": pos.x, "y": pos.y}
		}, "Blend point added")
	else:
		var pos = 0.0
		if position is float or position is int:
			pos = float(position)
		elif position is Dictionary:
			pos = float(position.get("x", 0))

		blend_space.add_blend_point(anim_node, pos)
		var idx = _find_blend_point_index(blend_space, anim_node, pos, false)
		return _success({
			"point_index": idx,
			"animation": animation,
			"position": pos
		}, "Blend point added")


func _find_blend_point_index(blend_space, anim_node: AnimationNodeAnimation, position, is_2d: bool) -> int:
	for i in range(blend_space.get_blend_point_count()):
		if blend_space.get_blend_point_node(i) != anim_node:
			continue

		var current_position = blend_space.get_blend_point_position(i)
		if is_2d and current_position == position:
			return i
		if not is_2d and is_equal_approx(float(current_position), float(position)):
			return i

	return blend_space.get_blend_point_count() - 1


func _remove_blend_point(blend_space, index: int) -> Dictionary:
	if index < 0 or index >= blend_space.get_blend_point_count():
		return _error("Point index out of range")

	blend_space.remove_blend_point(index)
	return _success({
		"removed_index": index
	}, "Blend point removed")


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

	return _success({
		"blend_mode": mode
	}, "Blend mode set")


func _get_blend_points(blend_space, is_2d: bool) -> Dictionary:
	var points: Array[Dictionary] = []
	var count = blend_space.get_blend_point_count()

	for i in range(count):
		var node = blend_space.get_blend_point_node(i)
		var anim_name = ""
		if node is AnimationNodeAnimation:
			anim_name = node.animation

		if is_2d:
			var pos = blend_space.get_blend_point_position(i)
			points.append({
				"index": i,
				"animation": anim_name,
				"position": {"x": pos.x, "y": pos.y}
			})
		else:
			var pos = blend_space.get_blend_point_position(i)
			points.append({
				"index": i,
				"animation": anim_name,
				"position": pos
			})

	return _success({
		"count": count,
		"points": points
	})


func _set_blend_bounds(blend_space, is_2d: bool, args: Dictionary) -> Dictionary:
	if is_2d:
		var min_space: Vector2 = blend_space.min_space
		var max_space: Vector2 = blend_space.max_space
		if args.has("min_x"):
			min_space.x = args.get("min_x", -1)
		if args.has("max_x"):
			max_space.x = args.get("max_x", 1)
		if args.has("min_y"):
			min_space.y = args.get("min_y", -1)
		if args.has("max_y"):
			max_space.y = args.get("max_y", 1)

		blend_space.min_space = min_space
		blend_space.max_space = max_space

		return _success({
			"min_space": {"x": blend_space.min_space.x, "y": blend_space.min_space.y},
			"max_space": {"x": blend_space.max_space.x, "y": blend_space.max_space.y}
		}, "Bounds set")
	else:
		blend_space.min_space = args.get("min", -1)
		blend_space.max_space = args.get("max", 1)

		return _success({
			"min_space": blend_space.min_space,
			"max_space": blend_space.max_space
		}, "Bounds set")


func _set_blend_snap(blend_space, is_2d: bool, snap: float) -> Dictionary:
	if is_2d:
		blend_space.snap = Vector2(snap, snap)
	else:
		blend_space.snap = snap

	return _success({
		"snap": snap
	}, "Snap set")
