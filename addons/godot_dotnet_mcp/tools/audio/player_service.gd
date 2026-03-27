@tool
extends "res://addons/godot_dotnet_mcp/tools/audio/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"list":
			return _list_audio_players()
		"get_info":
			return _get_player_info(str(args.get("path", "")))
		"play":
			return _play_audio(str(args.get("path", "")), float(args.get("from_position", 0.0)))
		"stop":
			return _stop_audio(str(args.get("path", "")))
		"pause":
			return _pause_audio(str(args.get("path", "")), bool(args.get("paused", true)))
		"seek":
			return _seek_audio(str(args.get("path", "")), float(args.get("position", 0.0)))
		"set_volume":
			return _set_player_volume(str(args.get("path", "")), float(args.get("volume_db", 0.0)))
		"set_pitch":
			return _set_player_pitch(str(args.get("path", "")), float(args.get("pitch_scale", 1.0)))
		"set_bus":
			return _set_player_bus(str(args.get("path", "")), str(args.get("bus", "Master")))
		"set_stream":
			return _set_player_stream(str(args.get("path", "")), str(args.get("stream", "")))
		_:
			return _error("Unknown action: %s" % action)


func _list_audio_players() -> Dictionary:
	var players: Array[Dictionary] = []
	var root := _get_active_root()
	if root == null:
		return _error("No scene open")

	_collect_audio_players(root, players)
	return _success({
		"count": players.size(),
		"players": players
	})


func _get_player_info(path: String) -> Dictionary:
	var player = _get_audio_player(path)
	if player == null:
		return _error("Audio player not found: %s" % path)

	var info := {
		"path": _get_scene_path(player),
		"type": str(player.get_class()),
		"playing": player.playing,
		"stream_paused": player.stream_paused,
		"volume_db": player.volume_db,
		"pitch_scale": player.pitch_scale,
		"bus": player.bus,
		"autoplay": player.autoplay
	}

	if player.stream:
		info["stream"] = str(player.stream.resource_path)
		info["stream_length"] = player.stream.get_length() if player.stream.has_method("get_length") else 0.0

	if player.playing:
		info["playback_position"] = player.get_playback_position()

	if player is AudioStreamPlayer2D:
		info["max_distance"] = player.max_distance
		info["attenuation"] = player.attenuation
	elif player is AudioStreamPlayer3D:
		info["max_db"] = player.max_db
		info["unit_size"] = player.unit_size
		info["max_distance"] = player.max_distance

	return _success(info)


func _play_audio(path: String, from_position: float) -> Dictionary:
	var player = _get_audio_player(path)
	if player == null:
		return _error("Audio player not found: %s" % path)
	if player.stream == null:
		return _error("No stream assigned to player")

	player.play(from_position)
	return _success({
		"path": path,
		"playing": true,
		"from_position": from_position
	}, "Playing audio")


func _stop_audio(path: String) -> Dictionary:
	var player = _get_audio_player(path)
	if player == null:
		return _error("Audio player not found: %s" % path)

	player.stop()
	return _success({
		"path": path,
		"playing": false
	}, "Stopped audio")


func _pause_audio(path: String, paused: bool) -> Dictionary:
	var player = _get_audio_player(path)
	if player == null:
		return _error("Audio player not found: %s" % path)

	player.stream_paused = paused
	return _success({
		"path": path,
		"paused": paused
	}, "Audio %s" % ("paused" if paused else "resumed"))


func _seek_audio(path: String, position: float) -> Dictionary:
	var player = _get_audio_player(path)
	if player == null:
		return _error("Audio player not found: %s" % path)
	if not player.playing:
		return _error("Player is not playing")

	player.seek(position)
	return _success({
		"path": path,
		"position": position
	}, "Seeked to position")


func _set_player_volume(path: String, volume_db: float) -> Dictionary:
	var player = _get_audio_player(path)
	if player == null:
		return _error("Audio player not found: %s" % path)

	player.volume_db = volume_db
	return _success({
		"path": path,
		"volume_db": volume_db
	}, "Volume set")


func _set_player_pitch(path: String, pitch_scale: float) -> Dictionary:
	var player = _get_audio_player(path)
	if player == null:
		return _error("Audio player not found: %s" % path)

	player.pitch_scale = pitch_scale
	return _success({
		"path": path,
		"pitch_scale": pitch_scale
	}, "Pitch set")


func _set_player_bus(path: String, bus: String) -> Dictionary:
	var player = _get_audio_player(path)
	if player == null:
		return _error("Audio player not found: %s" % path)
	if _get_bus_index(bus) < 0:
		return _error("Bus not found: %s" % bus)

	player.bus = bus
	return _success({
		"path": path,
		"bus": bus
	}, "Bus set")


func _set_player_stream(path: String, stream_path: String) -> Dictionary:
	var player = _get_audio_player(path)
	if player == null:
		return _error("Audio player not found: %s" % path)

	if stream_path.is_empty():
		player.stream = null
		return _success({"path": path, "stream": null}, "Stream cleared")

	var normalized_path := stream_path
	if not normalized_path.begins_with("res://"):
		normalized_path = "res://" + normalized_path
	if not ResourceLoader.exists(normalized_path):
		return _error("Stream not found: %s" % normalized_path)

	var stream = load(normalized_path)
	if stream == null or not stream is AudioStream:
		return _error("Invalid audio stream: %s" % normalized_path)

	player.stream = stream
	return _success({
		"path": path,
		"stream": normalized_path
	}, "Stream set")
