@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Animation player tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")

	if path.is_empty():
		return _error("Path is required")

	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if not node is AnimationPlayer:
		return _error("Node is not an AnimationPlayer")

	var player: AnimationPlayer = node

	match action:
		"list":
			return _list_animations(player)
		"play":
			return _play_animation(player, args.get("animation", ""), args.get("backwards", false))
		"stop":
			return _stop_animation(player)
		"pause":
			return _pause_animation(player)
		"seek":
			return _seek_animation(player, args.get("time", 0.0))
		"get_current":
			return _get_current_animation(player)
		"set_speed":
			return _set_playback_speed(player, args.get("speed", 1.0))
		_:
			return _error("Unknown action: %s" % action)


func _list_animations(player: AnimationPlayer) -> Dictionary:
	var animations: Array[String] = []
	for anim_name in player.get_animation_list():
		animations.append(str(anim_name))

	return _success({
		"path": _get_scene_path(player),
		"count": animations.size(),
		"animations": animations
	})


func _play_animation(player: AnimationPlayer, anim_name: String, backwards: bool) -> Dictionary:
	if anim_name.is_empty():
		return _error("Animation name is required")

	if not player.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)

	if backwards:
		player.play_backwards(anim_name)
	else:
		player.play(anim_name)

	return _success({
		"path": _get_scene_path(player),
		"animation": anim_name,
		"backwards": backwards
	}, "Animation playing")


func _stop_animation(player: AnimationPlayer) -> Dictionary:
	player.stop()
	return _success({"path": _get_scene_path(player)}, "Animation stopped")


func _pause_animation(player: AnimationPlayer) -> Dictionary:
	player.pause()
	return _success({"path": _get_scene_path(player)}, "Animation paused")


func _seek_animation(player: AnimationPlayer, time: float) -> Dictionary:
	player.seek(time)
	return _success({"path": _get_scene_path(player), "time": time}, "Seeked to time")


func _get_current_animation(player: AnimationPlayer) -> Dictionary:
	var current = player.current_animation
	var playing = player.is_playing()

	return _success({
		"path": _get_scene_path(player),
		"current_animation": str(current),
		"is_playing": playing,
		"current_position": player.current_animation_position if playing else 0.0,
		"playback_speed": player.speed_scale
	})


func _set_playback_speed(player: AnimationPlayer, speed: float) -> Dictionary:
	player.speed_scale = speed
	return _success({"path": _get_scene_path(player), "speed": speed}, "Playback speed set")
