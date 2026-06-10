@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Animation track tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var player_result := _get_animation_player(args.get("path", ""))
	if not bool(player_result.get("success", false)):
		return player_result

	var player: AnimationPlayer = player_result.get("player")
	var animation_result := _get_animation(player, args.get("animation", ""))
	if not bool(animation_result.get("success", false)):
		return animation_result

	var animation: Animation = animation_result.get("animation")

	match action:
		"list":
			return _list_tracks(animation)
		"add_property_track":
			return _add_property_track(animation, args.get("node_path", ""))
		"add_method_track":
			return _add_method_track(animation, args.get("node_path", ""))
		"remove_track":
			return _remove_track(animation, args.get("track", -1))
		"add_key":
			return _add_key(player, animation, args)
		"remove_key":
			return _remove_key(animation, args.get("track", -1), args.get("key", -1))
		_:
			return _error("Unknown action: %s" % action)


func _get_animation_player(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if not node is AnimationPlayer:
		return _error("Node is not an AnimationPlayer")

	return {"success": true, "player": node}


func _get_animation(player: AnimationPlayer, animation_name: String) -> Dictionary:
	if animation_name.is_empty():
		return _error("Animation name is required")

	if not player.has_animation(animation_name):
		return _error("Animation not found: %s" % animation_name)

	return {"success": true, "animation": player.get_animation(animation_name)}


func _list_tracks(animation: Animation) -> Dictionary:
	var tracks: Array[Dictionary] = []
	for index in range(animation.get_track_count()):
		tracks.append({
			"index": index,
			"type": animation.track_get_type(index),
			"path": str(animation.track_get_path(index)),
			"key_count": animation.track_get_key_count(index)
		})

	return _success({
		"count": tracks.size(),
		"tracks": tracks
	})


func _add_property_track(animation: Animation, node_path: String) -> Dictionary:
	if node_path.is_empty():
		return _error("Node path is required")

	var track_index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, NodePath(node_path))
	animation.value_track_set_update_mode(track_index, Animation.UPDATE_CONTINUOUS)

	return _success({
		"track": track_index,
		"type": Animation.TYPE_VALUE,
		"path": node_path
	}, "Property track added")


func _add_method_track(animation: Animation, node_path: String) -> Dictionary:
	if node_path.is_empty():
		return _error("Node path is required")

	var track_index := animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(track_index, NodePath(node_path))

	return _success({
		"track": track_index,
		"type": Animation.TYPE_METHOD,
		"path": node_path
	}, "Method track added")


func _remove_track(animation: Animation, track_index: int) -> Dictionary:
	if not _is_valid_track(animation, track_index):
		return _error("Track index out of range: %s" % track_index)

	animation.remove_track(track_index)
	return _success({"track": track_index}, "Track removed")


func _add_key(player: AnimationPlayer, animation: Animation, args: Dictionary) -> Dictionary:
	var track_index := int(args.get("track", -1))
	if not _is_valid_track(animation, track_index):
		return _error("Track index out of range: %s" % track_index)

	var time := float(args.get("time", 0.0))
	var key_value = args.get("value", null)
	if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
		var method_name := str(args.get("method", ""))
		if not method_name.is_empty():
			key_value = {
				"method": method_name,
				"args": args.get("args", [])
			}

	if key_value == null:
		return _error("Key value is required")

	var normalized_value = _normalize_key_value(player, animation, track_index, key_value)
	var key_index := animation.track_insert_key(track_index, time, normalized_value)
	return _success({
		"track": track_index,
		"key": key_index,
		"time": time,
		"value": _serialize_value(normalized_value)
	}, "Key added")


func _remove_key(animation: Animation, track_index: int, key_index: int) -> Dictionary:
	if not _is_valid_track(animation, track_index):
		return _error("Track index out of range: %s" % track_index)

	if key_index < 0 or key_index >= animation.track_get_key_count(track_index):
		return _error("Key index out of range: %s" % key_index)

	animation.track_remove_key(track_index, key_index)
	return _success({
		"track": track_index,
		"key": key_index
	}, "Key removed")


func _is_valid_track(animation: Animation, track_index: int) -> bool:
	return track_index >= 0 and track_index < animation.get_track_count()


func _normalize_key_value(player: AnimationPlayer, animation: Animation, track_index: int, key_value):
	if animation.track_get_type(track_index) != Animation.TYPE_VALUE:
		return _normalize_input_value(key_value)

	var reference_result := _get_value_track_reference(player, animation.track_get_path(track_index))
	if not bool(reference_result.get("success", false)):
		return _normalize_input_value(key_value)

	return _normalize_input_value(key_value, reference_result.get("reference"))


func _get_value_track_reference(player: AnimationPlayer, track_path: NodePath) -> Dictionary:
	var property_path := _get_track_property_path(track_path)
	if property_path.is_empty():
		return {"success": false}

	var target_node := _get_track_target_node(player, track_path)
	if target_node == null:
		return {"success": false}

	if not target_node.has_method("get_indexed"):
		return {"success": false}

	return {
		"success": true,
		"reference": target_node.get_indexed(NodePath(property_path))
	}


func _get_track_target_node(player: AnimationPlayer, track_path: NodePath) -> Node:
	var node_path := _get_track_node_path(track_path)
	var root_node := _get_animation_root_node(player)
	if root_node == null:
		return null
	if node_path.is_empty() or node_path == ".":
		return root_node
	return root_node.get_node_or_null(NodePath(node_path))


func _get_animation_root_node(player: AnimationPlayer) -> Node:
	if player.root_node != NodePath(""):
		var root_candidate := player.get_node_or_null(player.root_node)
		if root_candidate != null:
			return root_candidate
	var scene_root: Node = _get_edited_scene_root()
	return scene_root if scene_root != null else player


func _get_track_node_path(track_path: NodePath) -> String:
	if track_path.get_name_count() <= 0:
		return "."
	var parts: Array[String] = []
	for index in range(track_path.get_name_count()):
		parts.append(str(track_path.get_name(index)))
	return "/".join(parts)


func _get_track_property_path(track_path: NodePath) -> String:
	if track_path.get_subname_count() <= 0:
		return ""
	var parts: Array[String] = []
	for index in range(track_path.get_subname_count()):
		parts.append(str(track_path.get_subname(index)))
	return ":".join(parts)
