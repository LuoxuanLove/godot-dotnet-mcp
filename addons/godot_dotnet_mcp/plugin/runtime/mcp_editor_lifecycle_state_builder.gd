@tool
extends RefCounted
class_name MCPEditorLifecycleStateBuilder

var _get_plugin_host := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_get_plugin_host = callbacks.get("get_plugin_host", Callable())


func dispose() -> void:
	_get_plugin_host = Callable()


func build_state() -> Dictionary:
	var plugin = _get_plugin_host_safe()
	if plugin == null:
		return {
			"isPlayingScene": false,
			"openScenes": [],
			"dirtySceneCount": 0,
			"dirtyScenes": [],
			"currentScenePath": ""
		}

	var editor_interface = plugin.get_editor_interface()
	var open_scenes: Array[String] = []
	var dirty_scenes: Array[String] = []
	var current_scene_path := ""
	var is_playing_scene := false
	if editor_interface != null:
		if editor_interface.has_method("get_open_scenes"):
			for path in editor_interface.get_open_scenes():
				open_scenes.append(str(path))
		dirty_scenes = _collect_dirty_editor_scenes(editor_interface)
		if editor_interface.has_method("get_edited_scene_root"):
			current_scene_path = _resolve_editor_scene_root_path(editor_interface.get_edited_scene_root())
		if editor_interface.has_method("is_playing_scene"):
			is_playing_scene = bool(editor_interface.is_playing_scene())
	open_scenes.sort()
	dirty_scenes.sort()
	return {
		"isPlayingScene": is_playing_scene,
		"openScenes": open_scenes,
		"dirtySceneCount": dirty_scenes.size(),
		"dirtyScenes": dirty_scenes,
		"currentScenePath": current_scene_path
	}


func build_state_with_hint(hint: String) -> Dictionary:
	var state := build_state()
	state["hint"] = hint
	return state


func _resolve_editor_scene_root_path(root) -> String:
	if root == null:
		return ""
	if root is Node:
		var node: Node = root
		if not node.scene_file_path.is_empty():
			return node.scene_file_path
		if not node.name.is_empty():
			return "<unsaved:%s>" % node.name
	return str(root)


func _collect_dirty_editor_scenes(editor_interface) -> Array[String]:
	var dirty_scenes: Array[String] = []
	if editor_interface == null:
		return dirty_scenes
	if not editor_interface.has_method("get_open_scene_roots"):
		return dirty_scenes
	if not editor_interface.has_method("is_object_edited"):
		return dirty_scenes

	for root in editor_interface.get_open_scene_roots():
		if root == null:
			continue
		if not bool(editor_interface.is_object_edited(root)):
			continue
		var scene_path := _resolve_editor_scene_root_path(root)
		if scene_path.is_empty():
			continue
		if not dirty_scenes.has(scene_path):
			dirty_scenes.append(scene_path)

	return dirty_scenes


func _get_plugin_host_safe():
	if _get_plugin_host.is_valid():
		var plugin = _get_plugin_host.call()
		if plugin != null and is_instance_valid(plugin):
			return plugin
	return null
