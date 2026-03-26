extends RefCounted

const LifecycleStateBuilderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_state_builder.gd")


class FakeEditorInterface:
	extends RefCounted

	var _edited_root := Node.new()
	var _clean_root := Node.new()

	func _init() -> void:
		_edited_root.name = "EditedScene"
		_clean_root.name = "CleanScene"

	func get_open_scenes() -> Array[String]:
		return ["res://scenes/b.tscn", "res://scenes/a.tscn"]

	func get_open_scene_roots() -> Array:
		return [_edited_root, _clean_root]

	func is_object_edited(root) -> bool:
		return root == _edited_root

	func get_edited_scene_root():
		return _edited_root

	func is_playing_scene() -> bool:
		return true

	func cleanup() -> void:
		if _edited_root != null and is_instance_valid(_edited_root):
			_edited_root.free()
		if _clean_root != null and is_instance_valid(_clean_root):
			_clean_root.free()


class FakePluginHost:
	extends RefCounted

	var _editor_interface := FakeEditorInterface.new()

	func get_editor_interface():
		return _editor_interface

	func cleanup() -> void:
		if _editor_interface != null:
			_editor_interface.cleanup()


class PluginHostCallbacks:
	extends RefCounted

	var plugin_host

	func _init(current_plugin_host) -> void:
		plugin_host = current_plugin_host

	func get_plugin_host():
		return plugin_host

	func cleanup() -> void:
		if plugin_host != null and plugin_host.has_method("cleanup"):
			plugin_host.cleanup()


var _callbacks


func run_case(_tree: SceneTree) -> Dictionary:
	var builder = LifecycleStateBuilderScript.new()
	builder.configure({})
	var default_state: Dictionary = builder.build_state()
	if bool(default_state.get("isPlayingScene", true)):
		return _failure("Lifecycle state builder should default to a non-playing state when no plugin host exists.")
	if not (default_state.get("openScenes", []) is Array):
		return _failure("Lifecycle state builder default state did not include openScenes as an array.")

	_callbacks = PluginHostCallbacks.new(FakePluginHost.new())
	builder.configure({
		"get_plugin_host": Callable(_callbacks, "get_plugin_host")
	})
	var state: Dictionary = builder.build_state()
	var open_scenes = state.get("openScenes", [])
	if not (open_scenes is Array) or (open_scenes as Array).size() != 2:
		return _failure("Lifecycle state builder did not return both open scenes.")
	if str((open_scenes as Array)[0]) != "res://scenes/a.tscn":
		return _failure("Lifecycle state builder did not sort open scenes.")
	if str(state.get("currentScenePath", "")) != "<unsaved:EditedScene>":
		return _failure("Lifecycle state builder did not resolve the edited scene root path.")
	if int(state.get("dirtySceneCount", 0)) != 1:
		return _failure("Lifecycle state builder did not project the dirty scene count.")

	var hinted_state: Dictionary = builder.build_state_with_hint("Pass save=true")
	if str(hinted_state.get("hint", "")) != "Pass save=true":
		return _failure("Lifecycle state builder did not preserve the hint payload.")

	return {
		"name": "editor_lifecycle_state_builder_contracts",
		"success": true,
		"error": "",
		"details": {
			"dirty_scene_count": int(state.get("dirtySceneCount", 0)),
			"current_scene_path": str(state.get("currentScenePath", "")),
			"open_scene_count": (open_scenes as Array).size()
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _callbacks != null:
		_callbacks.cleanup()
		_callbacks = null


func _failure(message: String) -> Dictionary:
	return {
		"name": "editor_lifecycle_state_builder_contracts",
		"success": false,
		"error": message
	}
