@tool
extends "res://addons/godot_dotnet_mcp/tools/animation/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")
	var anim_name = args.get("animation", "")
	if path.is_empty():
		return _error("Path is required")
	var player = _get_animation_player(path)
	if player == null:
		return _error("Node is not an AnimationPlayer")
	if anim_name.is_empty() and action != "list":
		return _error("Animation name is required")
	match action:
		"list":
			return _list_tracks(player, anim_name)
		"add_property_track":
			return _add_property_track(player, anim_name, args.get("node_path", ""))
		"add_method_track":
			return _add_method_track(player, anim_name, args.get("node_path", ""))
		"remove_track":
			return _remove_track(player, anim_name, args.get("track", 0))
		"add_key":
			return _add_key(player, anim_name, args.get("track", 0), args.get("time", 0.0), args.get("value"))
		"remove_key":
			return _remove_key(player, anim_name, args.get("track", 0), args.get("key", 0))
		_:
			return _error("Unknown action: %s" % action)


func _list_tracks(player: AnimationPlayer, anim_name: String) -> Dictionary:
	if anim_name.is_empty():
		return _error("Animation name is required")
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim = player.get_animation(anim_name)
	var tracks: Array[Dictionary] = []
	for i in anim.get_track_count():
		tracks.append({"index": i, "path": str(anim.track_get_path(i)), "type": anim.track_get_type(i), "key_count": anim.track_get_key_count(i)})
	return _success({"path": _active_scene_path(player), "animation": anim_name, "track_count": tracks.size(), "tracks": tracks})


func _add_property_track(player: AnimationPlayer, anim_name: String, node_path: String) -> Dictionary:
	if node_path.is_empty():
		return _error("Node path is required")
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim = player.get_animation(anim_name)
	var track_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, NodePath(node_path))
	return _success({"path": _active_scene_path(player), "animation": anim_name, "track_index": track_idx, "node_path": node_path}, "Property track added")


func _add_method_track(player: AnimationPlayer, anim_name: String, node_path: String) -> Dictionary:
	if node_path.is_empty():
		return _error("Node path is required")
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim = player.get_animation(anim_name)
	var track_idx = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(track_idx, NodePath(node_path))
	return _success({"path": _active_scene_path(player), "animation": anim_name, "track_index": track_idx, "node_path": node_path}, "Method track added")


func _remove_track(player: AnimationPlayer, anim_name: String, track_idx: int) -> Dictionary:
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim = player.get_animation(anim_name)
	if track_idx < 0 or track_idx >= anim.get_track_count():
		return _error("Track index out of range")
	anim.remove_track(track_idx)
	return _success({"path": _active_scene_path(player), "animation": anim_name, "removed_track": track_idx}, "Track removed")


func _add_key(player: AnimationPlayer, anim_name: String, track_idx: int, time: float, value) -> Dictionary:
	if not player.has_animation(anim_name):
		var available = player.get_animation_list()
		return _error("Animation not found: %s" % anim_name, null, ["Available animations: %s" % ", ".join(available)] if available.size() > 0 else [])
	var anim = player.get_animation(anim_name)
	if track_idx < 0 or track_idx >= anim.get_track_count():
		return _error("Track index out of range: %d" % track_idx, {"track_count": anim.get_track_count()}, ["Valid track indices: 0 to %d" % (anim.get_track_count() - 1)] if anim.get_track_count() > 0 else ["Animation has no tracks. Add a track first."])
	if time < 0:
		return _error("Time cannot be negative", {"provided_time": time}, ["Time must be >= 0"])
	if time > anim.length:
		return _error("Time exceeds animation length", {"provided_time": time, "animation_length": anim.length}, ["Maximum time for this animation: %s seconds" % anim.length])
	var track_path = anim.track_get_path(track_idx)
	var track_type = anim.track_get_type(track_idx)
	if value == null:
		return _error("Value is required for keyframe", {"track_path": str(track_path), "track_type": track_type}, _get_value_hints_for_track(track_type, track_path))
	var expected_type = _get_expected_track_value_type(player, anim, track_idx, track_path)
	var reference_value = _get_track_reference_value(player, anim, track_idx, track_path)
	var converted_value = _normalize_input_value(value, reference_value) if reference_value != null else _convert_track_value(value)
	if expected_type != TYPE_NIL:
		var converted_type = typeof(converted_value)
		var validation = _validate_value_type(converted_value, expected_type)
		if not validation["valid"]:
			var hints = _get_value_hints_for_track(track_type, track_path)
			hints.append_array(validation["hints"])
			hints.append("Your value was interpreted as: %s" % _type_to_string(converted_type))
			return _error("Value type mismatch for track", {"track_path": str(track_path), "expected_type": _type_to_string(expected_type), "provided_type": _type_to_string(typeof(value)), "converted_type": _type_to_string(converted_type), "provided_value": value}, hints)
	var key_idx = anim.track_insert_key(track_idx, time, converted_value)
	if key_idx >= 0:
		var inserted_value = anim.track_get_key_value(track_idx, key_idx)
		var inserted_type = typeof(inserted_value)
		if expected_type != TYPE_NIL and inserted_type != expected_type:
			anim.track_remove_key(track_idx, key_idx)
			return _error("Keyframe value type invalid", {"track_path": str(track_path), "expected_type": _type_to_string(expected_type), "actual_type": _type_to_string(inserted_type), "provided_value": value}, _get_value_hints_for_track(track_type, track_path))
	return _success({"path": _active_scene_path(player), "animation": anim_name, "track": track_idx, "track_path": str(track_path), "key_index": key_idx, "time": time, "value": _serialize_value(converted_value)}, "Keyframe added")


func _remove_key(player: AnimationPlayer, anim_name: String, track_idx: int, key_idx: int) -> Dictionary:
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim = player.get_animation(anim_name)
	if track_idx < 0 or track_idx >= anim.get_track_count():
		return _error("Track index out of range")
	if key_idx < 0 or key_idx >= anim.track_get_key_count(track_idx):
		return _error("Key index out of range")
	anim.track_remove_key(track_idx, key_idx)
	return _success({"path": _active_scene_path(player), "animation": anim_name, "track": track_idx, "removed_key": key_idx}, "Keyframe removed")
