@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

var _scene_root_override: Node = null


func configure_context(context: Dictionary = {}) -> void:
	_scene_root_override = context.get("scene_root", null)


func _get_active_root() -> Node:
	if _scene_root_override != null and is_instance_valid(_scene_root_override):
		return _scene_root_override
	return _get_edited_scene_root()


func _normalize_active_path(path: String, root: Node = null) -> String:
	if root == null:
		root = _get_active_root()
	if root == null:
		return path.strip_edges()

	var normalized = path.strip_edges()
	if normalized.is_empty() or normalized == "/" or normalized == ".":
		return "."

	var root_name = str(root.name)
	var root_path = str(root.get_path())
	var absolute_tree_prefix = "/root/"

	if normalized == "/root":
		return "."
	if normalized.begins_with(absolute_tree_prefix):
		normalized = normalized.substr(absolute_tree_prefix.length())
		if normalized == root_name:
			return "."
		if normalized.begins_with(root_name + "/"):
			return normalized.substr(root_name.length() + 1)
		if normalized.is_empty():
			return "."

	if normalized == root_name or normalized == "/" + root_name:
		return "."
	if normalized == root_path:
		return "."
	if normalized.begins_with(root_path + "/"):
		return normalized.substr(root_path.length() + 1)
	if normalized.begins_with(root_name + "/"):
		return normalized.substr(root_name.length() + 1)
	if normalized.begins_with("/" + root_name + "/"):
		return normalized.substr(root_name.length() + 2)
	if normalized.begins_with("./"):
		return normalized.substr(2)
	if normalized.begins_with("/"):
		return normalized.trim_prefix("/")
	return normalized


func _find_active_node(path: String) -> Node:
	var root := _get_active_root()
	if root == null:
		return null
	if _scene_root_override == null:
		return _find_node_by_path(path)
	var normalized := _normalize_active_path(path, root)
	if normalized.is_empty() or normalized == ".":
		return root
	if normalized.begins_with("/"):
		var absolute_node = root.get_node_or_null(NodePath(normalized))
		if absolute_node != null:
			return absolute_node
	return root.get_node_or_null(NodePath(normalized))


func _active_scene_path(node: Node) -> String:
	if not node or not node.is_inside_tree():
		return ""
	var scene_root := _get_active_root()
	if not scene_root:
		return str(node.get_path())
	if node == scene_root:
		return str(node.name)
	var node_path_str := str(node.get_path())
	var scene_path_str := str(scene_root.get_path())
	if node_path_str.begins_with(scene_path_str + "/"):
		return node_path_str.substr(scene_path_str.length() + 1)
	if node_path_str == scene_path_str:
		return str(node.name)
	return node_path_str


func _get_animation_player(path: String) -> AnimationPlayer:
	var node = _find_active_node(path)
	if node == null or not node is AnimationPlayer:
		return null
	return node as AnimationPlayer


func _get_animation_tree(path: String) -> AnimationTree:
	var node = _find_active_node(path)
	if node == null or not node is AnimationTree:
		return null
	return node as AnimationTree


func _create_animation_node(type: String) -> AnimationRootNode:
	match type:
		"state_machine":
			return AnimationNodeStateMachine.new()
		"blend_tree":
			return AnimationNodeBlendTree.new()
		"blend_space_1d":
			return AnimationNodeBlendSpace1D.new()
		"blend_space_2d":
			return AnimationNodeBlendSpace2D.new()
		"animation":
			return AnimationNodeAnimation.new()
		_:
			return null


func _convert_track_value(value):
	value = _parse_json_like_value(value)
	if value is Dictionary:
		if value.has("x") and value.has("y"):
			if value.has("z"):
				if value.has("w"):
					return Vector4(value.get("x", 0), value.get("y", 0), value.get("z", 0), value.get("w", 0))
				return Vector3(value.get("x", 0), value.get("y", 0), value.get("z", 0))
			return Vector2(value.get("x", 0), value.get("y", 0))
		if value.has("r") and value.has("g") and value.has("b"):
			return Color(value.get("r", 1), value.get("g", 1), value.get("b", 1), value.get("a", 1))
	return value


func _get_animation_root_node(player: AnimationPlayer) -> Node:
	if player.root_node.is_empty():
		return player.get_parent() if player.get_parent() != null else player
	var root = player.get_node_or_null(player.root_node)
	if root != null:
		return root
	return player.get_parent() if player.get_parent() != null else player


func _resolve_track_target(player: AnimationPlayer, track_path: NodePath) -> Dictionary:
	var path_str = str(track_path)
	var path_parts = path_str.split(":", true, 1)
	var node_path = path_parts[0] if not path_parts.is_empty() else ""
	var property_name = path_parts[1] if path_parts.size() > 1 else ""
	var root = _get_animation_root_node(player)
	var target_node: Node = null
	if root != null:
		if node_path.is_empty() or node_path == ".":
			target_node = root
		else:
			target_node = root.get_node_or_null(NodePath(node_path))
	if target_node == null and not node_path.is_empty():
		target_node = _find_active_node(node_path)
	return {"node": target_node, "property": property_name}


func _get_track_reference_value(player: AnimationPlayer, anim: Animation, track_idx: int, track_path: NodePath):
	var key_count = anim.track_get_key_count(track_idx)
	if key_count > 0:
		return anim.track_get_key_value(track_idx, 0)
	var target = _resolve_track_target(player, track_path)
	var node = target.get("node")
	var property_name = str(target.get("property", ""))
	if node != null and not property_name.is_empty():
		return node.get(property_name)
	return null


func _get_expected_track_value_type(player: AnimationPlayer, anim: Animation, track_idx: int, track_path: NodePath) -> int:
	var key_count = anim.track_get_key_count(track_idx)
	if key_count > 0:
		var existing_value = anim.track_get_key_value(track_idx, 0)
		var existing_type = typeof(existing_value)
		if existing_type != TYPE_STRING or not str(existing_value).begins_with("{"):
			return existing_type
	var reference_value = _get_track_reference_value(player, anim, track_idx, track_path)
	if reference_value != null:
		return typeof(reference_value)
	var path_str = str(track_path)
	if ":position" in path_str:
		return TYPE_VECTOR2
	elif ":rotation" in path_str:
		return TYPE_FLOAT
	elif ":scale" in path_str:
		return TYPE_VECTOR2
	elif ":modulate" in path_str or ":self_modulate" in path_str or ":color" in path_str:
		return TYPE_COLOR
	elif ":visible" in path_str:
		return TYPE_BOOL
	elif ":z_index" in path_str:
		return TYPE_INT
	return TYPE_NIL


func _get_value_hints_for_track(track_type: int, track_path: NodePath) -> Array:
	var hints: Array = []
	var path_str = str(track_path)
	match track_type:
		Animation.TYPE_VALUE:
			if ":position" in path_str:
				hints.append("For position, use: {\"x\": number, \"y\": number} or {\"x\": n, \"y\": n, \"z\": n} for 3D")
			elif ":rotation" in path_str:
				hints.append("For rotation, use a number (radians)")
			elif ":scale" in path_str:
				hints.append("For scale, use: {\"x\": number, \"y\": number}")
			elif ":modulate" in path_str or ":color" in path_str:
				hints.append("For color, use: {\"r\": 0-1, \"g\": 0-1, \"b\": 0-1, \"a\": 0-1}")
			elif ":visible" in path_str:
				hints.append("For visibility, use: true or false")
			else:
				hints.append("Value format depends on the property type")
				hints.append("Common formats: number, boolean, {\"x\": n, \"y\": n}, {\"r\": n, \"g\": n, \"b\": n, \"a\": n}")
		Animation.TYPE_METHOD:
			hints.append("For method tracks, value should be an array of arguments")
		Animation.TYPE_BEZIER:
			hints.append("For bezier tracks, value should be a number")
		Animation.TYPE_AUDIO:
			hints.append("For audio tracks, value should be an AudioStream resource path")
		Animation.TYPE_ANIMATION:
			hints.append("For animation tracks, value should be an animation name")
	return hints


func _get_blend_space_from_tree(tree: AnimationTree, node_path: String) -> AnimationRootNode:
	if node_path.is_empty():
		return null
	var parts = node_path.split("/")
	if parts.size() < 2:
		return null
	var current: AnimationRootNode = tree.tree_root
	for i in range(1, parts.size()):
		if current is AnimationNodeBlendTree:
			current = current.get_node(parts[i])
		elif current is AnimationNodeStateMachine:
			current = current.get_node(parts[i])
		else:
			return null
	return current


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
