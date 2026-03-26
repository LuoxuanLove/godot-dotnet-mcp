@tool
extends "res://addons/godot_dotnet_mcp/tools/animation/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")
	var player = _get_animation_player(path)
	if player == null:
		return _error("Node is not an AnimationPlayer")
	match action:
		"create":
			return _create_animation(player, args.get("name", ""), args.get("length", 1.0))
		"delete":
			return _delete_animation(player, args.get("name", ""))
		"duplicate":
			return _duplicate_animation(player, args.get("name", ""), args.get("new_name", ""))
		"rename":
			return _rename_animation(player, args.get("name", ""), args.get("new_name", ""))
		"get_info":
			return _get_animation_info(player, args.get("name", ""))
		"set_length":
			return _set_animation_length(player, args.get("name", ""), args.get("length", 1.0))
		"set_loop":
			return _set_animation_loop(player, args.get("name", ""), args.get("loop", true))
		_:
			return _error("Unknown action: %s" % action)


func _create_animation(player: AnimationPlayer, anim_name: String, length: float) -> Dictionary:
	if anim_name.is_empty():
		return _error("Animation name is required")
	if player.has_animation(anim_name):
		return _error("Animation already exists: %s" % anim_name)
	var anim = Animation.new()
	anim.length = length
	var library = player.get_animation_library("")
	if not library:
		library = AnimationLibrary.new()
		player.add_animation_library("", library)
	library.add_animation(anim_name, anim)
	return _success({"path": _active_scene_path(player), "name": anim_name, "length": length}, "Animation created")


func _delete_animation(player: AnimationPlayer, anim_name: String) -> Dictionary:
	if anim_name.is_empty():
		return _error("Animation name is required")
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var library = player.get_animation_library("")
	if library:
		library.remove_animation(anim_name)
	return _success({"path": _active_scene_path(player), "name": anim_name}, "Animation deleted")


func _duplicate_animation(player: AnimationPlayer, anim_name: String, new_name: String) -> Dictionary:
	if anim_name.is_empty():
		return _error("Animation name is required")
	if new_name.is_empty():
		return _error("New name is required")
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	if player.has_animation(new_name):
		return _error("Animation already exists: %s" % new_name)
	var anim = player.get_animation(anim_name)
	var duplicate = anim.duplicate()
	var library = player.get_animation_library("")
	if not library:
		library = AnimationLibrary.new()
		player.add_animation_library("", library)
	library.add_animation(new_name, duplicate)
	return _success({"path": _active_scene_path(player), "original": anim_name, "duplicate": new_name}, "Animation duplicated")


func _rename_animation(player: AnimationPlayer, anim_name: String, new_name: String) -> Dictionary:
	if anim_name.is_empty():
		return _error("Animation name is required")
	if new_name.is_empty():
		return _error("New name is required")
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	if player.has_animation(new_name):
		return _error("Animation already exists: %s" % new_name)
	var library = player.get_animation_library("")
	if library:
		library.rename_animation(anim_name, new_name)
	return _success({"path": _active_scene_path(player), "old_name": anim_name, "new_name": new_name}, "Animation renamed")


func _get_animation_info(player: AnimationPlayer, anim_name: String) -> Dictionary:
	if anim_name.is_empty():
		return _error("Animation name is required")
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim = player.get_animation(anim_name)
	return _success({
		"path": _active_scene_path(player),
		"name": anim_name,
		"length": anim.length,
		"loop_mode": anim.loop_mode,
		"track_count": anim.get_track_count(),
		"step": anim.step
	})


func _set_animation_length(player: AnimationPlayer, anim_name: String, length: float) -> Dictionary:
	if anim_name.is_empty():
		return _error("Animation name is required")
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim = player.get_animation(anim_name)
	anim.length = length
	return _success({"path": _active_scene_path(player), "name": anim_name, "length": length}, "Animation length set")


func _set_animation_loop(player: AnimationPlayer, anim_name: String, loop: bool) -> Dictionary:
	if anim_name.is_empty():
		return _error("Animation name is required")
	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim = player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return _success({"path": _active_scene_path(player), "name": anim_name, "loop": loop}, "Animation loop set")
