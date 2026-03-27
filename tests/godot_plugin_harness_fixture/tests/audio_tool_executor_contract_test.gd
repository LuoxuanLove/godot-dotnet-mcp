extends RefCounted

const AudioExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/audio/executor.gd")

const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_audio_contracts"
const STREAM_PATH := "res://Tmp/godot_dotnet_mcp_audio_contracts/contract_stream.tres"
const CONTRACT_BUS := "ContractBus"

var _scene_root: Node = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = AudioExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/audio_tools.gd"):
		return _failure("audio_tools.gd should be removed once the split executor becomes the only stable entry.")

	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_remove_contract_bus()

	if not _create_audio_stream(STREAM_PATH):
		return _failure("Failed to create an audio stream fixture for the split audio services.")

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 2:
		return _failure("Audio executor should expose 2 tool definitions after the split.")

	var expected_names := ["bus", "player"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Audio executor is missing tool definition '%s'." % expected_name)

	var list_buses_result: Dictionary = executor.execute("bus", {"action": "list"})
	if not bool(list_buses_result.get("success", false)):
		return _failure("Bus list failed through the split bus service.")

	var add_bus_result: Dictionary = executor.execute("bus", {
		"action": "add",
		"bus": CONTRACT_BUS
	})
	if not bool(add_bus_result.get("success", false)):
		return _failure("Bus add failed through the split bus service.")

	var set_volume_result: Dictionary = executor.execute("bus", {
		"action": "set_volume",
		"bus": CONTRACT_BUS,
		"volume_db": -6.0
	})
	if not bool(set_volume_result.get("success", false)):
		return _failure("Bus set_volume failed through the split bus service.")

	var set_mute_result: Dictionary = executor.execute("bus", {
		"action": "set_mute",
		"bus": CONTRACT_BUS,
		"mute": true
	})
	if not bool(set_mute_result.get("success", false)):
		return _failure("Bus set_mute failed through the split bus service.")

	var add_effect_result: Dictionary = executor.execute("bus", {
		"action": "add_effect",
		"bus": CONTRACT_BUS,
		"effect": "AudioEffectReverb",
		"at_position": 0
	})
	if not bool(add_effect_result.get("success", false)):
		return _failure("Bus add_effect failed through the split bus service.")

	var get_effect_result: Dictionary = executor.execute("bus", {
		"action": "get_effect",
		"bus": CONTRACT_BUS,
		"effect_index": 0
	})
	if not bool(get_effect_result.get("success", false)):
		return _failure("Bus get_effect failed through the split bus service.")

	var disable_effect_result: Dictionary = executor.execute("bus", {
		"action": "set_effect_enabled",
		"bus": CONTRACT_BUS,
		"effect_index": 0,
		"enabled": false
	})
	if not bool(disable_effect_result.get("success", false)):
		return _failure("Bus set_effect_enabled failed through the split bus service.")

	var remove_effect_result: Dictionary = executor.execute("bus", {
		"action": "remove_effect",
		"bus": CONTRACT_BUS,
		"effect_index": 0
	})
	if not bool(remove_effect_result.get("success", false)):
		return _failure("Bus remove_effect failed through the split bus service.")

	var get_bus_info_result: Dictionary = executor.execute("bus", {
		"action": "get_info",
		"bus": CONTRACT_BUS
	})
	if not bool(get_bus_info_result.get("success", false)):
		return _failure("Bus get_info failed through the split bus service.")

	var list_players_result: Dictionary = executor.execute("player", {"action": "list"})
	if not bool(list_players_result.get("success", false)):
		return _failure("Player list failed through the split player service.")

	var get_player_info_result: Dictionary = executor.execute("player", {
		"action": "get_info",
		"path": "MusicPlayer"
	})
	if not bool(get_player_info_result.get("success", false)):
		return _failure("Player get_info failed through the split player service.")

	var set_player_volume_result: Dictionary = executor.execute("player", {
		"action": "set_volume",
		"path": "MusicPlayer",
		"volume_db": -3.0
	})
	if not bool(set_player_volume_result.get("success", false)):
		return _failure("Player set_volume failed through the split player service.")

	var set_player_pitch_result: Dictionary = executor.execute("player", {
		"action": "set_pitch",
		"path": "MusicPlayer",
		"pitch_scale": 1.25
	})
	if not bool(set_player_pitch_result.get("success", false)):
		return _failure("Player set_pitch failed through the split player service.")

	var set_player_stream_result: Dictionary = executor.execute("player", {
		"action": "set_stream",
		"path": "MusicPlayer",
		"stream": STREAM_PATH
	})
	if not bool(set_player_stream_result.get("success", false)):
		return _failure("Player set_stream failed through the split player service.")

	var play_result: Dictionary = executor.execute("player", {
		"action": "play",
		"path": "MusicPlayer",
		"from_position": 0.0
	})
	if not bool(play_result.get("success", false)):
		return _failure("Player play failed through the split player service.")

	var stop_result: Dictionary = executor.execute("player", {
		"action": "stop",
		"path": "MusicPlayer"
	})
	if not bool(stop_result.get("success", false)):
		return _failure("Player stop failed through the split player service.")

	var invalid_bus_result: Dictionary = executor.execute("player", {
		"action": "set_bus",
		"path": "MusicPlayer",
		"bus": "MissingBus"
	})
	if bool(invalid_bus_result.get("success", false)):
		return _failure("Player set_bus should fail for an unknown bus.")

	var remove_bus_result: Dictionary = executor.execute("bus", {
		"action": "remove",
		"bus": CONTRACT_BUS
	})
	if not bool(remove_bus_result.get("success", false)):
		return _failure("Bus remove failed through the split bus service.")

	return {
		"name": "audio_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"bus_count": int(list_buses_result.get("data", {}).get("count", 0)),
			"player_count": int(list_players_result.get("data", {}).get("count", 0)),
			"stream_path": STREAM_PATH
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	_remove_contract_bus()
	_remove_tree(TEMP_ROOT)
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node:
	var root := Node.new()
	root.name = "AudioToolExecutorContracts"
	var player := AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.stream = AudioStreamWAV.new()
	root.add_child(player)
	tree.root.add_child(root)
	return root


func _create_audio_stream(path: String) -> bool:
	var absolute_dir := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 44100
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.data = PackedByteArray()
	return ResourceSaver.save(stream, path) == OK


func _remove_contract_bus() -> void:
	for i in range(AudioServer.bus_count - 1, -1, -1):
		if AudioServer.get_bus_name(i) == CONTRACT_BUS:
			AudioServer.remove_bus(i)


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_tree_absolute(absolute_path)


func _remove_tree_absolute(absolute_path: String) -> void:
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree_absolute(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "audio_tool_executor_contracts",
		"success": false,
		"error": message
	}
