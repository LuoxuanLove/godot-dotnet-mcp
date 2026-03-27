@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

var _scene_root_override: Node = null


func configure_context(context: Dictionary = {}) -> void:
	_scene_root_override = context.get("scene_root", null)


func _get_active_root() -> Node:
	if _scene_root_override != null and is_instance_valid(_scene_root_override):
		return _scene_root_override
	return _get_edited_scene_root()


func _find_active_node(path: String) -> Node:
	var root := _get_active_root()
	if root == null:
		return null
	if _scene_root_override == null:
		return _find_node_by_path(path)
	var normalized := _normalize_node_path(path, root)
	if normalized.is_empty() or normalized == ".":
		return root
	if normalized.begins_with("/"):
		var absolute_node = root.get_node_or_null(NodePath(normalized))
		if absolute_node != null:
			return absolute_node
	return root.get_node_or_null(NodePath(normalized))


func _get_bus_index(bus) -> int:
	if bus is int:
		return bus
	if bus is String:
		for i in range(AudioServer.bus_count):
			if AudioServer.get_bus_name(i) == bus:
				return i
	return -1


func _get_audio_player(path: String):
	if path.is_empty():
		return null

	var node = _find_active_node(path)
	if node == null:
		return null
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		return node
	return null


func _collect_audio_players(node: Node, result: Array[Dictionary]) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		var info = {
			"path": _get_scene_path(node),
			"type": str(node.get_class()),
			"playing": node.playing,
			"bus": node.bus
		}
		if node.stream:
			info["stream"] = str(node.stream.resource_path)
		result.append(info)

	for child in node.get_children():
		if child is Node:
			_collect_audio_players(child, result)
